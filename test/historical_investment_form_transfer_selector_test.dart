import 'package:intl/intl.dart';
import 'package:investing/widgets/historical_operation_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/screens/historical_investment_form_page.dart';

void main() {
  testWidgets(
    'LF-143.10.3: permite seleccionar traspaso de entrada sin salidas '
    'compatibles con la fecha inicial',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoricalInvestmentFormPage(saveInvestment: (_, _) async {}),
        ),
      );

      await tester.tap(find.byTooltip('Añadir operación'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final dropdown = tester.widget<DropdownButton<HistoricalOperationType>>(
        find.descendant(
          of: find.byType(DropdownButtonFormField<HistoricalOperationType>),
          matching: find.byType(DropdownButton<HistoricalOperationType>),
        ),
      );

      final transferInItem = dropdown.items!.singleWhere(
        (item) => item.value == HistoricalOperationType.transferIn,
      );

      expect(transferInItem.enabled, isTrue);
    },
  );

  testWidgets('LF-143.10.4: muestra la referencia descriptiva del traspaso '
      'sin exponer su UID', (tester) async {
    const transferUid = 'transfer_fonditel_20250314_k8m2';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoricalOperationDialog(
            operation: HistoricalOperationDraft(
              date: DateTime(2025, 3, 15),
              type: HistoricalOperationType.transferIn,
              amount: 1234.56,
              transferUid: transferUid,
            ),
            dateFormat: DateFormat('dd/MM/yyyy'),
            pickDate: (_) async => null,
            parseNumber: (value) => double.tryParse(value.replaceAll(',', '.')),
            validateNumber: (value, {required label}) => null,
            generateTransferUid: () => 'unused',
            receivingInvestmentUid: 'INV-DESTINO',
            transferOperations: [
              HistoricalOperation(
                uid: 'OP-SALIDA',
                investmentUid: 'INV-ORIGEN',
                date: DateTime(2025, 3, 14),
                type: HistoricalOperationType.transferOut,
                amount: 1234.56,
                transferUid: transferUid,
              ),
            ],
            investmentNames: {
              'INV-ORIGEN': 'Fonditel Renta Fija',
              'INV-DESTINO': 'Fondo destino',
            },
            sourceInvestmentName: 'Fonditel Renta Fija',
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );

    expect(dropdown.items, hasLength(1));

    final label = (dropdown.items!.single.child as Text).data!;

    expect(label, 'Fonditel Renta Fija · 14/03/2025 · 1234,56 €');
    expect(label, isNot(contains(transferUid)));
  });
  testWidgets('LF-143.10.5: muestra la referencia descriptiva del traspaso '
      'de salida sin exponer su UID', (tester) async {
    const transferUid = 'transfer_fonditel_20250315_k8m2';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoricalOperationDialog(
            operation: HistoricalOperationDraft(
              date: DateTime(2025, 3, 15),
              type: HistoricalOperationType.transferOut,
              amount: 1234.56,
              transferUid: transferUid,
            ),
            dateFormat: DateFormat('dd/MM/yyyy'),
            pickDate: (_) async => null,
            parseNumber: (value) => double.tryParse(value.replaceAll(',', '.')),
            validateNumber: (value, {required label}) => null,
            generateTransferUid: () => 'unused',
            receivingInvestmentUid: 'INV-ORIGEN',
            transferOperations: const [],
            investmentNames: const {},
            sourceInvestmentName: 'Fonditel Renta Fija',
          ),
        ),
      ),
    );

    expect(
      find.text('Fonditel Renta Fija · 15/03/2025 · 1234,56 €'),
      findsOneWidget,
    );
    expect(find.textContaining(transferUid), findsNothing);
    expect(find.text('UID de transferencia (generado)'), findsNothing);
  });
}
