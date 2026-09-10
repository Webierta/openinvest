import 'package:flutter/material.dart';
import '../services/fund_scraper.dart';
import '../services/database_service.dart';

class FundProvider with ChangeNotifier {
  List<FundData> portfolio = [];
  FundData? currentFund;
  bool isLoading = false;
  String? error;

  Future<void> loadPortfolio() async {
    portfolio = await DatabaseService.getPortfolio();
    portfolio.sort((a, b) => a.name.compareTo(b.name));
    if (currentFund != null) {
      currentFund = await DatabaseService.getFund(currentFund!.isin);
    }
    notifyListeners();
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
