import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_search_mode.dart';

void main() {
  group('FundSearchMode', () {
    test('contiene exactamente los modos name e isin', () {
      expect(FundSearchMode.values, [FundSearchMode.name, FundSearchMode.isin]);
    });

    test('name representa la búsqueda por nombre', () {
      expect(FundSearchMode.name.name, 'name');
    });

    test('isin representa la búsqueda por ISIN', () {
      expect(FundSearchMode.isin.name, 'isin');
    });
  });
}
