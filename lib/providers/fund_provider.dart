import 'package:flutter/material.dart';

import '../services/fund_scraper.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/isin_resolver.dart';
import '../utils/financial_calculator.dart';
import '../utils/app_error.dart';

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

  Locale? get locale => _locale;

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
          final perfA = metricsA.isAnnualized ? metricsA.tae : metricsA.profitRel;
          final perfB = metricsB.isAnnualized ? metricsB.tae : metricsB.profitRel;
          return perfB.compareTo(
            perfA,
          ); // Descendente por defecto para rendimiento
        });
        break;
    }
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
      final result = await FundScraper.getFundByIsin(isin.toUpperCase());
      if (result.error != null) {
        lastError = result.error;
        return result;
      }
      return await _tryResolveIsin(result);
    } catch (error, stackTrace) {
      final appError = _asError(error, stackTrace);
      lastError = appError;
      return ScrapeResult(error: appError);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<FundSearchMatch>> searchFunds(String query) async {
    if (isBusy) return [];
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return [];
    isLoading = true;
    _clearError();
    notifyListeners();
    try {
      return await FundScraper.searchFunds(normalizedQuery);
    } catch (error, stackTrace) {
      lastError = _asError(error, stackTrace);
      return [];
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
      final result = await FundScraper.getFundBySearchMatch(match);
      if (result.error != null) {
        lastError = result.error;
        return result;
      }
      return await _tryResolveIsin(result);
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

    final resolver = IsinResolver();
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
        );
        return ScrapeResult(data: resolvedFund, isResolved: true);
      }
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
  }

  Future<void> replaceFund(FundData fund) async {
    await _runDatabaseOperation(() async {
      await DatabaseService.replaceFund(fund);
      currentFund = fund;
      await loadPortfolio();
    });
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
      final result = await FundScraper.getFundByIsin(isin.toUpperCase());
      if (result.data != null) {
        final existingFund = await DatabaseService.getFund(result.data!.isin);
        if (existingFund != null && !_hasNewData(existingFund, result.data!)) {
          _setError(
            AppError.info(
              'Los datos ya están actualizados y no se han producido cambios.',
            ),
          );
          return true;
        }
        await _runDatabaseOperation(() async {
          await DatabaseService.saveFund(result.data!);
          currentFund = result.data;
          await _syncFundState(result.data!.isin);
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
        final result = await FundScraper.getFundByIsin(isin);
        if (result.data != null) {
          // Mantener las alertas existentes al actualizar
          final existing = portfolio.firstWhere((f) => f.isin == isin);
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
              alertMin: existing.alertMin,
              alertMax: existing.alertMax,
              ter: existing.ter,
              performanceFee: existing.performanceFee,
            );
            await DatabaseService.saveFund(updatedFund);
            await _syncFundState(isin);
          }
        } else if (updateError == null && result.error != null) {
          updateError = result.error;
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
      );
      await DatabaseService.saveFund(updated);
      await loadPortfolio();
    });
  }

  Future<void> setFees(String isin, double? ter, double? performanceFee) async {
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
        ter: ter,
        performanceFee: performanceFee,
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
