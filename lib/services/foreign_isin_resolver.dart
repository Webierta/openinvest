import 'local_isin_provider.dart';

class ForeignIsinResolution {
  final String isin;
  final String fundName;
  final String? ticker;
  final String source;
  final MorningstarIds? morningstar;

  const ForeignIsinResolution({
    required this.isin,
    required this.fundName,
    this.ticker,
    required this.source,
    this.morningstar,
  });
}
