import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/scraper_result.dart';
import '../services/finantialtimes_scraper.dart';
import '../services/isin_providers/ecb_ifs_provider.dart';

import '../models/fund_cost.dart';
import '../models/fund_search_mode.dart';
import '../services/fund_scraper.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/isin_resolver.dart';
import '../services/morningstar_rating.dart';
import '../services/quefondos_scraper.dart';
import '../utils/financial_calculator.dart';
import '../utils/isin_search_query.dart';
import '../utils/isin_validator.dart';
import '../utils/app_error.dart';
import '../utils/http_config.dart';

enum SortCriteria { name, value, performance }

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

// búsquedas serializadas con política latest wins
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

class FundProvider with ChangeNotifier {
  List<FundData> portfolio = [];
  FundData? currentFund;
  bool isLoading = false;
  bool _databaseOperationInProgress = false;
  Future<void>? _portfolioLoadFuture;
  bool hasPortfolioLoadError = false;
  AppError? lastError;
  SortCriteria sortCriteria = SortCriteria.name;
  Map<String, double> exchangeRates = {'EUR': 1.0};
  List<PricePoint>? benchmarkHistory;
  String? selectedBenchmarkSymbol;
  Locale? _locale;
  List<FundAlertInfo> triggeredAlerts = [];
  final Set<String> _ratingRefreshesInProgress = {};
  final Future<ScraperResult?> Function(String) _queFondosFetcher;
  final Future<ScraperResult?> Function(String) _ftFetcher;
  final Future<ScrapeResult> Function(FundSearchMatch) _fundSearchFetcher;
  final Future<ScrapeResult> Function(String) _fundIsinFetcher;
  final Future<List<FundSearchMatch>> Function(
    String query, {
    required FundSearchMode mode,
  })
  _fundSearchFunction;
  _FundSearchRequest? _pendingFundSearch;
  int _fundSearchGeneration = 0;
  bool _isFundSearchInProgress = false;

  Locale? get locale => _locale;

  final IsinResolver Function() _isinResolverFactory;

  FundProvider({
    IsinResolver Function()? isinResolverFactory,
    Future<ScraperResult?> Function(String)? queFondosFetcher,
    Future<ScraperResult?> Function(String)? ftFetcher,
    Future<ScrapeResult> Function(FundSearchMatch)? fundSearchFetcher,
    Future<ScrapeResult> Function(String)? fundIsinFetcher,
    Future<List<FundSearchMatch>> Function(
      String query, {
      required FundSearchMode mode,
    })?
    fundSearch,
  }) : _isinResolverFactory = isinResolverFactory ?? IsinResolver.new,
       _queFondosFetcher = queFondosFetcher ?? _fetchQueFondos,
       _ftFetcher = ftFetcher ?? _fetchFT,
       _fundSearchFetcher =
           fundSearchFetcher ?? FundScraper.getFundBySearchMatch,
       _fundIsinFetcher = fundIsinFetcher ?? FundScraper.getFundByIsin,
       _fundSearchFunction = fundSearch ?? FundScraper.searchFunds;

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

  String? get error =>
      lastError?.type == AppErrorType.info ? null : lastError?.message;
  String? get info =>
      lastError?.type == AppErrorType.info ? lastError?.message : null;
  bool get isBusy => isLoading || _databaseOperationInProgress;

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

  Future<void> _runDatabaseOperation(Future<void> Function() operation) async {
    if (_databaseOperationInProgress) {
      final appError = AppError.busy();
      _setError(appError);
      throw appError;
    }
    _databaseOperationInProgress = true;
    _clearError();
    notifyListeners();
    try {
      await operation();
    } catch (error, stackTrace) {
      final appError = _asError(error, stackTrace, type: AppErrorType.database);
      _setError(appError);
      throw appError;
    } finally {
      _databaseOperationInProgress = false;
      notifyListeners();
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

  Future<void> initialize() async {
    await _initializeLocale();
    await loadPortfolio();
    await refreshOnStartupIfNeeded();
    unawaited(refreshMorningstarRatingsIfNeeded());
  }

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
    );

    return ScrapeResult(data: fund, isResolved: true, source: FundSource.ecb);
  }

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
    if (_databaseOperationInProgress ||
        (isLoading && !_isFundSearchInProgress)) {
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
        );
        return ScrapeResult(
          data: resolvedFund,
          isResolved: true,
          source: fundSourceFromIsinSource(resolution.source),
        );
      }

      if (fund.hasValidIsin) return result;
    } finally {
      resolver.dispose();
    }

    return result;
  }

  Future<void> addToPortfolio(FundData fund) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.saveFund(fund);
      currentFund = fund;
      await loadPortfolio();
    });
    unawaited(_refreshMorningstarRatingIfNeeded(fund.isin));
  }

  Future<void> replaceFund(FundData fund) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.replaceFund(fund);
      currentFund = fund;
      await loadPortfolio();
    });
    unawaited(_refreshMorningstarRatingIfNeeded(fund.isin));
  }

  Future<void> addOperation(FundOperation op) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.saveOperation(op);
      await loadPortfolio();
    });
  }

  Future<void> deleteOperation(int id) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.deleteOperation(id);
      await loadPortfolio();
    });
  }

  Future<void> restoreOperation(FundOperation operation) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.restoreOperation(operation);
      await loadPortfolio();
    });
  }

  Future<void> deletePricePoint(String isin, DateTime date) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.deletePricePoint(isin, date);
      await loadPortfolio();
    });
  }

  Future<void> restorePricePoint(String isin, PricePoint point) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.restorePricePoint(isin, point);
      await loadPortfolio();
    });
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
                symbol: fetchedFund.symbol,
                name: fetchedFund.name,
                lastValue: fetchedFund.lastValue,
                currency: fetchedFund.currency,
                date: fetchedFund.date,
                history: fetchedFund.history,
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
              );
        await _runDatabaseOperation(() async {
          await DatabaseService.saveFund(fundToSave);
          currentFund = fundToSave;
          await _syncFundState(fundToSave.isin);
          await loadPortfolio();
        });
        return true;
      }
      lastError = result.error;
      return false;
    } catch (error, stackTrace) {
      lastError = _asError(error, stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool _hasNewData(FundData existing, FundData fetched) {
    if (existing.lastValue != fetched.lastValue ||
        existing.date != fetched.date) {
      return true;
    }

    final existingPrices = <DateTime, double>{
      for (final point in existing.history)
        DateTime(point.date.year, point.date.month, point.date.day):
            point.price,
    };
    return fetched.history.any((point) {
      final date = DateTime(point.date.year, point.date.month, point.date.day);
      return existingPrices[date] != point.price;
    });
  }

  static Future<ScraperResult?> _fetchQueFondos(String isin) async {
    final client = http.Client();
    try {
      return await QueFondosScraper(client: client)
          .scrape(isin)
          .timeout(HttpConfig.timeout);
    } finally {
      client.close();
    }
  }

  static Future<ScraperResult?> _fetchFT(String isin) async {
    final client = http.Client();
    try {
      return await FTFundScraper(client: client)
          .scrape(isin)
          .timeout(HttpConfig.timeout);
    } finally {
      client.close();
    }
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
          source: primaryResult.source,
        );
      }

      if (primaryImprovesExisting) return primaryResult;
    }

    if (fallbackFund == null && !primaryResult.isResolved) {
      fallbackError ??= AppError.data(
        'QueFondos y Financial Times no devolvieron una valoración válida.',
      );
    }

    if (existingFund != null) {
      return ScrapeResult(
        data: existingFund,
        error: existingHasNav ? null : fallbackError,
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

  // FundData? _fundFromQueFondos(
  FundData? _fundFromScraper(
    String isin,
    ScraperResult? result, {
    FundData? existingFund,
    FundData? primaryFund,
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
    );
  }

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

  Future<bool> searchFundByRange(String isin, DateTimeRange range) async {
    if (isBusy) {
      _setError(AppError.busy());
      return false;
    }
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final result = await FundScraper.getFundByIsin(
        isin.toUpperCase(),
        startDate: range.start,
        endDate: range.end,
      );
      if (result.data != null) {
        final fetchedFund = result.data!;
        final existingFund = await DatabaseService.getFund(fetchedFund.isin);
        final fundToSave = existingFund == null
            ? fetchedFund
            : FundData(
                isin: fetchedFund.isin,
                symbol: fetchedFund.symbol,
                name: fetchedFund.name,
                lastValue: existingFund.lastValue,
                currency: fetchedFund.currency,
                date: existingFund.date,
                history: fetchedFund.history,
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
              );
        await _runDatabaseOperation(() async {
          await DatabaseService.saveFund(fundToSave);
          currentFund = fundToSave;
          await _syncFundState(fundToSave.isin);
          await loadPortfolio();
        });
        return true;
      }
      lastError = result.error;
      return false;
    } catch (error, stackTrace) {
      lastError = _asError(error, stackTrace);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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

  Future<void> removeFromPortfolio(String isin) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.deleteFund(isin);
      if (currentFund?.isin == isin) currentFund = null;
      await loadPortfolio();
    });
  }

  Future<void> clearCurrentFundData() async {
    if (currentFund != null) {
      await _runDatabaseOperation(() async {
        await DatabaseService.clearAllData(currentFund!.isin);
        await loadPortfolio();
      });
    }
  }

  Future<void> clearPortfolio() async {
    await _runDatabaseOperation(() async {
      await DatabaseService.clearPortfolio();
      portfolio = [];
      currentFund = null;
      notifyListeners();
    });
  }

  Future<void> updateAllPortfolio() async {
    if (portfolio.isEmpty || isBusy) return;
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      final isins = portfolio.map((f) => f.isin).toList();
      AppError? updateError;
      var hasChanges = false;
      for (final isin in isins) {
        final existing = portfolio.firstWhere((f) => f.isin == isin);
        final result = await _fetchLatestFundWithFallback(
          isin,
          existingFund: existing,
        );
        if (result.error != null && updateError == null) {
          updateError = result.error;
        }
        if (result.data != null) {
          // Mantener las alertas existentes al actualizar
          if (_hasNewData(existing, result.data!)) {
            hasChanges = true;
            final updatedFund = FundData(
              isin: result.data!.isin,
              symbol: result.data!.symbol,
              name: result.data!.name,
              lastValue: result.data!.lastValue,
              currency: result.data!.currency,
              date: result.data!.date,
              history: result.data!.history,
              operations: existing.operations,
              alertMin: existing.alertMin,
              alertMax: existing.alertMax,
              ter: existing.ter,
              performanceFee: existing.performanceFee,
              costPeriods: existing.costPeriods,
              costCharges: existing.costCharges,
              morningstarRating: existing.morningstarRating,
              morningstarCheckedAt: existing.morningstarCheckedAt,
              morningstarLastAttemptAt: existing.morningstarLastAttemptAt,
            );
            await DatabaseService.saveFund(updatedFund);
            await _syncFundState(isin);
          }
        }
      }
      await loadPortfolio();
      if (updateError != null) lastError = updateError;
      if (updateError == null && !hasChanges) {
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

  Future<void> setAlerts(String isin, double? min, double? max) async {
    await _runDatabaseOperation(() async {
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
      );
      await DatabaseService.saveFund(updated);
      await loadPortfolio();
    });
  }

  Future<void> setFundCosts(
    String isin, {
    required List<FundCostPeriod> periods,
    required List<FundCostCharge> charges,
  }) async {
    await _runDatabaseOperation(() async {
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
      );
      await DatabaseService.saveFund(updated);
      await loadPortfolio();
    });
  }

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
}
