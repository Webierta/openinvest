import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';
import 'package:investing/services/isin_providers/cnmv_fi_provider.dart';

class _ThrowingCnmvLocalFundProvider extends CnmvLocalFundProvider {
  final Object error;

  _ThrowingCnmvLocalFundProvider(this.error);

  @override
  Future<CnmvFundResult?> resolve({required String fundName}) async {
    throw error;
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
        isin: 'ES0000000010',
      ),
      managerName: 'Test Manager',
      depositaryName: 'Test Depositary',
    );
  }
}

class _SequenceCnmvLocalFundProvider extends CnmvLocalFundProvider {
  final List<Object?> _responses;
  int calls = 0;

  _SequenceCnmvLocalFundProvider(this._responses);

  @override
  Future<CnmvFundResult?> resolve({required String fundName}) async {
    final response = _responses[calls];
    calls++;

    if (response is Object && response is! CnmvFundResult) {
      throw response;
    }

    return response as CnmvFundResult?;
  }
}

void main() {
  group('CnmvFiProvider', () {
    test(
      'FI-1 - si CnmvLocalFundProvider no encuentra el fondo devuelve null',
      () async {
        final provider = CnmvFiProvider(
          cnmvLocalFundProvider: _NullCnmvLocalFundProvider(),
        );

        final result = await provider.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test(
      'FI-2 - transforma correctamente un resultado de CNMV local',
      () async {
        final provider = CnmvFiProvider(
          cnmvLocalFundProvider: _SuccessfulCnmvLocalFundProvider(),
        );

        final result = await provider.resolve(
          ticker: 'TEST.MC',
          fundName: 'Input Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000010');
        expect(result.source, 'CNMV/FI local');
        expect(result.officialName, 'Official Test Fund');
        expect(result.cnmvRegistration, 12345);
        expect(result.cnmvNif, isNull);
      },
    );

    test(
      'FI-3 - una excepción del proveedor local se convierte en null',
      () async {
        final provider = CnmvFiProvider(
          cnmvLocalFundProvider: _ThrowingCnmvLocalFundProvider(
            StateError('CNMV local data failure'),
          ),
        );

        final result = await provider.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test('FI-4 - un Error del proveedor local se convierte en null', () async {
      final provider = CnmvFiProvider(
        cnmvLocalFundProvider: _ThrowingCnmvLocalFundProvider(
          AssertionError('CNMV local assertion failure'),
        ),
      );

      final result = await provider.resolve(
        ticker: 'TEST.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'FI-5 - tras una excepción puede volver a resolver correctamente',
      () async {
        final localProvider = _SequenceCnmvLocalFundProvider([
          StateError('CNMV local temporary failure'),
          const CnmvFundResult(
            registrationNumber: 54321,
            fundName: 'Recovered Fund',
            compartmentName: 'Recovered Compartment',
            compartmentNumber: 2,
            fundClass: CnmvFundClass(
              number: 2,
              name: 'Recovered Class',
              isin: 'ES0000000010',
            ),
            managerName: 'Recovered Manager',
            depositaryName: 'Recovered Depositary',
          ),
        ]);

        final provider = CnmvFiProvider(cnmvLocalFundProvider: localProvider);

        final firstResult = await provider.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(firstResult, isNull);
        expect(localProvider.calls, 1);

        final secondResult = await provider.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(secondResult, isNotNull);
        expect(secondResult!.isin, 'ES0000000010');
        expect(secondResult.source, 'CNMV/FI local');
        expect(secondResult.officialName, 'Recovered Fund');
        expect(secondResult.cnmvRegistration, 54321);
        expect(secondResult.cnmvNif, isNull);
        expect(localProvider.calls, 2);
      },
    );
  });
}
