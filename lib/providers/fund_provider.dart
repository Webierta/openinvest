import 'dart:math';
import 'package:flutter/material.dart';
import '../services/fund_scraper.dart';
import '../services/database_service.dart';

enum SortCriteria { name, value, performance }

class FundProvider with ChangeNotifier {
  List<FundData> portfolio = [];
  FundData? currentFund;
  bool isLoading = false;
  String? error;
  SortCriteria sortCriteria = SortCriteria.name;

  Future<void> loadPortfolio() async {
    portfolio = await DatabaseService.getPortfolio();
    _sortPortfolio();
    if (currentFund != null) {
      currentFund = await DatabaseService.getFund(currentFund!.isin);
    }
    notifyListeners();
  }

  void setSortCriteria(SortCriteria criteria) {
    sortCriteria = criteria;
    _sortPortfolio();
    notifyListeners();
  }

  void _sortPortfolio() {
    switch (sortCriteria) {
      case SortCriteria.name:
        portfolio.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
          return perfB.compareTo(perfA); // Descendente por defecto para rendimiento
        });
        break;
    }
  }

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
    if (isin.length != 12) {
      error = 'El ISIN debe tener 12 caracteres.';
      notifyListeners();
      return ScrapeResult(error: error);
    }
    isLoading = true;
    error = null;
    notifyListeners();
    final result = await FundScraper.getFundByIsin(isin.toUpperCase());
    isLoading = false;
    error = result.error;
    notifyListeners();
    return result;
  }

  Future<void> addToPortfolio(FundData fund) async {
    await DatabaseService.saveFund(fund);
    currentFund = fund;
    await loadPortfolio();
  }

  Future<void> addOperation(FundOperation op) async {
    await DatabaseService.saveOperation(op);
    await loadPortfolio();
  }

  Future<void> deleteOperation(int id) async {
    await DatabaseService.deleteOperation(id);
    await loadPortfolio();
  }

  Future<void> deletePricePoint(String isin, DateTime date) async {
    await DatabaseService.deletePricePoint(isin, date);
    await loadPortfolio();
  }

  Future<bool> searchFund(String isin) async {
    if (isin.length != 12) {
      error = 'El ISIN debe tener 12 caracteres.';
      notifyListeners();
      return false;
    }
    isLoading = true;
    error = null;
    notifyListeners();
    final result = await FundScraper.getFundByIsin(isin.toUpperCase());
    isLoading = false;
    if (result.data != null) {
      await DatabaseService.saveFund(result.data!);
      currentFund = result.data;
      await loadPortfolio();
      return true;
    } else {
      error = result.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> searchFundByRange(String isin, DateTimeRange range) async {
    isLoading = true;
    error = null;
    notifyListeners();
    final result = await FundScraper.getFundByIsin(isin.toUpperCase(), startDate: range.start, endDate: range.end);
    isLoading = false;
    if (result.data != null) {
      await DatabaseService.saveFund(result.data!);
      currentFund = result.data;
      await loadPortfolio();
      return true;
    } else {
      error = result.error;
      notifyListeners();
      return false;
    }
  }

  void selectFund(FundData fund) {
    currentFund = fund;
    error = null;
    notifyListeners();
  }

  Future<void> removeFromPortfolio(String isin) async {
    await DatabaseService.deleteFund(isin);
    if (currentFund?.isin == isin) currentFund = null;
    await loadPortfolio();
  }

  Future<void> clearCurrentFundData() async {
    if (currentFund != null) {
      await DatabaseService.clearAllData(currentFund!.isin);
      await loadPortfolio();
    }
  }

  Future<void> clearPortfolio() async {
    await DatabaseService.clearPortfolio();
    portfolio = [];
    currentFund = null;
    notifyListeners();
  }

  Future<void> updateAllPortfolio() async {
    if (portfolio.isEmpty) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final isins = portfolio.map((f) => f.isin).toList();
      for (final isin in isins) {
        final result = await FundScraper.getFundByIsin(isin);
        if (result.data != null) await DatabaseService.saveFund(result.data!);
      }
      await loadPortfolio();
    } catch (e) {
      error = "Error al actualizar la cartera: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
