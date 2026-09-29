import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';
import 'package:investing/services/isin_providers/cnmv_fi_provider.dart';

class _ThrowingCnmvLocalFundProvider extends CnmvLocalFundProvider {
  @override
  Future<CnmvFundResult?> resolve({required String fundName}) async {
    throw StateError('CNMV local data failure');
  }
}

class _NullCnmvLocalFundProvider extends CnmvLocalFundProvider {
  @override
  Future<CnmvFundResult?> resolve({required String fundName}) async {
    return null;
  }
}

class _SuccessfulCnmvLocalFundProvider extends CnmvLocalFundProvider {
  @override
  Future<CnmvFundResult?> resolve({required String fundName}) async {
    return const CnmvFundResult(
      registrationNumber: 12345,
      fundName: 'Official Test Fund',
      compartmentName: 'Test Compartment',
      compartmentNumber: 1,
      fundClass: CnmvFundClass(
        number: 1,
        name: 'Test Class',
        isin: 'ES0000000013',
      ),
      managerName: 'Test Manager',
      depositaryName: 'Test Depositary',
    );
  }
}

void main() {
  group('CnmvFiProvider', () {
    test(
      'CnmvFiProvider-1 - una excepción de CnmvLocalFundProvider se propaga',
      () async {
        final provider = CnmvFiProvider(
          cnmvLocalFundProvider: _ThrowingCnmvLocalFundProvider(),
        );

        await expectLater(
          provider.resolve(ticker: 'TEST.MC', fundName: 'Test Fund'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'CNMV local data failure',
            ),
          ),
        );
      },
    );

    test('CnmvFiProvider-2 - si CnmvLocalFundProvider no encuentra el fondo devuelve null', () async {
      final provider = CnmvFiProvider(
        cnmvLocalFundProvider: _NullCnmvLocalFundProvider(),
      );

      final result = await provider.resolve(
        ticker: 'TEST.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'CnmvFiProvider-3 - transforma correctamente un resultado de CNMV local',
      () async {
        final provider = CnmvFiProvider(
          cnmvLocalFundProvider: _SuccessfulCnmvLocalFundProvider(),
        );

        final result = await provider.resolve(
          ticker: 'TEST.MC',
          fundName: 'Input Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000013');
        expect(result.source, 'CNMV/FI local');
        expect(result.officialName, 'Official Test Fund');
        expect(result.cnmvRegistration, 12345);
        expect(result.cnmvNif, isNull);
      },
    );
  });
}
