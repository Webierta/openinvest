import '../isin_resolver.dart';
import '../cnmv_local_fund_provider.dart';
import 'isin_source_provider.dart';

class CnmvFiProvider implements IsinSourceProvider {
  final CnmvLocalFundProvider _cnmvLocalFundProvider;

  CnmvFiProvider({CnmvLocalFundProvider? cnmvLocalFundProvider})
    : _cnmvLocalFundProvider = cnmvLocalFundProvider ?? CnmvLocalFundProvider();

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final cnmvFiResult = await _cnmvLocalFundProvider.resolve(
      fundName: fundName,
    );

    if (cnmvFiResult != null) {
      return IsinResult(
        isin: cnmvFiResult.isin,
        source: 'CNMV/FI local',
        officialName: cnmvFiResult.fundName,
        cnmvRegistration: cnmvFiResult.registrationNumber,
      );
    }
    return null;
  }
}
