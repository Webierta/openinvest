import 'package:investing/utils/fund_name_matcher.dart';

void main() {
  const name = 'MAPFRE PRIVATE EQUITY I FCR';

  print('Original : <$name>');
  print('Normalizado: <${FundNameMatcher.normalizeName(name)}>');
}
