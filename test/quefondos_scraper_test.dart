import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/quefondos_scraper.dart';

void main() {
  test('extrae NAV y fecha cuando QueFondos separa campos en spans', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['isin'], 'ES0146722014');
      return http.Response(
        '''
<h2>IB IMPACT DIRECT DEBT, FIL B</h2>
<h4>Última valoración</h4>
<span class="floatleft">Valor liquidativo: </span><span class="floatright">0,000010 EUR</span>
<span class="floatleft">Fecha: </span><span class="floatright">20/06/2024</span>
<span class="floatleft">Divisa: </span><span class="floatright">EUR</span>
''',
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    final result = await QueFondosScraper(client: client)
        .scrape('ES0146722014');

    expect(result, isNotNull);
    expect(result!.nombre, 'IB IMPACT DIRECT DEBT, FIL B');
    expect(result.valorLiquidativo, '0,000010');
    expect(result.fecha, '20/06/2024');
    expect(result.divisa, 'EUR');
  });
}
