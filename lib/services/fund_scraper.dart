import 'dart:convert';
import 'package:http/http.dart' as http;

class PricePoint {
  final DateTime date;
  final double price;

  PricePoint(this.date, this.price);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'price': price,
  };

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
    DateTime.parse(json['date']),
    json['price'].toDouble(),
  );
}

enum OperationType { buy, sell }

class FundOperation {
  final int? id;
  final String isin;
  final DateTime date;
  final OperationType type;
  final double units;
  final double price;
  final double amount;

  FundOperation({
    this.id,
    required this.isin,
    required this.date,
    required this.type,
    required this.units,
    required this.price,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'isin': isin,
    'date': date.toIso8601String(),
    'type': type.name,
    'units': units,
    'price': price,
    'amount': amount,
  };

  factory FundOperation.fromJson(Map<String, dynamic> json) => FundOperation(
    isin: json['isin'],
    date: DateTime.parse(json['date']),
    type: json['type'] == 'buy' ? OperationType.buy : OperationType.sell,
    units: json['units'].toDouble(),
    price: json['price'].toDouble(),
    amount: json['amount']?.toDouble() ?? (json['units'] * json['price']).toDouble(),
  );
}

class FundData {
  final String isin;
  final String symbol;
  final String name;
  final double lastValue;
  final String currency;
  final DateTime date;
  final List<PricePoint> history;
  final List<FundOperation> operations;
  final double? alertMin;
  final double? alertMax;

  FundData({
    required this.isin,
    required this.symbol,
    required this.name,
    required this.lastValue,
    required this.currency,
    required this.date,
    required List<PricePoint> history,
    this.operations = const [],
    this.alertMin,
    this.alertMax,
  }) : history = _syncHistory(history, lastValue, date);

  // Asegura que lastValue esté en history y sea el punto más reciente para esa fecha
  static List<PricePoint> _syncHistory(List<PricePoint> history, double lastValue, DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final List<PricePoint> synced = List.from(history);
    
    final int existingIdx = synced.indexWhere((p) => 
      p.date.year == normalizedDate.year && 
      p.date.month == normalizedDate.month && 
      p.date.day == normalizedDate.day
    );

    if (existingIdx != -1) {
      // Reemplazamos el punto del día con el lastValue más preciso
      synced[existingIdx] = PricePoint(normalizedDate, lastValue);
    } else {
      // Si no existe el día en el historial (ej: es hoy), lo añadimos
      synced.add(PricePoint(normalizedDate, lastValue));
    }
    
    synced.sort((a, b) => a.date.compareTo(b.date));
    return synced;
  }

  Map<String, dynamic> toJson() => {
    'isin': isin,
    'symbol': symbol,
    'name': name,
    'lastValue': lastValue,
    'currency': currency,
    'date': date.toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
    'operations': operations.map((e) => e.toJson()).toList(),
    'alertMin': alertMin,
    'alertMax': alertMax,
  };

  factory FundData.fromJson(Map<String, dynamic> json) => FundData(
    isin: json['isin'],
    symbol: json['symbol'],
    name: json['name'],
    lastValue: json['lastValue'],
    currency: json['currency'],
    date: DateTime.parse(json['date']),
    history: (json['history'] as List?)?.map((e) => PricePoint.fromJson(e)).toList() ?? [],
    operations: (json['operations'] as List?)?.map((e) => FundOperation.fromJson(e)).toList() ?? [],
    alertMin: json['alertMin']?.toDouble(),
    alertMax: json['alertMax']?.toDouble(),
  );
}

class ScrapeResult {
  final FundData? data;
  final String? error;

  ScrapeResult({this.data, this.error});
}

class FundScraper {
  static const String _searchUrl = 'https://query1.finance.yahoo.com/v1/finance/search?q=';
  static const String _chartUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/';

  static final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<ScrapeResult> getFundByIsin(String isin, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final searchResponse = await http.get(Uri.parse('$_searchUrl$isin'), headers: _headers);
      if (searchResponse.statusCode != 200) return ScrapeResult(error: 'Error de búsqueda');

      final searchData = json.decode(searchResponse.body);
      final List quotes = searchData['quotes'] ?? [];
      if (quotes.isEmpty) return ScrapeResult(error: 'ISIN no encontrado');

      final firstResult = quotes.first;
      final String symbol = firstResult['symbol'];
      final String name = firstResult['longname'] ?? firstResult['shortname'] ?? 'Fondo desconocido';

      // Build chart URL
      String url = '$_chartUrl$symbol';
      if (startDate != null && endDate != null) {
        final start = startDate.millisecondsSinceEpoch ~/ 1000;
        final end = endDate.millisecondsSinceEpoch ~/ 1000;
        url += '?period1=$start&period2=$end&interval=1d';
      } else {
        url += '?range=1mo&interval=1d';
      }

      final chartResponse = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (chartResponse.statusCode != 200) return ScrapeResult(error: 'Error de cotización');

      final chartData = json.decode(chartResponse.body);
      final result = chartData['chart']?['result']?[0];
      if (result == null) return ScrapeResult(error: 'Sin datos');

      final meta = result['meta'];
      final double? price = meta['regularMarketPrice']?.toDouble();
      final String currency = meta['currency'] ?? '';
      final int? timestamp = meta['regularMarketTime'];

      // Extract history
      final List<dynamic>? timestamps = result['timestamp'];
      final List<dynamic>? closePrices = result['indicators']?['quote']?[0]['close'];
      final List<PricePoint> history = [];

      if (timestamps != null && closePrices != null) {
        for (int i = 0; i < timestamps.length; i++) {
          if (closePrices[i] != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000);
            history.add(PricePoint(
              DateTime(date.year, date.month, date.day),
              closePrices[i].toDouble(),
            ));
          }
        }
      }

      final DateTime updateDate = timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000) 
        : DateTime.now();
      final DateTime normalizedUpdateDate = DateTime(updateDate.year, updateDate.month, updateDate.day);

      if (price == null && history.isNotEmpty) {
        // Use last history point if regularMarketPrice is null (happens sometimes with ranges)
        final lastPoint = history.last;
        return ScrapeResult(
          data: FundData(
            isin: isin,
            symbol: symbol,
            name: name,
            lastValue: lastPoint.price,
            currency: currency,
            date: lastPoint.date,
            history: history,
          ),
        );
      }

      if (price == null) return ScrapeResult(error: 'Precio no disponible');

      return ScrapeResult(
        data: FundData(
          isin: isin,
          symbol: symbol,
          name: name,
          lastValue: price,
          currency: currency,
          date: normalizedUpdateDate,
          history: history,
        ),
      );
    } catch (e) {
      return ScrapeResult(error: 'Error: $e');
    }
  }

  static Future<double> getExchangeRate(String from, String to) async {
    if (from == to) return 1.0;
    try {
      final String symbol = '$from$to=X';
      final response = await http.get(Uri.parse('$_chartUrl$symbol?range=1d&interval=1d'), headers: _headers);
      if (response.statusCode != 200) return 1.0;
      
      final data = json.decode(response.body);
      final result = data['chart']?['result']?[0];
      final double? rate = result?['meta']?['regularMarketPrice']?.toDouble();
      
      return rate ?? 1.0;
    } catch (e) {
      return 1.0;
    }
  }
}
