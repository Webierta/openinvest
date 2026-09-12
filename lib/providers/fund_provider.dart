import 'dart:math';

import 'package:flutter/material.dart';

import '../services/fund_scraper.dart';
import '../services/database_service.dart';
import '../utils/app_error.dart';

enum SortCriteria { name, value, performance }

class FundProvider with ChangeNotifier {
  List<FundData> portfolio = [];
  FundData? currentFund;
  bool isLoading = false;
  bool _databaseOperationInProgress = false;
  bool _portfolioLoadInProgress = false;
  bool hasPortfolioLoadError = false;
  AppError? lastError;
  SortCriteria sortCriteria = SortCriteria.name;
  Map<String, double> exchangeRates = {'EUR': 1.0};

  String? get error => lastError?.message;
  bool get isBusy => isLoading || _databaseOperationInProgress;

  void _clearError() {
    lastError = null;
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
    if (_portfolioLoadInProgress) return;
    _portfolioLoadInProgress = true;
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
    } catch (error, stackTrace) {
      hasPortfolioLoadError = true;
      _setError(_asError(error, stackTrace, type: AppErrorType.database));
    } finally {
      _portfolioLoadInProgress = false;
    }
    notifyListeners();
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
          final valA = _calculateTotalValue(a);
          final valB = _calculateTotalValue(b);
          return valB.compareTo(valA); // Descendente por defecto para valores
        });
        break;
      case SortCriteria.performance:
        portfolio.sort((a, b) {
          final perfA = _calculatePerformance(a);
          final perfB = _calculatePerformance(b);
          return perfB.compareTo(
            perfA,
          ); // Descendente por defecto para rendimiento
        });
        break;
    }
  }

  // ignore: unused_element
  double _calculateTotalValue(FundData fund) {
    double totalUnits = 0;
    for (var op in fund.operations) {
      if (op.type == OperationType.buy) {
        totalUnits += op.units;
      } else {
        totalUnits -= op.units;
      }
    }
    return totalUnits * fund.lastValue;
  }

  // ignore: unused_element
  double _calculatePerformance(FundData fund) {
    double totalUnits = 0;
    double totalInvested = 0;
    DateTime? firstOpDate;

    for (var op in fund.operations) {
      if (op.type == OperationType.buy) {
        totalUnits += op.units;
        totalInvested += op.amount;
      } else {
        totalUnits -= op.units;
        totalInvested -= op.amount;
      }
      if (firstOpDate == null || op.date.isBefore(firstOpDate)) {
        firstOpDate = op.date;
      }
    }

    if (totalInvested <= 0 || firstOpDate == null) return -999;

    final currentValue = totalUnits * fund.lastValue;
    final daysDiff = DateTime.now().difference(firstOpDate).inDays;

    // Intentar TWR (TAE)
    final firstOpPricePoint = fund.history.cast<PricePoint?>().lastWhere(
      (p) => p!.date.isBefore(firstOpDate!.add(const Duration(days: 1))),
      orElse: () => null,
    );

    double performanceTotal = 0;
    if (firstOpPricePoint != null && firstOpPricePoint.price > 0) {
      performanceTotal = (fund.lastValue / firstOpPricePoint.price) - 1;
    } else {
      // Fallback ROI
      performanceTotal = (currentValue - totalInvested) / totalInvested;
    }

    if (daysDiff >= 30) {
      final double years = daysDiff / 365.25;
      return (pow(1 + performanceTotal, 1 / years) - 1) * 100;
    } else {
      return performanceTotal * 100;
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
      if (result.error != null) lastError = result.error;
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
        await _runDatabaseOperation(() async {
          await DatabaseService.saveFund(result.data!);
          currentFund = result.data;
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
        await _runDatabaseOperation(() async {
          await DatabaseService.saveFund(result.data!);
          currentFund = result.data;
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
    _clearError();
    notifyListeners();
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
      for (final isin in isins) {
        final result = await FundScraper.getFundByIsin(isin);
        if (result.data != null) {
          // Mantener las alertas existentes al actualizar
          final existing = portfolio.firstWhere((f) => f.isin == isin);
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
          );
          await DatabaseService.saveFund(updatedFund);
        } else if (updateError == null && result.error != null) {
          updateError = result.error;
        }
      }
      await loadPortfolio();
      if (updateError != null) lastError = updateError;
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
      );
      await DatabaseService.saveFund(updated);
      await loadPortfolio();
    });
  }
}
