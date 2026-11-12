import 'package:flutter/material.dart';
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
}
