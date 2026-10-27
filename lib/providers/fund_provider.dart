import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/fund_cost.dart';
import '../models/fund_data.dart';
import '../models/fund_search_mode.dart';
import '../models/scraper_result.dart';

import '../services/database_service.dart';
import '../services/financialtimes_scraper.dart';
import '../services/fund_scraper.dart';
import '../services/ine_ipc_service.dart';
import '../services/isin_providers/ecb_ifs_provider.dart';
import '../services/isin_resolver.dart';
import '../services/morningstar_rating.dart';
import '../services/quefondos_scraper.dart';
import '../services/settings_service.dart';

import '../tools/portfolio_correlation_matrix.dart';
import '../utils/app_error.dart';
import '../utils/financial_calculator.dart';
import '../utils/http_config.dart';
import '../utils/isin_search_query.dart';
import '../utils/isin_validator.dart';

// =============================================================
// TOP-LEVEL TYPES
// =============================================================
enum SortCriteria { name, date, value, performance }

// =============================================================
// AUXILIARY CLASSES
// =============================================================
class FundAlertInfo {
  final FundData fund;
  final double limitValue;
  final bool isMinAlert;
  final double currentValue;

  FundAlertInfo({
    required this.fund,
    required this.limitValue,
    required this.isMinAlert,
    required this.currentValue,
  });
}

// Búsquedas serializadas con política latest wins
class _FundSearchRequest {
  final String query;
  final FundSearchMode mode;
  final int generation;
  final Completer<List<FundSearchMatch>> completer =
      Completer<List<FundSearchMatch>>();

  _FundSearchRequest({
    required this.query,
    required this.mode,
    required this.generation,
  });
}

// =============================================================
// MAIN PROVIDER CLASS
// =============================================================
class FundProvider with ChangeNotifier {
  // =============================================================
  // STATIC FIELDS
  // =============================================================
  // Cliente HTTP compartido para reutilización de conexiones ===
  static http.Client? _sharedHttpClient;

  // =============================================================
  // PRIVATE FIELDS (final injectables)
  // =============================================================
  final Future<ScraperResult?> Function(String) _queFondosFetcher;
  final Future<ScraperResult?> Function(String) _ftFetcher;
  final Future<ScrapeResult?> Function(String) _ftByIsinFetcher;
  final Future<ScrapeResult> Function(FundSearchMatch) _fundSearchFetcher;
  final Future<ScrapeResult> Function(String) _fundIsinFetcher;
  final Future<ScrapeResult> Function(String, DateTimeRange) _fundRangeFetcher;
  final Future<List<FundSearchMatch>> Function(
    String query, {
    required FundSearchMode mode,
  })
  _fundSearchFunction;
  final IsinResolver Function() _isinResolverFactory;

  // =============================================================
  // PRIVATE FIELDS (mutable state)
  // =============================================================
  Future<void>? _portfolioLoadFuture;
  _FundSearchRequest? _pendingFundSearch;
  int _fundSearchGeneration = 0;
  bool _isFundSearchInProgress = false;
  final Set<String> _ratingRefreshesInProgress = {};
  Locale? _locale;

  PortfolioCorrelationMatrix? _correlationMatrix;
  bool _isCalculatingMatrix = false;

  // =============================================================
  // PUBLIC FIELDS (observable state)
  // =============================================================
  List<FundData> portfolio = [];
  FundData? currentFund;
  bool isLoading = false;
  bool hasPortfolioLoadError = false;
  AppError? lastError;
  SortCriteria sortCriteria = SortCriteria.name;
  Map<String, double> exchangeRates = {'EUR': 1.0};
  List<PricePoint>? benchmarkHistory;
  String? selectedBenchmarkSymbol;
  List<FundAlertInfo> triggeredAlerts = [];

  // =============================================================
  // CONSTRUCTOR
  // =============================================================
  FundProvider({
    IsinResolver Function()? isinResolverFactory,
    Future<ScraperResult?> Function(String)? queFondosFetcher,
    Future<ScraperResult?> Function(String)? ftFetcher,
    Future<ScrapeResult?> Function(String)? ftByIsinFetcher,
    Future<ScrapeResult> Function(FundSearchMatch)? fundSearchFetcher,
    Future<ScrapeResult> Function(String)? fundIsinFetcher,
    Future<ScrapeResult> Function(String, DateTimeRange)? fundRangeFetcher,
    Future<List<FundSearchMatch>> Function(
      String query, {
      required FundSearchMode mode,
    })?
    fundSearch,
  }) : _isinResolverFactory = isinResolverFactory ?? IsinResolver.new,
       _queFondosFetcher = queFondosFetcher ?? _fetchQueFondos,
       _ftFetcher = ftFetcher ?? _fetchFT,
       _ftByIsinFetcher = ftByIsinFetcher ?? _fetchFTByIsin,
       _fundSearchFetcher =
           fundSearchFetcher ?? FundScraper.getFundBySearchMatch,
       _fundIsinFetcher = fundIsinFetcher ?? FundScraper.getFundByIsin,
       _fundRangeFetcher = fundRangeFetcher ?? _fetchFundByRange,
       _fundSearchFunction = fundSearch ?? FundScraper.searchFunds;

  // =============================================================
  // STATIC METHODS (HTTP client)
  // =============================================================
  /// Obtiene o crea el cliente HTTP compartido.
  /// Este cliente reutiliza conexiones TCP, mejorando significativamente
  /// el rendimiento al actualizar múltiples fondos secuencialmente.
  static http.Client _getHttpClient() {
    _sharedHttpClient ??= http.Client();
    return _sharedHttpClient!;
  }

  /// Cierra el cliente HTTP compartido.
  /// Debe llamarse cuando la aplicación se cierra para liberar recursos.
  static void disposeHttpClient() {
    _sharedHttpClient?.close();
    _sharedHttpClient = null;
  }

  // =============================================================
  // GETTERS
  // =============================================================
  Locale? get locale => _locale;

  String? get error =>
      lastError?.type == AppErrorType.info ? null : lastError?.message;

  String? get info =>
      lastError?.type == AppErrorType.info ? lastError?.message : null;

  /// Indica si el provider está realizando alguna operación.
  /// La UI debe usar esta propiedad para deshabilitar botones y evitar
  /// interacciones duplicadas (doble clic, etc.).
  bool get isBusy => isLoading;

  PortfolioCorrelationMatrix? get correlationMatrix => _correlationMatrix;
  bool get isCalculatingMatrix => _isCalculatingMatrix;

  // =============================================================
  // INITIALIZATION & LIFECYCLE
  // =============================================================
  Future<void> initialize() async {
    await _initializeLocale();
    await loadPortfolio();
    await refreshOnStartupIfNeeded();
    unawaited(refreshMorningstarRatingsIfNeeded());
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await SettingsService.setLocale(locale.languageCode);
    notifyListeners();
  }

  Future<void> _initializeLocale() async {
    final languageCode = await SettingsService.getLocale();
    if (languageCode != null) {
      _locale = Locale(languageCode);
    }
  }

  Future<void> loadPortfolio() async {
    final pendingLoad = _portfolioLoadFuture;
    if (pendingLoad != null) {
      await pendingLoad;
      return loadPortfolio();
    }

    final loadFuture = () async {
      _clearError();
      hasPortfolioLoadError = false;
      try {
        final loadedPortfolio = await DatabaseService.getPortfolio();
        portfolio = loadedPortfolio;
        await _updateExchangeRates();
        _sortPortfolio();
        if (currentFund != null) {
          currentFund = await DatabaseService.getFund(currentFund!.isin);
        }
        _checkPortfolioAlerts();
      } catch (error, stackTrace) {
        hasPortfolioLoadError = true;
        _setError(_asError(error, stackTrace, type: AppErrorType.database));
      }
      notifyListeners();
    }();
    _portfolioLoadFuture = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_portfolioLoadFuture, loadFuture)) {
        _portfolioLoadFuture = null;
      }
    }
  }

  Future<void> refreshOnStartupIfNeeded() async {
    if (!await SettingsService.isAutoRefreshEnabled() || portfolio.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allFundsAreStale = portfolio.every((fund) {
      final fundDate = DateTime(fund.date.year, fund.date.month, fund.date.day);
      return fundDate.isBefore(today);
    });
    if (!allFundsAreStale) return;

    final lastGlobalRefresh = await SettingsService.getLastGlobalRefresh();
    if (lastGlobalRefresh != null &&
        now.isBefore(lastGlobalRefresh.add(const Duration(hours: 24)))) {
      return;
    }

    await updateAllPortfolio();
    await SettingsService.setLastGlobalRefresh(now);
  }

  // =============================================================
  // ERROR HANDLING
  // =============================================================
  void _clearError() {
    lastError = null;
  }

  void clearError() {
    if (lastError == null) return;
    _clearError();
    notifyListeners();
  }

  AppError _asError(
    Object error,
    StackTrace stackTrace, {
    AppErrorType type = AppErrorType.unknown,
  }) {
    if (error is AppError) return error;
    return AppError.fromException(error, stackTrace, type: type);
  }

  void _setError(AppError error) {
    lastError = error;
    notifyListeners();
  }

  // =============================================================
  // PORTFOLIO STATE MANAGEMENT
  // =============================================================
  void selectFund(FundData fund) {
    currentFund = fund;
    clearBenchmark();
    _clearError();
    notifyListeners();
  }

  Future<void> _syncFundState(String isin) async {
    final updatedFund = await DatabaseService.getFund(isin);
    if (updatedFund == null) return;

    final portfolioIndex = portfolio.indexWhere((fund) => fund.isin == isin);
    if (portfolioIndex != -1) {
      portfolio[portfolioIndex] = updatedFund;
    }
    if (currentFund?.isin == isin) {
      currentFund = updatedFund;
    }
  }

  void _checkPortfolioAlerts() {
    triggeredAlerts.clear();
    for (final fund in portfolio) {
      if (fund.lastValue <= 0) continue;
      if (fund.alertMin != null && fund.lastValue <= fund.alertMin!) {
        triggeredAlerts.add(
          FundAlertInfo(
            fund: fund,
            limitValue: fund.alertMin!,
            isMinAlert: true,
            currentValue: fund.lastValue,
          ),
        );
      }
      if (fund.alertMax != null && fund.lastValue >= fund.alertMax!) {
        triggeredAlerts.add(
          FundAlertInfo(
            fund: fund,
            limitValue: fund.alertMax!,
            isMinAlert: false,
            currentValue: fund.lastValue,
          ),
        );
      }
    }
  }

  void clearTriggeredAlerts() {
    triggeredAlerts.clear();
    notifyListeners();
  }

  // =============================================================
  // SORTING
  // =============================================================
  void setSortCriteria(SortCriteria criteria) {
    sortCriteria = criteria;
    _sortPortfolio();
    notifyListeners();
  }

  void _sortPortfolio() {
    switch (sortCriteria) {
      case SortCriteria.name:
        portfolio.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SortCriteria.date:
        portfolio.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortCriteria.value:
        portfolio.sort((a, b) {
          final metricsA = FinancialCalculator.calculateFundMetrics(a);
          final metricsB = FinancialCalculator.calculateFundMetrics(b);
          return metricsB.currentValue.compareTo(
            metricsA.currentValue,
          ); // Descendente por defecto para valores
        });
        break;
      case SortCriteria.performance:
        portfolio.sort((a, b) {
          final metricsA = FinancialCalculator.calculateFundMetrics(a);
          final metricsB = FinancialCalculator.calculateFundMetrics(b);
          final perfA = metricsA.isAnnualized
              ? metricsA.tae
              : metricsA.profitRel;
          final perfB = metricsB.isAnnualized
              ? metricsB.tae
              : metricsB.profitRel;
          return perfB.compareTo(
            perfA,
          ); // Descendente por defecto para rendimiento
        });
        break;
    }
  }

  // =============================================================
  // EXCHANGE RATES
  // =============================================================
  Future<void> _updateExchangeRates() async {
    final currencies = portfolio.map((f) => f.currency).toSet();
    for (var cur in currencies) {
      if (cur != 'EUR' && cur.isNotEmpty) {
        try {
          exchangeRates[cur] = await FundScraper.getExchangeRate(cur, 'EUR');
        } catch (error, stackTrace) {
          exchangeRates[cur] = 1.0;
          _setError(_asError(error, stackTrace));
        }
      }
    }
  }

  // =============================================================
  // MORNINGSTAR RATINGS
  // =============================================================
  Future<void> refreshMorningstarRatingsIfNeeded() async {
    for (final fund in List<FundData>.of(portfolio)) {
      await _refreshMorningstarRatingIfNeeded(fund.isin);
    }
  }

  bool _isMorningstarRatingDue(FundData fund, DateTime now) {
    final lastAttempt = fund.morningstarLastAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(hours: 24)) {
      return false;
    }

    final lastChecked = fund.morningstarCheckedAt;
    if (lastChecked == null) return true;

    final currentMonth = DateTime(now.year, now.month);
    return now.day >= 5 && lastChecked.isBefore(currentMonth);
  }

  Future<void> _refreshMorningstarRatingIfNeeded(String isin) async {
    if (!_ratingRefreshesInProgress.add(isin)) return;
    try {
      final fund = await DatabaseService.getFund(isin);
      if (fund == null || !_isMorningstarRatingDue(fund, DateTime.now())) {
        return;
      }

      final attemptedAt = DateTime.now();
      await DatabaseService.updateMorningstarAttempt(isin, attemptedAt);

      final service = MorningstarRating(isin);
      late final MorningstarRatingResult result;

      try {
        result = await service.fetchRating();
      } finally {
        service.close();
      }
      if (!result.succeeded) return;

      await DatabaseService.updateMorningstarRating(
        isin,
        rating: result.rating ?? fund.morningstarRating,
        checkedAt: DateTime.now(),
      );
      await _syncFundState(isin);
      notifyListeners();
    } catch (_) {
      // El rating es complementario y no debe afectar a la cartera.
    } finally {
      _ratingRefreshesInProgress.remove(isin);
    }
  }

  // =============================================================
  // FUND SEARCH (query-based)
  // =============================================================
  Future<List<FundSearchMatch>> searchFunds(
    String query, {
    required FundSearchMode mode,
  }) {
    final normalizedQuery = query.trim();
    if (mode == FundSearchMode.isin) {
      if (IsinSearchQuery.prefix(normalizedQuery) == null) {
        return Future.value([]);
      }
    } else if (normalizedQuery.length < 2) {
      return Future.value([]);
    }

    if (isLoading && !_isFundSearchInProgress) {
      return Future.value([]);
    }

    final request = _FundSearchRequest(
      query: normalizedQuery,
      mode: mode,
      generation: ++_fundSearchGeneration,
    );

    if (_isFundSearchInProgress) {
      final supersededRequest = _pendingFundSearch;
      if (supersededRequest != null) {
        supersededRequest.completer.complete([]);
      }
      _pendingFundSearch = request;
      _clearError();
      notifyListeners();
      return request.completer.future;
    }

    _pendingFundSearch = request;
    _isFundSearchInProgress = true;
    isLoading = true;
    _clearError();
    notifyListeners();
    unawaited(_processFundSearchQueue());
    return request.completer.future;
  }

  Future<void> _processFundSearchQueue() async {
    try {
      while (_pendingFundSearch != null) {
        final request = _pendingFundSearch!;
        _pendingFundSearch = null;
        try {
          final matches = await _fundSearchFunction(
            request.query,
            mode: request.mode,
          );
          request.completer.complete(matches);
        } catch (error, stackTrace) {
          if (request.generation == _fundSearchGeneration) {
            lastError = _asError(error, stackTrace);
          }
          request.completer.complete([]);
        }
      }
    } finally {
      _isFundSearchInProgress = false;
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // FUND SEARCH & FETCHING (individual fund operations)
  // =============================================================
  Future<ScrapeResult> fetchFundOnly(String isin) async {
    if (isBusy) {
      final appError = AppError.busy();
      _setError(appError);
      return ScrapeResult(error: appError);
    }

    if (isin.length != 12) {
      final appError = AppError.validation('El ISIN debe tener 12 caracteres.');
      _setError(appError);
      return ScrapeResult(error: appError);
    }

    isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final normalizedIsin = isin.toUpperCase();
      ScrapeResult primaryResult;
      try {
        primaryResult = await _fundIsinFetcher(normalizedIsin);
      } catch (error, stackTrace) {
        primaryResult = ScrapeResult(error: _asError(error, stackTrace));
      }

      if (primaryResult.data == null &&
          primaryResult.error?.type == AppErrorType.notFound) {
        final ecbResult = await _tryResolveFundByIsin(normalizedIsin);
        if (ecbResult != null) primaryResult = ecbResult;
      }

      if (primaryResult.data != null) {
        primaryResult = await _tryResolveIsin(primaryResult);
      }

      final result = await _fetchLatestFundWithFallback(
        normalizedIsin,
        primaryResult: primaryResult,
      );
      lastError = result.error;
      return result;
    } catch (error, stackTrace) {
      final appError = _asError(error, stackTrace);
      lastError = appError;
      return ScrapeResult(error: appError);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ScrapeResult> fetchFundMatch(FundSearchMatch match) async {
    if (isBusy) {
      final appError = AppError.busy();
      _setError(appError);
      return ScrapeResult(error: appError);
    }
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final result = await _fundSearchFetcher(match);
      if (result.data == null) {
        final candidateIsin = match.isin?.trim().toUpperCase();
        if (candidateIsin != null && IsinValidator.isValid(candidateIsin)) {
          final fallbackResult = await _fetchLatestFundWithFallback(
            candidateIsin,
            primaryResult: result,
          );
          lastError = fallbackResult.error;
          return fallbackResult;
        }

        lastError = result.error;
        return result;
      }
      if (result.error != null) {
        lastError = result.error;
        return result;
      }
      final resolvedResult = await _tryResolveIsin(result);
      final fund = resolvedResult.data;
      if (fund == null || !fund.hasValidIsin) return resolvedResult;

      return await _fetchLatestFundWithFallback(
        fund.isin,
        primaryResult: resolvedResult,
      );
    } catch (error, stackTrace) {
      final appError = _asError(error, stackTrace);
      lastError = appError;
      return ScrapeResult(error: appError);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> searchFund(String isin) async {
    if (isBusy) {
      _setError(AppError.busy());
      return false;
    }
    if (isin.length != 12) {
      _setError(AppError.validation('El ISIN debe tener 12 caracteres.'));
      return false;
    }
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final normalizedIsin = isin.toUpperCase();
      final existingFund = await DatabaseService.getFund(normalizedIsin);
      final result = await _fetchLatestFundWithFallback(
        normalizedIsin,
        existingFund: existingFund,
      );
      if (result.data != null) {
        final fetchedFund = result.data!;
        if (existingFund != null && !_hasNewData(existingFund, fetchedFund)) {
          if (result.error != null) {
            lastError = result.error;
            return false;
          }
          _setError(
            AppError.info(
              'Los datos ya están actualizados y no se han producido cambios.',
            ),
          );
          return true;
        }
        final fundToSave = existingFund == null
            ? fetchedFund
            : FundData(
                isin: fetchedFund.isin,
                symbol: fetchedFund.symbol.trim().isNotEmpty
                    ? fetchedFund.symbol
                    : existingFund.symbol,
                name: fetchedFund.name.trim().isNotEmpty
                    ? fetchedFund.name
                    : existingFund.name,
                lastValue: fetchedFund.lastValue,
                currency: fetchedFund.currency,
                date: fetchedFund.date,
                history: fetchedFund.history,
                operations: existingFund.operations,
                alertMin: existingFund.alertMin,
                alertMax: existingFund.alertMax,
                ter: fetchedFund.ter ?? existingFund.ter,
                performanceFee:
                    fetchedFund.performanceFee ?? existingFund.performanceFee,
                // Los costes estructurados se adoptan como un conjunto coherente.
                // Si el proveedor no aporta cargos, conservamos los costes existentes
                // para evitar eliminar periodos que todavía tienen cargos asociados.
                // costPeriods: fetchedFund.costCharges.isNotEmpty
                //     ? fetchedFund.costPeriods
                //     : existingFund.costPeriods,
                costPeriods: _canAdoptCostPeriods(existingFund, fetchedFund)
                    ? fetchedFund.costPeriods
                    : existingFund.costPeriods,
                costCharges: fetchedFund.costCharges.isNotEmpty
                    ? fetchedFund.costCharges
                    : existingFund.costCharges,
                morningstarRating: existingFund.morningstarRating,
                morningstarCheckedAt: existingFund.morningstarCheckedAt,
                morningstarLastAttemptAt: existingFund.morningstarLastAttemptAt,
                source: existingFund.source ?? fetchedFund.source,
                valuationSource:
                    fetchedFund.valuationSource ?? existingFund.valuationSource,
              );

        await DatabaseService.saveFund(fundToSave);
        currentFund = fundToSave;
        await _syncFundState(fundToSave.isin);
        await loadPortfolio();
        return true;
      }
      lastError = result.error;
      return false;
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('LF-71 searchFund exception: $error');
      // ignore: avoid_print
      print(stackTrace);

      lastError = _asError(error, stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> searchFundByRange(String isin, DateTimeRange range) async {
    if (isBusy) {
      _setError(AppError.busy());
      return false;
    }

    isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final result = await _fundRangeFetcher(isin.toUpperCase(), range);
      final fetchedFund = result.data;

      if (fetchedFund == null) {
        lastError = result.error;
        return false;
      }

      final validFetchedHistory =
          fetchedFund.history
              .where(
                (point) =>
                    point.price.isFinite &&
                    point.price > 0 &&
                    !point.date.isBefore(range.start) &&
                    !point.date.isAfter(range.end),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      if (validFetchedHistory.isEmpty) {
        final existingFund = await DatabaseService.getFund(fetchedFund.isin);

        if (existingFund == null) {
          return false;
        }

        // Compatibilidad con una respuesta que contiene un único precio cero:
        // se considera procesada, pero no se modifica el fondo persistido.
        if (fetchedFund.history.length == 1 &&
            fetchedFund.history.single.price == 0.0) {
          return true;
        }

        return false;
      }

      final existingFund = await DatabaseService.getFund(fetchedFund.isin);

      final fetchedLatestPoint = validFetchedHistory.fold<PricePoint?>(
        null,
        (latest, point) =>
            latest == null || point.date.isAfter(latest.date) ? point : latest,
      );

      final hasExistingHistory =
          existingFund?.history.any(
            (point) => point.price.isFinite && point.price > 0,
          ) ??
          false;

      final shouldAdoptFetchedValuation =
          fetchedLatestPoint != null &&
          (existingFund == null ||
              !hasExistingHistory ||
              fetchedLatestPoint.date.isAfter(existingFund.date));

      final mergedHistory = <DateTime, PricePoint>{};

      for (final point in existingFund?.history ?? <PricePoint>[]) {
        final key = DateTime(point.date.year, point.date.month, point.date.day);
        if (point.price.isFinite && point.price > 0) {
          mergedHistory[key] = point;
        }
      }

      for (final point in validFetchedHistory) {
        final key = DateTime(point.date.year, point.date.month, point.date.day);

        // No permitimos que una valoración de igual fecha sustituya
        // el precio histórico asociado a la valoración vigente.
        final isCurrentValuationDate =
            existingFund != null &&
            key.year == existingFund.date.year &&
            key.month == existingFund.date.month &&
            key.day == existingFund.date.day;

        if (!isCurrentValuationDate || shouldAdoptFetchedValuation) {
          mergedHistory[key] = point;
        }
      }

      final historyToSave = mergedHistory.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final fundToSave = existingFund == null
          ? fetchedFund
          : FundData(
              isin: fetchedFund.isin,
              symbol: shouldAdoptFetchedValuation
                  ? fetchedFund.symbol
                  : existingFund.symbol,
              name: shouldAdoptFetchedValuation
                  ? fetchedFund.name
                  : existingFund.name,
              currency: shouldAdoptFetchedValuation
                  ? fetchedFund.currency
                  : existingFund.currency,
              lastValue: shouldAdoptFetchedValuation
                  ? fetchedLatestPoint.price
                  : existingFund.lastValue,
              date: shouldAdoptFetchedValuation
                  ? fetchedLatestPoint.date
                  : existingFund.date,
              //history: validFetchedHistory,
              history: historyToSave,
              operations: existingFund.operations,
              alertMin: existingFund.alertMin,
              alertMax: existingFund.alertMax,
              ter: existingFund.ter,
              performanceFee: existingFund.performanceFee,
              costPeriods: existingFund.costPeriods,
              costCharges: existingFund.costCharges,
              morningstarRating: existingFund.morningstarRating,
              morningstarCheckedAt: existingFund.morningstarCheckedAt,
              morningstarLastAttemptAt: existingFund.morningstarLastAttemptAt,
              source: existingFund.source,
              valuationSource: shouldAdoptFetchedValuation
                  ? (fetchedFund.valuationSource ??
                        existingFund.valuationSource)
                  : existingFund.valuationSource,
            );

      await DatabaseService.saveFund(fundToSave);
      currentFund = fundToSave;
      await _syncFundState(fundToSave.isin);
      await loadPortfolio();

      return true;
    } catch (error, stackTrace) {
      lastError = _asError(error, stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAllPortfolio() async {
    if (portfolio.isEmpty || isBusy) return;
    isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final isins = portfolio.map((f) => f.isin).toList();

      //AppError? updateError;
      // ✅ NUEVO: Acumulamos los mensajes de error de cada fondo fallido
      final failedUpdates = <String>[];
      var hasChanges = false;

      for (final isin in isins) {
        final existing = portfolio.firstWhere((f) => f.isin == isin);
        final result = await _fetchLatestFundWithFallback(
          isin,
          existingFund: existing,
        );

        /* if (result.error != null && updateError == null) {
          // ❌ Solo guarda el PRIMER error y ignora el resto
          updateError = result.error;
        } */
        // ✅ Acumulamos el error con el nombre del fondo para que no se pierda
        if (result.error != null) {
          failedUpdates.add('• ${existing.name}: ${result.error!.message}');
        }

        if (result.data != null) {
          // Mantener las alertas existentes al actualizar
          if (_hasNewData(existing, result.data!)) {
            hasChanges = true;
            final updatedFund = FundData(
              isin: result.data!.isin,
              symbol: result.data!.symbol.trim().isNotEmpty
                  ? result.data!.symbol
                  : existing.symbol,
              name: result.data!.name.trim().isNotEmpty
                  ? result.data!.name
                  : existing.name,
              lastValue: result.data!.lastValue,
              currency: result.data!.currency,
              date: result.data!.date,
              history: result.data!.history,
              operations: existing.operations,
              alertMin: existing.alertMin,
              alertMax: existing.alertMax,
              ter: result.data!.ter ?? existing.ter,
              performanceFee:
                  result.data!.performanceFee ?? existing.performanceFee,
              // Mantener periodos y cargos existentes cuando el proveedor
              // no aporta cargos estructurados, evitando referencias rotas.
              // costPeriods: result.data!.costCharges.isNotEmpty
              //     ? result.data!.costPeriods
              //     : existing.costPeriods,

              costPeriods: _canAdoptCostPeriods(existing, result.data!)
                  ? result.data!.costPeriods
                  : existing.costPeriods,
              costCharges: result.data!.costCharges.isNotEmpty
                  ? result.data!.costCharges
                  : existing.costCharges,
              morningstarRating: existing.morningstarRating,
              morningstarCheckedAt: existing.morningstarCheckedAt,
              morningstarLastAttemptAt: existing.morningstarLastAttemptAt,
              source: existing.source ?? result.data!.source,
              valuationSource:
                  result.data!.valuationSource ?? existing.valuationSource,
            );
            await DatabaseService.saveFund(updatedFund);
            await _syncFundState(isin);
          }
        }
      }
      await loadPortfolio();

      // ✅ NUEVO: Generamos un mensaje de error claro y detallado si hubo fallos
      if (failedUpdates.isNotEmpty) {
        final count = failedUpdates.length;
        final header = count == 1
            ? 'No se pudo actualizar 1 fondo:'
            : 'No se pudieron actualizar $count fondos:';

        lastError = AppError(
          type: AppErrorType.network,
          message: '$header\n${failedUpdates.join('\n')}',
        );
      } else if (!hasChanges) {
        lastError = AppError.info(
          'Los datos ya están actualizados y no se han producido cambios.',
        );
      }
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // ISIN RESOLUTION
  // =============================================================
  Future<ScrapeResult?> _tryResolveFundByIsin(String isin) async {
    final provider = EcbIfsProvider();

    final resolution = await provider.resolveByIsin(isin);

    if (resolution == null) {
      return null;
    }

    final fund = FundData(
      isin: resolution.isin,
      symbol: '',
      name: resolution.officialName ?? '',
      lastValue: 0,
      currency: '',
      date: DateTime.now(),
      history: const [],
      source: FundSource.ecb,
    );

    return ScrapeResult(data: fund, isResolved: true, source: FundSource.ecb);
  }

  Future<ScrapeResult> _tryResolveIsin(ScrapeResult result) async {
    if (result.data == null) return result;

    FundData fund = result.data!;
    if (fund.hasValidIsin) return result;

    final resolver = _isinResolverFactory();

    try {
      final resolution = await resolver.resolve(
        fundName: fund.name,
        ticker: fund.symbol,
      );

      if (resolution != null) {
        final resolvedFund = FundData(
          isin: resolution.isin,
          symbol: fund.symbol,
          name: fund.name,
          lastValue: fund.lastValue,
          currency: fund.currency,
          date: fund.date,
          history: fund.history,
          alertMin: fund.alertMin,
          alertMax: fund.alertMax,
          operations: fund.operations,
          ter: fund.ter,
          performanceFee: fund.performanceFee,
          costPeriods: fund.costPeriods,
          costCharges: fund.costCharges,
          morningstarRating: fund.morningstarRating,
          morningstarCheckedAt: fund.morningstarCheckedAt,
          morningstarLastAttemptAt: fund.morningstarLastAttemptAt,
          //source: fund.source,
          source: fund.source ?? fundSourceFromIsinSource(resolution.source),
          valuationSource: fund.valuationSource,
        );
        return ScrapeResult(
          data: resolvedFund,
          isResolved: true,
          source: fundSourceFromIsinSource(resolution.source),
          //valuationSource: result.valuationSource,
        );
      }

      if (fund.hasValidIsin) return result;
    } finally {
      resolver.dispose();
    }

    return result;
  }

  // =============================================================
  // FUND FETCHING CORE LOGIC (private helpers)
  // =============================================================

  bool _canAdoptCostPeriods(FundData existing, FundData fetched) {
    if (fetched.costPeriods.isEmpty) return false;

    final fetchedUids = fetched.costPeriods.map((p) => p.uid).toSet();

    final referencesRemainValid = existing.costCharges.every((charge) {
      final periodUid = charge.performancePeriodUid;
      return periodUid == null || fetchedUids.contains(periodUid);
    });

    if (!referencesRemainValid) return false;

    // Los periodos TER generados automáticamente no deben sustituir
    // costes estructurados existentes.
    final containsNonLegacyPeriod = fetched.costPeriods.any(
      (period) => period.concept != FundCostConcept.ter,
    );

    return containsNonLegacyPeriod || existing.costPeriods.isEmpty;
  }

  Future<ScrapeResult> _fetchLatestFundWithFallback(
    String isin, {
    FundData? existingFund,
    ScrapeResult? primaryResult,
  }) async {
    if (primaryResult == null) {
      try {
        primaryResult = await _fundIsinFetcher(isin);
      } catch (error, stackTrace) {
        //primaryResult ??= await _ftByIsinFetcher(isin);
        primaryResult = ScrapeResult(error: _asError(error, stackTrace));
      }
    }
    if (!_hasUsableNav(primaryResult.data)) {
      try {
        final ftResult = await _ftByIsinFetcher(isin);
        if (ftResult != null && _hasUsableNav(ftResult.data)) {
          primaryResult = ftResult;
        }
      } catch (error, stackTrace) {
        // Se conserva el resultado original; los siguientes fallbacks siguen ejecutándose.
        primaryResult = ScrapeResult(error: _asError(error, stackTrace));
      }
    }

    final primaryFund = primaryResult.data;
    final existingDate = _latestKnownPriceDate(existingFund);
    final primaryDate = _latestKnownPriceDate(primaryFund);
    final existingHasNav = _hasUsableNav(existingFund);
    final primaryIsUsable = _hasUsableNav(primaryFund);
    final primaryImprovesExisting =
        primaryIsUsable &&
        primaryDate != null &&
        (existingDate == null ||
            primaryDate.isAfter(existingDate) ||
            (!existingHasNav && !primaryDate.isBefore(existingDate)));

    FundData? fallbackFund;
    AppError? scraperError;
    try {
      final queFondosResult = await _queFondosFetcher(isin)
          .timeout(HttpConfig.timeout);
      fallbackFund = _fundFromScraper(
        isin,
        queFondosResult,
        existingFund: existingFund,
        primaryFund: primaryFund,
        valuationSource: FundSource.queFondos,
      );
    } catch (error, stackTrace) {
      scraperError = _asError(error, stackTrace);
    }

    if (fallbackFund == null) {
      try {
        final ftResult = await _ftFetcher(isin).timeout(HttpConfig.timeout);
        fallbackFund = _fundFromScraper(
          isin,
          ftResult,
          existingFund: existingFund,
          primaryFund: primaryFund,
          valuationSource: FundSource.financialTimes,
        );
        if (fallbackFund != null) scraperError = null;
      } catch (error, stackTrace) {
        scraperError ??= _asError(error, stackTrace);
      }
    }

    var fallbackError = primaryResult.isResolved ? null : scraperError;

    if (fallbackFund != null) {
      final fallbackDate = DateTime(
        fallbackFund.date.year,
        fallbackFund.date.month,
        fallbackFund.date.day,
      );

      final isNewerThanExisting =
          existingDate == null ||
          fallbackDate.isAfter(existingDate) ||
          (!existingHasNav && !fallbackDate.isBefore(existingDate));

      final isNotOlderThanPrimary =
          primaryDate == null ||
          (primaryIsUsable
              ? fallbackDate.isAfter(primaryDate)
              : !fallbackDate.isBefore(primaryDate));

      if (isNewerThanExisting && isNotOlderThanPrimary) {
        return ScrapeResult(
          data: fallbackFund,
          isResolved: primaryResult.isResolved,
          source: fallbackFund.source,
        );
      }
    }

    /* // Evaluar Yahoo también cuando no haya un fallback válido.
    if (primaryImprovesExisting) return primaryResult;

    if (fallbackFund == null && !primaryResult.isResolved) {
      fallbackError ??= AppError.data(
        'QueFondos y Financial Times no devolvieron una valoración válida.',
      );
    } */

    // Evaluar Yahoo también cuando no haya un fallback válido.
    if (primaryImprovesExisting) return primaryResult;

    // LF-65: aceptar cambios de metadatos aunque la valoración
    // y el historial no hayan cambiado.
    final primaryMetadataChanged =
        existingFund != null &&
        primaryFund != null &&
        ((existingFund.source == null && primaryFund.source != null) ||
            (primaryFund.valuationSource != null &&
                primaryFund.valuationSource != existingFund.valuationSource));

    final primaryCostsChanged =
        existingFund != null &&
        primaryFund != null &&
        (_hasDifferentCostPeriods(
              existingFund.costPeriods,
              primaryFund.costPeriods,
            ) ||
            _hasDifferentCostCharges(
              existingFund.costCharges,
              primaryFund.costCharges,
            ));

    final primaryIsNotOlderThanExisting =
        primaryDate != null &&
        (existingDate == null || !primaryDate.isBefore(existingDate));

    if (primaryIsUsable &&
        (primaryMetadataChanged || primaryCostsChanged) &&
        primaryIsNotOlderThanExisting) {
      return ScrapeResult(
        data: primaryFund,
        isResolved: primaryResult.isResolved,
        source: primaryResult.source,
      );
    }

    if (fallbackFund == null && !primaryResult.isResolved) {
      fallbackError ??= AppError.data(
        'QueFondos y Financial Times no devolvieron una valoración válida.',
      );
    }

    if (existingFund != null) {
      return ScrapeResult(
        data: existingFund,
        //error: existingHasNav ? null : fallbackError, // BUG
        // ✅ SIEMPRE reportamos el error si la red falló, aunque tengamos datos locales.
        // El llamador decidirá si mostrarlo al usuario o no.
        error: fallbackError,
      );
    }

    if (primaryIsUsable) return primaryResult;

    if (primaryFund != null) {
      return ScrapeResult(
        data: primaryFund,
        error: fallbackError,
        isResolved: primaryResult.isResolved,
        source: primaryResult.source,
      );
    }

    return ScrapeResult(error: primaryResult.error ?? fallbackError);
  }

  FundData? _fundFromScraper(
    String isin,
    ScraperResult? result, {
    FundData? existingFund,
    FundData? primaryFund,
    required FundSource valuationSource,
  }) {
    if (result == null) return null;

    final value = _parseScraperValue(result.valorLiquidativo);
    final date = _parseScraperDate(result.fecha);
    if (value == null || date == null) return null;

    final metadata = existingFund ?? primaryFund;
    final fallbackCurrency = result.divisa?.trim().toUpperCase();
    if (fallbackCurrency != null &&
        fallbackCurrency.isNotEmpty &&
        !RegExp(r'^[A-Z]{3}$').hasMatch(fallbackCurrency)) {
      return null;
    }

    final metadataCurrency = metadata?.currency.trim().toUpperCase();
    if (fallbackCurrency != null &&
        fallbackCurrency.isNotEmpty &&
        metadataCurrency != null &&
        metadataCurrency.isNotEmpty &&
        fallbackCurrency != metadataCurrency) {
      return null;
    }

    final currency = fallbackCurrency?.isNotEmpty == true
        ? fallbackCurrency!
        : metadataCurrency;
    if (currency == null || currency.isEmpty) return null;

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final historyByDate = <DateTime, PricePoint>{};
    void addHistory(Iterable<PricePoint> history) {
      for (final point in history) {
        final pointDate = DateTime(
          point.date.year,
          point.date.month,
          point.date.day,
        );
        historyByDate[pointDate] = PricePoint(pointDate, point.price);
      }
    }

    addHistory(existingFund?.history ?? const []);
    addHistory(primaryFund?.history ?? const []);
    historyByDate[normalizedDate] = PricePoint(normalizedDate, value);
    final history = historyByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final officialName = result.nombre?.trim();
    return FundData(
      isin: isin,
      symbol: existingFund?.symbol ?? primaryFund?.symbol ?? '',
      name: officialName?.isNotEmpty == true
          ? officialName!
          : metadata?.name ?? 'Fondo desconocido',
      lastValue: value,
      currency: currency,
      date: normalizedDate,
      history: history,
      operations: metadata?.operations ?? const [],
      alertMin: metadata?.alertMin,
      alertMax: metadata?.alertMax,
      ter: metadata?.ter,
      performanceFee: metadata?.performanceFee,
      costPeriods: metadata?.costPeriods,
      costCharges: metadata?.costCharges ?? const [],
      morningstarRating: metadata?.morningstarRating,
      morningstarCheckedAt: metadata?.morningstarCheckedAt,
      morningstarLastAttemptAt: metadata?.morningstarLastAttemptAt,
      //source: existingFund?.source ?? primaryFund?.source ?? valuationSource,
      source: existingFund?.source ?? primaryFund?.source,
      valuationSource: valuationSource,
    );
  }

  bool _hasNewData(FundData existing, FundData fetched) {
    if (existing.lastValue != fetched.lastValue ||
        existing.date != fetched.date) {
      return true;
    }

    // Completar la identidad solo si aún no tiene una fuente.
    if (existing.source == null && fetched.source != null) {
      return true;
    }

    // Una nueva fuente de valoración es un cambio aunque el precio
    // y la fecha de valoración sean idénticos.
    if (fetched.valuationSource != null &&
        existing.valuationSource != fetched.valuationSource) {
      return true;
    }

    final existingPrices = <DateTime, double>{
      for (final point in existing.history)
        DateTime(point.date.year, point.date.month, point.date.day):
            point.price,
    };

    /* return fetched.history.any((point) {
      final date = DateTime(point.date.year, point.date.month, point.date.day);
      return existingPrices[date] != point.price;
    }); */
    final historyChanged = fetched.history.any((point) {
      final date = DateTime(point.date.year, point.date.month, point.date.day);
      return existingPrices[date] != point.price;
    });

    return historyChanged ||
        _hasDifferentCostPeriods(existing.costPeriods, fetched.costPeriods) ||
        _hasDifferentCostCharges(existing.costCharges, fetched.costCharges);
  }

  bool _hasDifferentCostPeriods(
    List<FundCostPeriod> existing,
    List<FundCostPeriod> fetched,
  ) {
    if (existing.length != fetched.length) return true;

    final existingByUid = {for (final item in existing) item.uid: item};
    final fetchedByUid = {for (final item in fetched) item.uid: item};

    if (!existingByUid.keys.toSet().containsAll(fetchedByUid.keys)) {
      return true;
    }

    for (final item in fetched) {
      final old = existingByUid[item.uid];
      if (old == null ||
          old.concept != item.concept ||
          old.ratePercent != item.ratePercent ||
          old.basis != item.basis ||
          old.treatment != item.treatment ||
          old.validFrom != item.validFrom ||
          old.validTo != item.validTo ||
          old.description != item.description) {
        return true;
      }
    }

    return false;
  }

  bool _hasDifferentCostCharges(
    List<FundCostCharge> existing,
    List<FundCostCharge> fetched,
  ) {
    if (existing.length != fetched.length) return true;

    final existingByUid = {for (final item in existing) item.uid: item};
    final fetchedByUid = {for (final item in fetched) item.uid: item};

    if (!existingByUid.keys.toSet().containsAll(fetchedByUid.keys)) {
      return true;
    }

    for (final item in fetched) {
      final old = existingByUid[item.uid];
      if (old == null ||
          old.concept != item.concept ||
          old.date != item.date ||
          old.amount != item.amount ||
          old.description != item.description ||
          old.performancePeriodUid != item.performancePeriodUid ||
          old.settledThrough != item.settledThrough) {
        return true;
      }
    }

    return false;
  }

  // =============================================================
  // PORTFOLIO CRUD OPERATIONS
  // =============================================================
  // === OPERACIONES DE CARTERA ===

  Future<void> addToPortfolio(FundData fund) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.saveFund(fund);
      currentFund = fund;
      await loadPortfolio();
      unawaited(_refreshMorningstarRatingIfNeeded(fund.isin));
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> replaceFund(FundData fund) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.replaceFund(fund);
      currentFund = fund;
      await loadPortfolio();
      unawaited(_refreshMorningstarRatingIfNeeded(fund.isin));
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeFromPortfolio(String isin) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.deleteFund(isin);
      if (currentFund?.isin == isin) currentFund = null;
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearCurrentFundData() async {
    if (currentFund == null) return;
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.clearAllData(currentFund!.isin);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearPortfolio() async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.clearPortfolio();
      portfolio = [];
      currentFund = null;
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // OPERATIONS CRUD (COMPRA/VENTA)
  // =============================================================
  // === OPERACIONES DE COMPRA/VENTA/TRASPASO ===

  Future<void> addOperation(FundOperation op, {FundOperation? op2}) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      /* await DatabaseService.saveOperation(op);
      if (op2 != null) {
        await DatabaseService.saveOperation(op2);
      } */

      if (op2 == null) {
        await DatabaseService.saveOperation(op);
      } else {
        await DatabaseService.saveOperationsAtomically([op, op2]);
      }

      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteOperation(int id) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.deleteOperation(id);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restoreOperation(FundOperation operation) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.restoreOperation(operation);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // PRICE POINTS CRUD
  // =============================================================
  // === OPERACIONES DE PRECIOS ===

  Future<void> deletePricePoint(String isin, DateTime date) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.deletePricePoint(isin, date);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deletePricePoints(String isin, List<DateTime> dates) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.deletePricePoints(isin, dates);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePricePoint(String isin, PricePoint point) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.restorePricePoint(isin, point);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePricePoints(String isin, List<PricePoint> points) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      await DatabaseService.restorePricePoints(isin, points);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // FUND CONFIGURATION (Alerts & Costs)
  // =============================================================
  // === OPERACIONES DE CONFIGURACIÓN ===

  Future<void> setAlerts(String isin, double? min, double? max) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final fund = await DatabaseService.getFund(isin);
      if (fund == null) return;
      final updated = FundData(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        lastValue: fund.lastValue,
        currency: fund.currency,
        date: fund.date,
        history: fund.history,
        operations: fund.operations,
        alertMin: min,
        alertMax: max,
        ter: fund.ter,
        performanceFee: fund.performanceFee,
        costPeriods: fund.costPeriods,
        costCharges: fund.costCharges,
        morningstarRating: fund.morningstarRating,
        morningstarCheckedAt: fund.morningstarCheckedAt,
        morningstarLastAttemptAt: fund.morningstarLastAttemptAt,
        source: fund.source,
        valuationSource: fund.valuationSource,
      );
      await DatabaseService.saveFund(updated);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setFundCosts(
    String isin, {
    required List<FundCostPeriod> periods,
    required List<FundCostCharge> charges,
  }) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final fund = await DatabaseService.getFund(isin);
      if (fund == null) return;
      final updated = FundData(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        lastValue: fund.lastValue,
        currency: fund.currency,
        date: fund.date,
        history: fund.history,
        operations: fund.operations,
        alertMin: fund.alertMin,
        alertMax: fund.alertMax,
        ter: fund.ter,
        performanceFee: fund.performanceFee,
        costPeriods: periods,
        costCharges: charges,
        morningstarRating: fund.morningstarRating,
        morningstarCheckedAt: fund.morningstarCheckedAt,
        morningstarLastAttemptAt: fund.morningstarLastAttemptAt,
        source: fund.source,
        valuationSource: fund.valuationSource,
      );
      await DatabaseService.saveFund(updated);
      await loadPortfolio();
    } catch (error, stackTrace) {
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // BENCHMARKS
  // =============================================================
  Future<void> fetchBenchmark(
    String symbol, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final result = await FundScraper.getHistoryBySymbol(
        symbol,
        startDate: startDate,
        endDate: endDate,
      );
      if (result.data != null) {
        benchmarkHistory = result.data!.history;
        selectedBenchmarkSymbol = symbol;
      } else {
        lastError = result.error;
      }
    } catch (error, stackTrace) {
      lastError = _asError(error, stackTrace);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearBenchmark() {
    benchmarkHistory = null;
    selectedBenchmarkSymbol = null;
    notifyListeners();
  }

  // =============================================================
  // STATIC FETCHERS (default implementations)
  // =============================================================
  static Future<ScrapeResult> _fetchFundByRange(
    String isin,
    DateTimeRange range,
  ) {
    return FundScraper.getFundByIsin(
      isin,
      startDate: range.start,
      endDate: range.end,
    );
  }

  static Future<ScraperResult?> _fetchQueFondos(String isin) async {
    return await QueFondosScraper(client: _getHttpClient())
        .scrape(isin)
        .timeout(HttpConfig.timeout);
  }

  static Future<ScrapeResult?> _fetchFTByIsin(String isin) async {
    try {
      return await FTFundScraper(client: _getHttpClient())
          .scrapeByIsin(isin)
          .timeout(HttpConfig.timeout);
    } catch (e) {
      return null;
    }
  }

  static Future<ScraperResult?> _fetchFT(String isin) async {
    return await FTFundScraper(client: _getHttpClient())
        .scrape(isin)
        .timeout(HttpConfig.timeout);
  }

  // =============================================================
  // PARSING HELPERS
  // =============================================================
  bool _hasUsableNav(FundData? fund) =>
      fund != null && fund.lastValue.isFinite && fund.lastValue > 0;

  DateTime? _latestKnownPriceDate(FundData? fund) {
    if (fund == null) return null;

    DateTime? latestDate;
    void includeDate(DateTime date) {
      final normalized = DateTime(date.year, date.month, date.day);
      if (latestDate == null || normalized.isAfter(latestDate!)) {
        latestDate = normalized;
      }
    }

    if (_hasUsableNav(fund)) includeDate(fund.date);
    for (final point in fund.history) {
      if (point.price.isFinite && point.price > 0) includeDate(point.date);
    }
    return latestDate;
  }

  double? _parseScraperValue(String? rawValue) {
    if (rawValue == null) return null;
    final value = rawValue.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.contains(',')) {
      final isEuropeanNumber = RegExp(
        r'^(?:[0-9]{1,3}(?:\.[0-9]{3})+|[0-9]+),[0-9]+$',
      ).hasMatch(value);
      if (!isEuropeanNumber) return null;
      final parsed = double.tryParse(
        value.replaceAll('.', '').replaceAll(',', '.'),
      );
      return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
    }

    if (!RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(value)) return null;
    final parsed = double.tryParse(value);
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  DateTime? _parseScraperDate(String? rawDate) {
    if (rawDate == null) return null;
    final match = RegExp(r'^([0-9]{2})/([0-9]{2})/([0-9]{4})$')
        .firstMatch(rawDate.trim());
    if (match == null) return null;

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  // =============================================================
  // IPC
  // =============================================================
  List<IpcDataPoint>? _ipcHistory;

  List<IpcDataPoint>? get ipcHistory => _ipcHistory;

  // Ejecutar la primera vez que se vaya a calcular
  Future<void> loadIpcHistory() async {
    if (_ipcHistory != null) return;
    // Ya está en caché, no volvemos a llamar a la API

    final service = IneIpcService(client: _getHttpClient());
    _ipcHistory = await service.getAllIpcHistory();

    if (_ipcHistory!.isEmpty) {
      debugPrint('Provider ADVERTENCIA: El historial IPC se cargó vacío.');
    } else {
      debugPrint(
        'Provider: Historial IPC cargado en caché (${_ipcHistory!.length} registros).',
      );
    }
    notifyListeners();
  }

  /// Calcula la variación porcentual del IPC entre dos fechas.
  ///
  /// [startYear], [startMonth]: Fecha inicial (ej. 2021, 3 para Marzo 2021).
  /// [endYear], [endMonth]: Fecha final (ej. 2023, 10 para Octubre 2023).
  ///
  /// Devuelve la variación en porcentaje (ej. 5.5 significa un 5.5% de inflación).
  /// Devuelve `null` si falta el dato de alguna de las dos fechas (ej. mes futuro no publicado).
  /* Future<double?> getIpcVariation(
    int startYear,
    int startMonth,
    int endYear,
    int endMonth,
  ) async {
    // 'Los meses deben estar entre 1 (Enero) y 12 (Diciembre).',
    if (startMonth < 1 || startMonth > 12 || endMonth < 1 || endMonth > 12) {
      return null;
    }

    try {
      // 1. Obtenemos toda la serie histórica (la API la cacheará a nivel de red,
      // y si está en Provider, es instantáneo).
      //final history = await getAllIpcHistory();
      if (_ipcHistory == null) {
        await loadIpcHistory();
      }
      final history = _ipcHistory;
      if (history == null || history.isEmpty) {
        debugPrint(
          'IPC VARIATION: Fallo -> El historial está vacío o es null.',
        );
        return null;
      }

      // 2. Buscamos los valores del índice para ambas fechas
      // Búsqueda directa en la lista (no necesita ser async)
      final startData = history.firstWhere(
        (data) => data.year == startYear && data.month == startMonth,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );
      final endData = history.firstWhere(
        (data) => data.year == endYear && data.month == endMonth,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );

      // 3. Validamos que ambas fechas tengan datos publicados
      if (startData.year == 0 || endData.year == 0) return null;
      // Una de las fechas no tiene datos (probablemente es un mes futuro)

      // 4. Calculamos la variación porcentual
      // final variation = ((endData.value - startData.value) / startData.value) * 100;
      final variation = ((endData.value / startData.value) - 1) * 100;

      return variation;
    } catch (e) {
      //debugPrint('IPC VARIATION: Excepción no controlada -> $e');
      //debugPrint(stackTrace.toString());
      return null;
    }
  } */

  // =============================================================
  // PORTFOLIO CORRELATION MATRIX
  // =============================================================

  /// Método optimizado para calcular la matriz en un isolate secundario
  Future<void> loadCorrelationMatrix() async {
    if (portfolio.length < 2) {
      _correlationMatrix = null;
      notifyListeners();
      return;
    }

    _isCalculatingMatrix = true;
    notifyListeners();

    try {
      // 'compute' ejecuta la función en un hilo separado, evitando bloquear la UI
      _correlationMatrix = await compute(_calculateMatrixIsolate, portfolio);
    } catch (e) {
      debugPrint('Error calculando matriz de correlación: $e');
      _correlationMatrix = null;
    } finally {
      _isCalculatingMatrix = false;
      notifyListeners();
    }
  }
}

/// Esta función DEBE ser de nivel superior (top-level) o estática para que 'compute' funcione
PortfolioCorrelationMatrix _calculateMatrixIsolate(List<FundData> funds) {
  return calculatePortfolioCorrelationMatrix(funds, minDataPoints: 30);
}
