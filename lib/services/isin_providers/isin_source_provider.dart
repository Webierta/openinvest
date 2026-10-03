import '../isin_resolver.dart';

abstract interface class IsinSourceProvider {
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  });

  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  });
}
