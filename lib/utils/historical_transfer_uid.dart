import 'package:intl/intl.dart';

class HistoricalTransferUid {
  static String generate({
    required String investmentName,
    required DateTime date,
    required String uniqueSuffix,
  }) {
    final normalizedName = investmentName
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final abbreviatedName = normalizedName.length > 24
        ? normalizedName.substring(0, 24).replaceAll(RegExp(r'_+$'), '')
        : normalizedName;

    final datePart = DateFormat('yyyyMMdd').format(date);

    return 'transfer_${abbreviatedName}_${datePart}_$uniqueSuffix';
  }
}
