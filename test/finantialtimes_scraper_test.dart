import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/finantialtimes_scraper.dart';

void main() {
  test('scrapeByIsin conserva el historial de precios parseado', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) {
        return http.Response('''
<h1 class="mod-tearsheet-overview__header__title">Fondo de prueba</h1>
<div>Price (EUR)112.15</div>
<div>as of October 6, 2026</div>
''', 200);
      }

      expect(request.url.path, endsWith('/historical'));
      return http.Response('''
<div class="mod-tearsheet-historical-prices">
  <table>
    <tr><th>Date</th><th>Open</th><th>High</th><th>Low</th><th>Close</th><th>Volume</th></tr>
    <tr><td><span>Tuesday, October 06, 2026</span><span>Tue, Oct 06, 2026</span></td><td>112.15</td><td>112.15</td><td>112.15</td><td>112.15</td><td></td></tr>
    <tr><td><span>Monday, October 05, 2026</span><span>Mon, Oct 05, 2026</span></td><td>112.10</td><td>112.10</td><td>112.10</td><td>112.10</td><td></td></tr>
  </table>
</div>
''', 200);
    });

    final result = await FTFundScraper(client: client)
        .scrapeByIsin('LU2597552558');

    expect(result?.data, isNotNull);
    expect(
      result!.data!.history.any(
        (point) => point.date == DateTime(2026, 10, 5) && point.price == 112.10,
      ),
      isTrue,
    );
  });
}
