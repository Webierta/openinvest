import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.12.4.6.2 — Límites del fallback ECB/IFS', () {
    test('un error remote de Yahoo no activa el fallback ECB/IFS', () async {
      final provider = FundProvider(
        fundIsinFetcher: (_) async => ScrapeResult(
          error: AppError.remote('El servicio de búsqueda no está disponible.'),
        ),
      );

      final result = await provider.fetchFundOnly('ES0160483014');

      expect(result.data, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.type, AppErrorType.remote);
      expect(
        result.error!.message,
        'El servicio de búsqueda no está disponible.',
      );
      expect(result.isResolved, isFalse);
      expect(result.source, isNull);
    });

    test(
      'un notFound de Yahoo se conserva si ECB/IFS tampoco conoce el ISIN',
      () async {
        final provider = FundProvider(
          fundIsinFetcher: (_) async =>
              ScrapeResult(error: AppError.notFound('ISIN no encontrado.')),
        );

        final result = await provider.fetchFundOnly('ES1000000000');

        expect(result.data, isNull);
        expect(result.error, isNotNull);
        expect(result.error!.type, AppErrorType.notFound);
        expect(result.error!.message, 'ISIN no encontrado.');
        expect(result.isResolved, isFalse);
        expect(result.source, isNull);
      },
    );
  });
}
