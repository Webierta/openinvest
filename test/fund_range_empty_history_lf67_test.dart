import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_range_empty_history_lf67_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
    FundProvider.disposeHttpClient();
  });

  test('LF-67.1: inicializa lastValue y date al descargar precios para un fondo sin historial', () async {
    final initialDate = DateTime(2026, 10, 1);
    final firstPriceDate = DateTime(2026, 10, 2);
    final latestPriceDate = DateTime(2026, 10, 6);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 7),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo sin historial',
      lastValue: 0,
      currency: 'EUR',
      date: initialDate,
      history: const [],
      source: FundSource.cnmv,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo sin historial',
      lastValue: 102.50,
      currency: 'EUR',
      date: latestPriceDate,
      history: [
        PricePoint(firstPriceDate, 101.25),
        PricePoint(latestPriceDate, 102.50),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.history, hasLength(2));
    expect(saved.lastValue, 102.50);
    expect(saved.date, latestPriceDate);
    expect(saved.source, FundSource.cnmv);
    //expect(saved.valuationSource, isNull);
    expect(saved.valuationSource, FundSource.yahoo);
  });

  test('LF-67.2: una descarga de rango antiguo no hace retroceder la valoración vigente', () async {
    final currentDate = DateTime(2026, 10, 15);
    final historicalDate1 = DateTime(2026, 8, 10);
    final historicalDate2 = DateTime(2026, 8, 20);

    final range = DateTimeRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 110.0,
      currency: 'EUR',
      date: currentDate,
      history: [
        PricePoint(DateTime(2026, 8, 5), 105.0),
        PricePoint(currentDate, 110.0),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 98.0,
      currency: 'EUR',
      date: historicalDate2,
      history: [
        PricePoint(historicalDate1, 97.0),
        PricePoint(historicalDate2, 98.0),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.lastValue, 110.0);
    expect(saved.date, currentDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
  });

  test(
    'LF-67.3: una descarga más reciente actualiza la valoración vigente',
    () async {
      final currentDate = DateTime(2026, 10, 10);
      final fetchedLatestDate = DateTime(2026, 10, 18);

      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 20),
      );

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo existente',
        lastValue: 110.0,
        currency: 'EUR',
        date: currentDate,
        history: [
          PricePoint(DateTime(2026, 10, 5), 105.0),
          PricePoint(currentDate, 110.0),
        ],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(existingFund);

      final fetchedFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo descargado',
        lastValue: 115.0,
        currency: 'EUR',
        date: fetchedLatestDate,
        history: [
          PricePoint(DateTime(2026, 10, 12), 112.0),
          PricePoint(fetchedLatestDate, 115.0),
        ],
        source: null,
        valuationSource: FundSource.yahoo,
      );

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
      );

      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.lastValue, 115.0);
      expect(saved.date, fetchedLatestDate);
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);
    },
  );

  test('LF-67.4: combina ambos historiales, conserva puntos externos al rango y ordena por fecha', () async {
    final date1 = DateTime(2026, 9, 1);
    final date2 = DateTime(2026, 9, 10);
    final date3 = DateTime(2026, 9, 15);
    final date4 = DateTime(2026, 9, 20);
    final date5 = DateTime(2026, 10, 10);

    final range = DateTimeRange(
      start: DateTime(2026, 9, 5),
      end: DateTime(2026, 9, 25),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 120.0,
      currency: 'EUR',
      date: date5,
      history: [
        PricePoint(date5, 120.0),
        PricePoint(date1, 100.0),
        PricePoint(date3, 115.0),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 118.0,
      currency: 'EUR',
      date: date4,
      history: [PricePoint(date4, 118.0), PricePoint(date2, 110.0)],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);

    final history = saved!.history;

    // El punto anterior al rango se conserva.
    expect(
      history.any((point) => point.date == date1 && point.price == 100.0),
      isTrue,
    );

    // Los puntos descargados se incorporan.
    expect(
      history.any((point) => point.date == date2 && point.price == 110.0),
      isTrue,
    );
    expect(
      history.any((point) => point.date == date4 && point.price == 118.0),
      isTrue,
    );

    // El punto existente que cae dentro del rango también se conserva
    // cuando la descarga no contiene esa fecha.
    expect(
      history.any((point) => point.date == date3 && point.price == 115.0),
      isTrue,
    );

    // El punto posterior al rango se conserva.
    expect(
      history.any((point) => point.date == date5 && point.price == 120.0),
      isTrue,
    );

    // El historial combinado debe estar ordenado cronológicamente.
    expect(history.map((point) => point.date).toList(), [
      date1,
      date2,
      date3,
      date4,
      date5,
    ]);

    // La valoración vigente no retrocede.
    expect(saved.lastValue, 120.0);
    expect(saved.date, date5);

    // Se conserva el origen del fondo.
    expect(saved.source, FundSource.cnmv);
  });

  test('LF-67.5: el precio descargado prevalece en fechas duplicadas sin duplicar puntos', () async {
    final oldDate = DateTime(2026, 9, 1);
    final duplicatedDate = DateTime(2026, 9, 15);
    final currentDate = DateTime(2026, 10, 10);

    final range = DateTimeRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 120.0,
      currency: 'EUR',
      date: currentDate,
      history: [
        PricePoint(oldDate, 100.0),
        PricePoint(duplicatedDate, 115.0),
        PricePoint(currentDate, 120.0),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 116.0,
      currency: 'EUR',
      date: duplicatedDate,
      history: [PricePoint(duplicatedDate, 116.0)],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);

    final matchingPoints = saved!.history
        .where((point) => point.date == duplicatedDate)
        .toList();

    expect(matchingPoints, hasLength(1));
    expect(matchingPoints.single.price, 116.0);

    expect(saved.history, hasLength(3));
    expect(saved.lastValue, 120.0);
    expect(saved.date, currentDate);
    expect(saved.source, FundSource.cnmv);
  });

  test('LF-67.6: añadir precios históricos antiguos no cambia el proveedor de la valoración vigente', () async {
    final historicalDate1 = DateTime(2026, 9, 10);
    final historicalDate2 = DateTime(2026, 9, 20);
    final currentDate = DateTime(2026, 10, 15);

    final range = DateTimeRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 125.0,
      currency: 'EUR',
      date: currentDate,
      history: [
        PricePoint(DateTime(2026, 10, 1), 120.0),
        PricePoint(currentDate, 125.0),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 105.0,
      currency: 'EUR',
      date: historicalDate2,
      history: [
        PricePoint(historicalDate1, 102.0),
        PricePoint(historicalDate2, 105.0),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.lastValue, 125.0);
    expect(saved.date, currentDate);
    expect(saved.valuationSource, FundSource.financialTimes);
    expect(saved.source, FundSource.cnmv);

    expect(
      saved.history.any(
        (point) => point.date == historicalDate1 && point.price == 102.0,
      ),
      isTrue,
    );
    expect(
      saved.history.any(
        (point) => point.date == historicalDate2 && point.price == 105.0,
      ),
      isTrue,
    );
  });

  test('LF-67.7: actualizar la valoración desde Yahoo conserva source y actualiza valuationSource', () async {
    final currentDate = DateTime(2026, 10, 10);
    final fetchedLatestDate = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 110.0,
      currency: 'EUR',
      date: currentDate,
      history: [PricePoint(currentDate, 110.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 115.0,
      currency: 'EUR',
      date: fetchedLatestDate,
      history: [
        PricePoint(DateTime(2026, 10, 12), 112.0),
        PricePoint(fetchedLatestDate, 115.0),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.lastValue, 115.0);
    expect(saved.date, fetchedLatestDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
  });

  test(
    'LF-67.8: un precio cero descargado no sustituye la valoración vigente',
    () async {
      final currentDate = DateTime(2026, 10, 10);
      final invalidLatestDate = DateTime(2026, 10, 20);

      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 25),
      );

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo existente',
        lastValue: 110.0,
        currency: 'EUR',
        date: currentDate,
        history: [PricePoint(currentDate, 110.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(existingFund);

      final fetchedFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo descargado',
        lastValue: 0.0,
        currency: 'EUR',
        date: invalidLatestDate,
        history: [PricePoint(invalidLatestDate, 0.0)],
        source: null,
        valuationSource: FundSource.yahoo,
      );

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
      );

      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.lastValue, 110.0);
      expect(saved.date, currentDate);
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      // El punto inválido no debe incorporarse al historial.
      expect(
        saved.history.any(
          (point) => point.date == invalidLatestDate && point.price == 0.0,
        ),
        isFalse,
      );
    },
  );

  test('LF-67.9: conserva los precios válidos y descarta los inválidos de una descarga mixta', () async {
    final currentDate = DateTime(2026, 10, 10);
    final validDate1 = DateTime(2026, 10, 12);
    final zeroDate = DateTime(2026, 10, 13);
    final negativeDate = DateTime(2026, 10, 14);
    final nanDate = DateTime(2026, 10, 15);
    final validDate2 = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 110.0,
      currency: 'EUR',
      date: currentDate,
      history: [PricePoint(currentDate, 110.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 118.0,
      currency: 'EUR',
      date: validDate2,
      history: [
        PricePoint(validDate2, 118.0),
        PricePoint(zeroDate, 0.0),
        PricePoint(validDate1, 112.0),
        PricePoint(negativeDate, -5.0),
        PricePoint(nanDate, double.nan),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);

    expect(saved!.lastValue, 118.0);
    expect(saved.date, validDate2);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);

    expect(
      saved.history.any(
        (point) => point.date == validDate1 && point.price == 112.0,
      ),
      isTrue,
    );
    expect(
      saved.history.any(
        (point) => point.date == validDate2 && point.price == 118.0,
      ),
      isTrue,
    );

    expect(saved.history.any((point) => point.date == zeroDate), isFalse);
    expect(saved.history.any((point) => point.date == negativeDate), isFalse);
    expect(saved.history.any((point) => point.date == nanDate), isFalse);

    expect(saved.history.map((point) => point.date).toList(), [
      currentDate,
      validDate1,
      validDate2,
    ]);
  });

  test('LF-67.10: repetir la descarga del mismo rango no duplica precios ni altera la valoración', () async {
    final initialDate = DateTime(2026, 10, 1);
    final priceDate1 = DateTime(2026, 10, 5);
    final priceDate2 = DateTime(2026, 10, 15);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 100.0,
      currency: 'EUR',
      date: initialDate,
      history: [PricePoint(initialDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 115.0,
      currency: 'EUR',
      date: priceDate2,
      history: [PricePoint(priceDate2, 115.0), PricePoint(priceDate1, 105.0)],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final firstResult = await provider.searchFundByRange(isin, range);
    expect(firstResult, isTrue);

    final firstSaved = await DatabaseService.getFund(isin);
    expect(firstSaved, isNotNull);

    final secondResult = await provider.searchFundByRange(isin, range);
    expect(secondResult, isTrue);

    final secondSaved = await DatabaseService.getFund(isin);
    expect(secondSaved, isNotNull);

    expect(secondSaved!.history, hasLength(firstSaved!.history.length));

    final dates = secondSaved.history.map((point) => point.date).toList();
    expect(dates.toSet(), hasLength(dates.length));

    expect(secondSaved.lastValue, firstSaved.lastValue);
    expect(secondSaved.date, firstSaved.date);
    expect(secondSaved.source, FundSource.cnmv);
    expect(secondSaved.valuationSource, FundSource.yahoo);

    expect(secondSaved.history.map((point) => point.date).toList(), [
      initialDate,
      priceDate1,
      priceDate2,
    ]);
  });

  test('LF-67.11: una descarga con fechas duplicadas guarda un único punto por fecha', () async {
    final currentDate = DateTime(2026, 10, 1);
    final duplicatedDate = DateTime(2026, 10, 10);
    final latestDate = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 100.0,
      currency: 'EUR',
      date: currentDate,
      history: [PricePoint(currentDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(existingFund);

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 118.0,
      currency: 'EUR',
      date: latestDate,
      history: [
        PricePoint(latestDate, 118.0),
        PricePoint(duplicatedDate, 112.0),
        PricePoint(duplicatedDate, 113.0),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);

    final duplicatePoints = saved!.history
        .where((point) => point.date == duplicatedDate)
        .toList();

    expect(duplicatePoints, hasLength(1));
    expect(duplicatePoints.single.price, 113.0);

    final dates = saved.history.map((point) => point.date).toList();
    expect(dates.toSet(), hasLength(dates.length));

    expect(dates, [currentDate, duplicatedDate, latestDate]);

    expect(saved.lastValue, 118.0);
    expect(saved.date, latestDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
  });

  test(
    'LF-67.12: ignora precios descargados fuera del rango solicitado',
    () async {
      final september25 = DateTime(2026, 9, 25);
      final october5 = DateTime(2026, 10, 5);
      final october15 = DateTime(2026, 10, 15);
      final october25 = DateTime(2026, 10, 25);

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 125.0,
        currency: 'EUR',
        date: october25,
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
        history: [
          PricePoint(september25, 95.0),
          PricePoint(october5, 105.0),
          PricePoint(october25, 125.0),
        ],
      );

      await DatabaseService.saveFund(existingFund);

      final downloadedFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 130.0,
        currency: 'EUR',
        date: october25,
        valuationSource: FundSource.yahoo,
        history: [
          // Fuera del rango: no deben reemplazar los precios existentes.
          PricePoint(september25, 90.0),

          // Dentro del rango: deben incorporarse los precios descargados.
          PricePoint(october5, 106.0),
          PricePoint(october15, 115.0),

          // Fuera del rango: no debe reemplazar la valoración vigente.
          PricePoint(october25, 130.0),
        ],
      );

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: downloadedFund),
      );

      final result = await provider.searchFundByRange(
        isin,
        DateTimeRange(
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 20),
        ),
      );

      expect(result, isTrue);

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);

      final pricesByDate = {
        for (final point in savedFund!.history)
          DateTime(point.date.year, point.date.month, point.date.day):
              point.price,
      };

      // Los precios que ya existían fuera del rango se conservan.
      expect(pricesByDate[september25], 95.0);
      expect(pricesByDate[october25], 125.0);

      // Los precios descargados dentro del rango se incorporan.
      expect(pricesByDate[october5], 106.0);
      expect(pricesByDate[october15], 115.0);

      // La valoración y su proveedor vigentes no retroceden ni se sustituyen
      // por el punto descargado que queda fuera del intervalo.
      expect(savedFund.lastValue, 125.0);
      expect(savedFund.date, october25);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.financialTimes);

      // No hay fechas duplicadas en el historial final.
      expect(
        savedFund.history
            .map(
              (point) =>
                  DateTime(point.date.year, point.date.month, point.date.day),
            )
            .toSet()
            .length,
        savedFund.history.length,
      );
    },
  );

  test(
    'LF-68.1: una descarga fallida conserva íntegramente el fondo',
    () async {
      final valuationDate = DateTime(2026, 10, 15);
      final previousDate = DateTime(2026, 10, 10);

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 125.0,
        currency: 'EUR',
        date: valuationDate,
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
        history: [
          PricePoint(previousDate, 120.0),
          PricePoint(valuationDate, 125.0),
        ],
      );

      await DatabaseService.saveFund(existingFund);

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async {
          throw Exception('Error simulado de descarga');
        },
      );

      final result = await provider.searchFundByRange(
        isin,
        DateTimeRange(
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 20),
        ),
      );

      expect(result, isFalse);

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);

      expect(savedFund!.lastValue, 125.0);
      expect(savedFund.date, valuationDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.financialTimes);

      expect(
        savedFund.history.map((point) => (point.date, point.price)).toList(),
        [(previousDate, 120.0), (valuationDate, 125.0)],
      );
    },
  );

  test(
    'LF-68.2: una descarga sin precios válidos conserva íntegramente el fondo',
    () async {
      final valuationDate = DateTime(2026, 10, 15);
      final previousDate = DateTime(2026, 10, 10);

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 125.0,
        currency: 'EUR',
        date: valuationDate,
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
        history: [
          PricePoint(previousDate, 120.0),
          PricePoint(valuationDate, 125.0),
        ],
      );

      await DatabaseService.saveFund(existingFund);

      final downloadedFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 0.0,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(DateTime(2026, 10, 16), 0.0),
          PricePoint(DateTime(2026, 10, 17), -1.0),
          PricePoint(DateTime(2026, 10, 18), double.nan),
          PricePoint(DateTime(2026, 10, 19), double.infinity),
        ],
      );

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: downloadedFund),
      );

      final result = await provider.searchFundByRange(
        isin,
        DateTimeRange(
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 20),
        ),
      );

      expect(result, isFalse);

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);

      expect(savedFund!.lastValue, 125.0);
      expect(savedFund.date, valuationDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.financialTimes);

      expect(
        savedFund.history.map((point) => (point.date, point.price)).toList(),
        [(previousDate, 120.0), (valuationDate, 125.0)],
      );
    },
  );

  test('LF-68.3: descarga mixta actualiza solo con precios válidos y conserva la identidad', () async {
    final september25 = DateTime(2026, 9, 25);
    final october5 = DateTime(2026, 10, 5);
    final october10 = DateTime(2026, 10, 10);
    final october15 = DateTime(2026, 10, 15);
    final october25 = DateTime(2026, 10, 25);

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 110.0,
      currency: 'EUR',
      date: october10,
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
      history: [
        PricePoint(september25, 95.0),
        PricePoint(october5, 105.0),
        PricePoint(october10, 110.0),
        PricePoint(october25, 125.0),
      ],
    );

    await DatabaseService.saveFund(existingFund);

    final downloadedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo descargado',
      lastValue: 115.0,
      currency: 'EUR',
      date: october15,
      valuationSource: FundSource.yahoo,
      history: [
        // Precio válido en una fecha existente: debe prevalecer.
        PricePoint(october5, 106.0),

        // Precio válido nuevo dentro del rango.
        PricePoint(october15, 115.0),

        // Precios inválidos que deben descartarse.
        PricePoint(DateTime(2026, 10, 16), 0.0),
        PricePoint(DateTime(2026, 10, 17), -1.0),
        PricePoint(DateTime(2026, 10, 18), double.nan),
        PricePoint(DateTime(2026, 10, 19), double.infinity),

        // Precio fuera del rango: no debe incorporarse.
        PricePoint(october25, 130.0),
      ],
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: downloadedFund),
    );

    final result = await provider.searchFundByRange(
      isin,
      DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 20)),
    );

    expect(result, isTrue);

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);

    // La valoración más reciente válida descargada se adopta.
    expect(savedFund!.lastValue, 115.0);
    expect(savedFund.date, october15);

    // Se conserva el origen del fondo y cambia el proveedor de valoración.
    expect(savedFund.source, FundSource.cnmv);
    expect(savedFund.valuationSource, FundSource.yahoo);

    final pricesByDate = {
      for (final point in savedFund.history)
        DateTime(point.date.year, point.date.month, point.date.day):
            point.price,
    };

    // Se conservan los precios preexistentes fuera del rango.
    expect(pricesByDate[september25], 95.0);
    expect(pricesByDate[october25], 125.0);

    // Los precios válidos dentro del rango se incorporan.
    expect(pricesByDate[october5], 106.0);
    expect(pricesByDate[october10], 110.0);
    expect(pricesByDate[october15], 115.0);

    // No se incorporan los puntos inválidos.
    expect(pricesByDate.containsKey(DateTime(2026, 10, 16)), isFalse);
    expect(pricesByDate.containsKey(DateTime(2026, 10, 17)), isFalse);
    expect(pricesByDate.containsKey(DateTime(2026, 10, 18)), isFalse);
    expect(pricesByDate.containsKey(DateTime(2026, 10, 19)), isFalse);

    // El historial queda ordenado y sin fechas duplicadas.
    final dates = savedFund.history
        .map(
          (point) =>
              DateTime(point.date.year, point.date.month, point.date.day),
        )
        .toList();

    expect(dates, orderedEquals([...dates]..sort()));
    expect(dates.toSet().length, dates.length);
  });

  test('LF-68.4: un fallo al persistir conserva íntegramente el fondo', () async {
    final previousDate = DateTime(2026, 10, 10);
    final newDate = DateTime(2026, 10, 15);

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 110.0,
      currency: 'EUR',
      date: previousDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(previousDate, 110.0)],
    );

    await DatabaseService.saveFund(existingFund);

    // Provoca un error real durante la escritura del historial.
    // saveFund debe revertir también los cambios previos de la transacción.
    final db = await DatabaseService.database;
    await db.execute('''
      CREATE TRIGGER fail_price_insert_lf684
      BEFORE INSERT ON prices
      BEGIN
        SELECT RAISE(ABORT, 'LF-68.4 simulated persistence failure');
      END
    ''');

    final downloadedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo actualizado',
      lastValue: 115.0,
      currency: 'EUR',
      date: newDate,
      valuationSource: FundSource.yahoo,
      history: [PricePoint(previousDate, 110.0), PricePoint(newDate, 115.0)],
    );

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: downloadedFund),
    );

    final result = await provider.searchFundByRange(
      isin,
      DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 20)),
    );

    expect(result, isFalse);

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);

    // La transacción fallida no debe actualizar la valoración ni los metadatos.
    expect(savedFund!.lastValue, 110.0);
    expect(savedFund.date, previousDate);
    expect(savedFund.name, 'Fondo existente');
    expect(savedFund.source, FundSource.cnmv);
    expect(savedFund.valuationSource, FundSource.financialTimes);

    // El historial persistido también debe permanecer intacto.
    expect(savedFund.history, hasLength(1));
    expect(savedFund.history.single.date, previousDate);
    expect(savedFund.history.single.price, 110.0);
  });

  test('LF-68.5: un fallo al persistir conserva el estado del proveedor en memoria', () async {
    final previousDate = DateTime(2026, 10, 10);
    final newDate = DateTime(2026, 10, 15);
    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 110.0,
      currency: 'EUR',
      date: previousDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(previousDate, 110.0)],
    );

    final downloadedFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo actualizado',
      lastValue: 115.0,
      currency: 'EUR',
      date: newDate,
      valuationSource: FundSource.yahoo,
      history: [PricePoint(previousDate, 110.0), PricePoint(newDate, 115.0)],
    );

    var nextFund = existingFund;

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: nextFund),
    );

    // Establece el estado inicial persistido y en memoria.
    final initialResult = await provider.searchFundByRange(isin, range);

    expect(initialResult, isTrue);
    expect(provider.currentFund, isNotNull);
    expect(provider.currentFund!.lastValue, 110.0);
    expect(provider.currentFund!.name, 'Fondo existente');
    expect(provider.currentFund!.valuationSource, FundSource.financialTimes);

    final db = await DatabaseService.database;

    await db.execute('''
      CREATE TRIGGER fail_price_insert_lf685
      BEFORE INSERT ON prices
      BEGIN
        SELECT RAISE(ABORT, 'LF-68.5 simulated persistence failure');
      END
    ''');

    // La siguiente descarga propone una valoración nueva.
    nextFund = downloadedFund;

    final result = await provider.searchFundByRange(isin, range);

    expect(result, isFalse);
    expect(provider.isLoading, isFalse);

    // El estado en memoria debe seguir representando el fondo original.
    final currentFund = provider.currentFund;

    expect(currentFund, isNotNull);
    expect(currentFund!.lastValue, 110.0);
    expect(currentFund.date, previousDate);
    expect(currentFund.name, 'Fondo existente');
    expect(currentFund.source, FundSource.cnmv);
    expect(currentFund.valuationSource, FundSource.financialTimes);
    expect(currentFund.history, hasLength(1));
    expect(currentFund.history.single.date, previousDate);
    expect(currentFund.history.single.price, 110.0);

    // La base de datos tampoco debe reflejar la actualización fallida.
    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.lastValue, 110.0);
    expect(savedFund.date, previousDate);
    expect(savedFund.name, 'Fondo existente');
    expect(savedFund.source, FundSource.cnmv);
    expect(savedFund.valuationSource, FundSource.financialTimes);
    expect(savedFund.history, hasLength(1));
    expect(savedFund.history.single.price, 110.0);

    provider.dispose();
  });

  test(
    'LF-68.6: el proveedor se recupera de un fallo de persistencia',
    () async {
      final previousDate = DateTime(2026, 10, 10);
      final failedDate = DateTime(2026, 10, 15);
      final recoveredDate = DateTime(2026, 10, 18);

      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 20),
      );

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo original',
        lastValue: 110.0,
        currency: 'EUR',
        date: previousDate,
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
        history: [PricePoint(previousDate, 110.0)],
      );

      final failedDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo descarga fallida',
        lastValue: 115.0,
        currency: 'EUR',
        date: failedDate,
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(previousDate, 110.0),
          PricePoint(failedDate, 115.0),
        ],
      );

      final recoveredDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo recuperado',
        lastValue: 118.0,
        currency: 'EUR',
        date: recoveredDate,
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(previousDate, 110.0),
          PricePoint(recoveredDate, 118.0),
        ],
      );

      var nextDownload = existingFund;

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: nextDownload),
      );

      try {
        // Inicializa el fondo usando el mismo proveedor que se probará.
        expect(await provider.searchFundByRange(isin, range), isTrue);
        expect(provider.currentFund!.lastValue, 110.0);

        final db = await DatabaseService.database;

        await db.execute('''
        CREATE TRIGGER fail_price_insert_lf686
        BEFORE INSERT ON prices
        BEGIN
          SELECT RAISE(ABORT, 'LF-68.6 simulated persistence failure');
        END
      ''');

        nextDownload = failedDownload;

        // La primera actualización debe fallar sin cambiar el fondo.
        expect(await provider.searchFundByRange(isin, range), isFalse);
        expect(provider.isLoading, isFalse);
        expect(provider.currentFund!.lastValue, 110.0);
        expect(provider.currentFund!.name, 'Fondo original');
        expect(
          provider.currentFund!.valuationSource,
          FundSource.financialTimes,
        );

        // Retira la causa del fallo y prueba otra descarga con el mismo proveedor.
        await db.execute('DROP TRIGGER fail_price_insert_lf686');

        nextDownload = recoveredDownload;

        expect(await provider.searchFundByRange(isin, range), isTrue);

        // La recuperación debe reflejarse tanto en memoria como en SQLite.
        final currentFund = provider.currentFund;

        expect(currentFund, isNotNull);
        expect(currentFund!.lastValue, 118.0);
        expect(currentFund.date, recoveredDate);
        expect(currentFund.name, 'Fondo recuperado');
        expect(currentFund.source, FundSource.cnmv);
        expect(currentFund.valuationSource, FundSource.yahoo);
        expect(currentFund.history.map((point) => point.date), isNotEmpty);
        expect(
          currentFund.history.any(
            (point) =>
                point.date.year == recoveredDate.year &&
                point.date.month == recoveredDate.month &&
                point.date.day == recoveredDate.day &&
                point.price == 118.0,
          ),
          isTrue,
        );
        expect(provider.isLoading, isFalse);

        final savedFund = await DatabaseService.getFund(isin);

        expect(savedFund, isNotNull);
        expect(savedFund!.lastValue, 118.0);
        expect(savedFund.date, recoveredDate);
        expect(savedFund.name, 'Fondo recuperado');
        expect(savedFund.source, FundSource.cnmv);
        expect(savedFund.valuationSource, FundSource.yahoo);
        expect(
          savedFund.history.any(
            (point) =>
                point.date.year == recoveredDate.year &&
                point.date.month == recoveredDate.month &&
                point.date.day == recoveredDate.day &&
                point.price == 118.0,
          ),
          isTrue,
        );
      } finally {
        provider.dispose();
      }
    },
  );

  test('LF-68.7: una descarga fallida no contamina el historial de la recuperación', () async {
    final initialDate = DateTime(2026, 10, 10);
    final failedDate = DateTime(2026, 10, 15);
    final recoveredDate = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final initialFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo original',
      lastValue: 110.0,
      currency: 'EUR',
      date: initialDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(initialDate, 110.0)],
    );

    final failedDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Descarga fallida',
      lastValue: 115.0,
      currency: 'EUR',
      date: failedDate,
      source: FundSource.ecb,
      valuationSource: FundSource.yahoo,
      history: [PricePoint(initialDate, 110.0), PricePoint(failedDate, 115.0)],
    );

    final recoveredDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Descarga recuperada',
      lastValue: 118.0,
      currency: 'EUR',
      date: recoveredDate,
      source: FundSource.local,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(initialDate, 110.0),
        PricePoint(recoveredDate, 118.0),
      ],
    );

    var nextDownload = initialFund;

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: nextDownload),
    );

    try {
      expect(await provider.searchFundByRange(isin, range), isTrue);

      final db = await DatabaseService.database;

      await db.execute('''
        CREATE TRIGGER fail_price_insert_lf687
        BEFORE INSERT ON prices
        BEGIN
          SELECT RAISE(ABORT, 'LF-68.7 simulated persistence failure');
        END
      ''');

      nextDownload = failedDownload;

      expect(await provider.searchFundByRange(isin, range), isFalse);

      // El intento fallido no debe cambiar el estado previo.
      expect(provider.currentFund!.lastValue, 110.0);
      expect(provider.currentFund!.name, 'Fondo original');
      expect(provider.currentFund!.source, FundSource.cnmv);
      expect(provider.currentFund!.valuationSource, FundSource.financialTimes);

      await db.execute('DROP TRIGGER fail_price_insert_lf687');

      nextDownload = recoveredDownload;

      expect(await provider.searchFundByRange(isin, range), isTrue);

      final currentFund = provider.currentFund!;

      expect(currentFund.lastValue, 118.0);
      expect(currentFund.date, recoveredDate);
      expect(currentFund.name, 'Descarga recuperada');

      // El origen persistente debe conservarse, no adoptar el del resultado.
      expect(currentFund.source, FundSource.cnmv);
      expect(currentFund.valuationSource, FundSource.yahoo);

      // Solo debe existir el historial inicial y el punto de recuperación.
      expect(
        currentFund.history.any(
          (point) =>
              point.date.year == failedDate.year &&
              point.date.month == failedDate.month &&
              point.date.day == failedDate.day &&
              point.price == 115.0,
        ),
        isFalse,
      );

      expect(
        currentFund.history.any(
          (point) =>
              point.date.year == recoveredDate.year &&
              point.date.month == recoveredDate.month &&
              point.date.day == recoveredDate.day &&
              point.price == 118.0,
        ),
        isTrue,
      );

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.lastValue, 118.0);
      expect(savedFund.name, 'Descarga recuperada');
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == failedDate.year &&
              point.date.month == failedDate.month &&
              point.date.day == failedDate.day &&
              point.price == 115.0,
        ),
        isFalse,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == recoveredDate.year &&
              point.date.month == recoveredDate.month &&
              point.date.day == recoveredDate.day &&
              point.price == 118.0,
        ),
        isTrue,
      );

      expect(provider.isLoading, isFalse);
    } finally {
      provider.dispose();
    }
  });

  test(
    'LF-68.8: repetir la descarga recuperada no duplica el historial',
    () async {
      final initialDate = DateTime(2026, 10, 10);
      final failedDate = DateTime(2026, 10, 15);
      final recoveredDate = DateTime(2026, 10, 18);

      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 20),
      );

      final initialFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo original',
        lastValue: 110.0,
        currency: 'EUR',
        date: initialDate,
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
        history: [PricePoint(initialDate, 110.0)],
      );

      final failedDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Descarga fallida',
        lastValue: 115.0,
        currency: 'EUR',
        date: failedDate,
        source: FundSource.ecb,
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(initialDate, 110.0),
          PricePoint(failedDate, 115.0),
        ],
      );

      final recoveredDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Descarga recuperada',
        lastValue: 118.0,
        currency: 'EUR',
        date: recoveredDate,
        source: FundSource.local,
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(initialDate, 110.0),
          PricePoint(recoveredDate, 118.0),
        ],
      );

      var nextDownload = initialFund;

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: nextDownload),
      );

      try {
        expect(await provider.searchFundByRange(isin, range), isTrue);

        final db = await DatabaseService.database;

        await db.execute('''
        CREATE TRIGGER fail_price_insert_lf688
        BEFORE INSERT ON prices
        BEGIN
          SELECT RAISE(ABORT, 'LF-68.8 simulated persistence failure');
        END
      ''');

        nextDownload = failedDownload;

        expect(await provider.searchFundByRange(isin, range), isFalse);
        expect(provider.currentFund!.lastValue, 110.0);

        await db.execute('DROP TRIGGER fail_price_insert_lf688');

        nextDownload = recoveredDownload;

        expect(await provider.searchFundByRange(isin, range), isTrue);

        final recoveredFund = await DatabaseService.getFund(isin);
        expect(recoveredFund, isNotNull);

        final initialRecoveredHistory =
            recoveredFund!.history
                .map(
                  (point) => (
                    year: point.date.year,
                    month: point.date.month,
                    day: point.date.day,
                    price: point.price,
                  ),
                )
                .toList()
              ..sort((a, b) {
                final dateComparison = DateTime(
                  a.year,
                  a.month,
                  a.day,
                ).compareTo(DateTime(b.year, b.month, b.day));
                return dateComparison != 0
                    ? dateComparison
                    : a.price.compareTo(b.price);
              });

        // Repetir exactamente la misma descarga con el mismo proveedor.
        expect(await provider.searchFundByRange(isin, range), isTrue);

        final finalFund = await DatabaseService.getFund(isin);

        expect(finalFund, isNotNull);
        expect(finalFund!.lastValue, 118.0);
        expect(finalFund.date, recoveredDate);
        expect(finalFund.name, 'Descarga recuperada');
        expect(finalFund.source, FundSource.cnmv);
        expect(finalFund.valuationSource, FundSource.yahoo);

        final finalHistory =
            finalFund.history
                .map(
                  (point) => (
                    year: point.date.year,
                    month: point.date.month,
                    day: point.date.day,
                    price: point.price,
                  ),
                )
                .toList()
              ..sort((a, b) {
                final dateComparison = DateTime(
                  a.year,
                  a.month,
                  a.day,
                ).compareTo(DateTime(b.year, b.month, b.day));
                return dateComparison != 0
                    ? dateComparison
                    : a.price.compareTo(b.price);
              });

        expect(finalHistory, initialRecoveredHistory);
        expect(
          finalHistory.where(
            (point) =>
                point.year == failedDate.year &&
                point.month == failedDate.month &&
                point.day == failedDate.day &&
                point.price == 115.0,
          ),
          isEmpty,
        );
        expect(
          finalHistory.where(
            (point) =>
                point.year == recoveredDate.year &&
                point.month == recoveredDate.month &&
                point.day == recoveredDate.day &&
                point.price == 118.0,
          ),
          hasLength(1),
        );

        expect(provider.currentFund!.lastValue, 118.0);
        expect(provider.currentFund!.source, FundSource.cnmv);
        expect(provider.currentFund!.valuationSource, FundSource.yahoo);
        expect(provider.isLoading, isFalse);
      } finally {
        provider.dispose();
      }
    },
  );

  test(
    'LF-68.9: un segundo fallo conserva la última recuperación válida',
    () async {
      final initialDate = DateTime(2026, 10, 10);
      final recoveredDate = DateTime(2026, 10, 18);
      final secondFailedDate = DateTime(2026, 10, 19);

      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 20),
      );

      final initialFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo original',
        lastValue: 110.0,
        currency: 'EUR',
        date: initialDate,
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
        history: [PricePoint(initialDate, 110.0)],
      );

      final firstFailedDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Primera descarga fallida',
        lastValue: 115.0,
        currency: 'EUR',
        date: DateTime(2026, 10, 15),
        source: FundSource.ecb,
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(initialDate, 110.0),
          PricePoint(DateTime(2026, 10, 15), 115.0),
        ],
      );

      final recoveredDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Recuperación válida',
        lastValue: 118.0,
        currency: 'EUR',
        date: recoveredDate,
        source: FundSource.local,
        valuationSource: FundSource.yahoo,
        history: [
          PricePoint(initialDate, 110.0),
          PricePoint(recoveredDate, 118.0),
        ],
      );

      final secondFailedDownload = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Segunda descarga fallida',
        lastValue: 121.0,
        currency: 'EUR',
        date: secondFailedDate,
        source: FundSource.ecb,
        valuationSource: FundSource.morningstar,
        history: [
          PricePoint(initialDate, 110.0),
          PricePoint(recoveredDate, 118.0),
          PricePoint(secondFailedDate, 121.0),
        ],
      );

      var nextDownload = initialFund;

      final provider = FundProvider(
        fundRangeFetcher: (_, _) async => ScrapeResult(data: nextDownload),
      );

      try {
        expect(await provider.searchFundByRange(isin, range), isTrue);

        final db = await DatabaseService.database;

        Future<void> installFailureTrigger() async {
          await db.execute('''
          CREATE TRIGGER fail_price_insert_lf689
          BEFORE INSERT ON prices
          BEGIN
            SELECT RAISE(ABORT, 'LF-68.9 simulated persistence failure');
          END
        ''');
        }

        await installFailureTrigger();
        nextDownload = firstFailedDownload;

        expect(await provider.searchFundByRange(isin, range), isFalse);
        expect(provider.currentFund!.lastValue, 110.0);

        await db.execute('DROP TRIGGER fail_price_insert_lf689');

        nextDownload = recoveredDownload;

        expect(await provider.searchFundByRange(isin, range), isTrue);
        expect(provider.currentFund!.lastValue, 118.0);
        expect(provider.currentFund!.name, 'Recuperación válida');

        // Una segunda incidencia no debe revertir la recuperación válida.
        await installFailureTrigger();
        nextDownload = secondFailedDownload;

        expect(await provider.searchFundByRange(isin, range), isFalse);
        expect(provider.isLoading, isFalse);

        final currentFund = provider.currentFund!;

        expect(currentFund.lastValue, 118.0);
        expect(currentFund.date, recoveredDate);
        expect(currentFund.name, 'Recuperación válida');
        expect(currentFund.source, FundSource.cnmv);
        expect(currentFund.valuationSource, FundSource.yahoo);

        expect(
          currentFund.history.any(
            (point) =>
                point.date.year == secondFailedDate.year &&
                point.date.month == secondFailedDate.month &&
                point.date.day == secondFailedDate.day &&
                point.price == 121.0,
          ),
          isFalse,
        );

        final savedFund = await DatabaseService.getFund(isin);

        expect(savedFund, isNotNull);
        expect(savedFund!.lastValue, 118.0);
        expect(savedFund.date, recoveredDate);
        expect(savedFund.name, 'Recuperación válida');
        expect(savedFund.source, FundSource.cnmv);
        expect(savedFund.valuationSource, FundSource.yahoo);

        expect(
          savedFund.history.any(
            (point) =>
                point.date.year == secondFailedDate.year &&
                point.date.month == secondFailedDate.month &&
                point.date.day == secondFailedDate.day &&
                point.price == 121.0,
          ),
          isFalse,
        );

        await db.execute('DROP TRIGGER fail_price_insert_lf689');
      } finally {
        provider.dispose();
      }
    },
  );

  test('LF-68.10: los fallos de persistencia conservan operaciones, alertas y costes', () async {
    final initialDate = DateTime(2026, 10, 10);
    final recoveredDate = DateTime(2026, 10, 18);
    final failedDate = DateTime(2026, 10, 19);
    final purchaseDate = DateTime(2026, 9, 20);
    final chargeDate = DateTime(2026, 10, 5);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final operation = FundOperation(
      isin: isin,
      date: purchaseDate,
      type: OperationType.buy,
      units: 10.0,
      price: 10.0,
      amount: 100.0,
    );

    final period = FundCostPeriod(
      concept: FundCostConcept.performance,
      ratePercent: 10.0,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
    );

    final charge = FundCostCharge(
      concept: FundCostConcept.performance,
      date: chargeDate,
      amount: 2.50,
      performancePeriodUid: period.uid,
    );

    final initialFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo original',
      lastValue: 110.0,
      currency: 'EUR',
      date: initialDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(initialDate, 110.0)],
      operations: [operation],
      alertMin: 90.0,
      alertMax: 130.0,
      ter: 0.75,
      performanceFee: 10.0,
      costPeriods: [period],
      costCharges: [charge],
    );

    final recoveredDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo recuperado',
      lastValue: 118.0,
      currency: 'EUR',
      date: recoveredDate,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(initialDate, 110.0),
        PricePoint(recoveredDate, 118.0),
      ],
    );

    final failedDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Descarga fallida',
      lastValue: 121.0,
      currency: 'EUR',
      date: failedDate,
      valuationSource: FundSource.morningstar,
      history: [
        PricePoint(initialDate, 110.0),
        PricePoint(recoveredDate, 118.0),
        PricePoint(failedDate, 121.0),
      ],
    );

    var nextDownload = initialFund;

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: nextDownload),
    );

    try {
      expect(await provider.searchFundByRange(isin, range), isTrue);

      final db = await DatabaseService.database;

      await db.execute('''
        CREATE TRIGGER fail_price_insert_lf6810
        BEFORE INSERT ON prices
        BEGIN
          SELECT RAISE(ABORT, 'LF-68.10 simulated persistence failure');
        END
      ''');

      nextDownload = failedDownload;

      expect(await provider.searchFundByRange(isin, range), isFalse);

      await db.execute('DROP TRIGGER fail_price_insert_lf6810');

      nextDownload = recoveredDownload;

      expect(await provider.searchFundByRange(isin, range), isTrue);

      // Provoca un segundo fallo tras la recuperación válida.
      await db.execute('''
        CREATE TRIGGER fail_price_insert_lf6810
        BEFORE INSERT ON prices
        BEGIN
          SELECT RAISE(ABORT, 'LF-68.10 simulated second failure');
        END
      ''');

      nextDownload = failedDownload;

      expect(await provider.searchFundByRange(isin, range), isFalse);
      expect(provider.isLoading, isFalse);

      final currentFund = provider.currentFund;

      expect(currentFund, isNotNull);
      expect(currentFund!.lastValue, 118.0);
      expect(currentFund.date, recoveredDate);
      expect(currentFund.name, 'Fondo recuperado');
      expect(currentFund.source, FundSource.cnmv);
      expect(currentFund.valuationSource, FundSource.yahoo);

      // Alertas y valores de costes heredados del fondo persistido.
      expect(currentFund.alertMin, 90.0);
      expect(currentFund.alertMax, 130.0);
      expect(currentFund.ter, 0.75);
      expect(currentFund.performanceFee, 10.0);

      // Operaciones y costes estructurados deben seguir intactos.
      expect(currentFund.operations, hasLength(1));
      expect(currentFund.operations.single.isin, isin);
      expect(currentFund.operations.single.units, 10.0);
      expect(currentFund.operations.single.price, 10.0);
      expect(currentFund.operations.single.amount, 100.0);

      expect(currentFund.costPeriods, hasLength(1));
      expect(currentFund.costPeriods.single.uid, period.uid);
      expect(currentFund.costPeriods.single.ratePercent, 10.0);

      expect(currentFund.costCharges, hasLength(1));
      expect(currentFund.costCharges.single.amount, 2.50);
      expect(currentFund.costCharges.single.performancePeriodUid, period.uid);

      expect(
        currentFund.history.any(
          (point) =>
              point.date.year == failedDate.year &&
              point.date.month == failedDate.month &&
              point.date.day == failedDate.day &&
              point.price == 121.0,
        ),
        isFalse,
      );

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.lastValue, 118.0);
      expect(savedFund.date, recoveredDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      expect(savedFund.alertMin, 90.0);
      expect(savedFund.alertMax, 130.0);
      expect(savedFund.ter, 0.75);
      expect(savedFund.performanceFee, 10.0);

      expect(savedFund.operations, hasLength(1));
      expect(savedFund.operations.single.units, 10.0);
      expect(savedFund.operations.single.price, 10.0);
      expect(savedFund.operations.single.amount, 100.0);

      expect(savedFund.costPeriods, hasLength(1));
      expect(savedFund.costPeriods.single.uid, period.uid);
      expect(savedFund.costPeriods.single.ratePercent, 10.0);

      expect(savedFund.costCharges, hasLength(1));
      expect(savedFund.costCharges.single.amount, 2.50);
      expect(savedFund.costCharges.single.performancePeriodUid, period.uid);

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == failedDate.year &&
              point.date.month == failedDate.month &&
              point.date.day == failedDate.day &&
              point.price == 121.0,
        ),
        isFalse,
      );

      await db.execute('DROP TRIGGER fail_price_insert_lf6810');
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.11: una descarga histórica posterior a la recuperación no hace retroceder la valoración', () async {
    final initialDate = DateTime(2026, 10, 10);
    final recoveredDate = DateTime(2026, 10, 18);
    final failedDate = DateTime(2026, 10, 19);
    final historicalDate = DateTime(2026, 10, 5);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final initialFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo original',
      lastValue: 110.0,
      currency: 'EUR',
      date: initialDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(initialDate, 110.0)],
    );

    final recoveredDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo recuperado',
      lastValue: 118.0,
      currency: 'EUR',
      date: recoveredDate,
      source: FundSource.local,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(initialDate, 110.0),
        PricePoint(recoveredDate, 118.0),
      ],
    );

    final failedDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Descarga fallida',
      lastValue: 121.0,
      currency: 'EUR',
      date: failedDate,
      valuationSource: FundSource.morningstar,
      history: [PricePoint(initialDate, 110.0), PricePoint(failedDate, 121.0)],
    );

    final historicalDownload = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Respuesta histórica',
      lastValue: 105.0,
      currency: 'EUR',
      date: historicalDate,
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(historicalDate, 105.0)],
    );

    var nextDownload = initialFund;

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: nextDownload),
    );

    try {
      expect(await provider.searchFundByRange(isin, range), isTrue);

      final db = await DatabaseService.database;

      await db.execute('''
        CREATE TRIGGER fail_price_insert_lf6811
        BEFORE INSERT ON prices
        BEGIN
          SELECT RAISE(ABORT, 'LF-68.11 simulated persistence failure');
        END
      ''');

      nextDownload = failedDownload;

      expect(await provider.searchFundByRange(isin, range), isFalse);

      await db.execute('DROP TRIGGER fail_price_insert_lf6811');

      nextDownload = recoveredDownload;

      expect(await provider.searchFundByRange(isin, range), isTrue);
      expect(provider.currentFund!.lastValue, 118.0);
      expect(provider.currentFund!.date, recoveredDate);

      // La respuesta histórica no debe reemplazar la valoración vigente.
      nextDownload = historicalDownload;

      expect(await provider.searchFundByRange(isin, range), isTrue);

      final currentFund = provider.currentFund!;

      expect(currentFund.lastValue, 118.0);
      expect(currentFund.date, recoveredDate);
      expect(currentFund.name, 'Fondo recuperado');
      expect(currentFund.source, FundSource.cnmv);
      expect(currentFund.valuationSource, FundSource.yahoo);

      // El precio histórico válido se incorpora al historial.
      expect(
        currentFund.history.any(
          (point) =>
              point.date.year == historicalDate.year &&
              point.date.month == historicalDate.month &&
              point.date.day == historicalDate.day &&
              point.price == 105.0,
        ),
        isTrue,
      );

      // Ningún precio de la descarga fallida debe haberse incorporado.
      expect(
        currentFund.history.any(
          (point) =>
              point.date.year == failedDate.year &&
              point.date.month == failedDate.month &&
              point.date.day == failedDate.day &&
              point.price == 121.0,
        ),
        isFalse,
      );

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.lastValue, 118.0);
      expect(savedFund.date, recoveredDate);
      expect(savedFund.name, 'Fondo recuperado');
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == historicalDate.year &&
              point.date.month == historicalDate.month &&
              point.date.day == historicalDate.day &&
              point.price == 105.0,
        ),
        isTrue,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == failedDate.year &&
              point.date.month == failedDate.month &&
              point.date.day == failedDate.day &&
              point.price == 121.0,
        ),
        isFalse,
      );

      expect(provider.isLoading, isFalse);
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.12: una descarga histórica conserva símbolo y moneda del fondo vigente', () async {
    final currentDate = DateTime(2026, 10, 18);
    final historicalDate = DateTime(2026, 10, 5);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'CURRENT',
      name: 'Fondo vigente',
      lastValue: 118.0,
      currency: 'EUR',
      date: currentDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 10), 110.0),
        PricePoint(currentDate, 118.0),
      ],
    );

    final historicalDownload = FundData(
      isin: isin,
      symbol: 'HISTORICAL',
      name: 'Nombre de respuesta histórica',
      lastValue: 105.0,
      currency: 'USD',
      date: historicalDate,
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(historicalDate, 105.0)],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: historicalDownload),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final currentFund = provider.currentFund;

      expect(currentFund, isNotNull);
      expect(currentFund!.symbol, 'CURRENT');
      expect(currentFund.name, 'Fondo vigente');
      expect(currentFund.currency, 'EUR');
      expect(currentFund.lastValue, 118.0);
      expect(currentFund.date, currentDate);
      expect(currentFund.source, FundSource.cnmv);
      expect(currentFund.valuationSource, FundSource.yahoo);

      // La cotización histórica sí debe incorporarse.
      expect(
        currentFund.history.any(
          (point) =>
              point.date.year == historicalDate.year &&
              point.date.month == historicalDate.month &&
              point.date.day == historicalDate.day &&
              point.price == 105.0,
        ),
        isTrue,
      );

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'CURRENT');
      expect(savedFund.name, 'Fondo vigente');
      expect(savedFund.currency, 'EUR');
      expect(savedFund.lastValue, 118.0);
      expect(savedFund.date, currentDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == historicalDate.year &&
              point.date.month == historicalDate.month &&
              point.date.day == historicalDate.day &&
              point.price == 105.0,
        ),
        isTrue,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.13: una valoración más reciente actualiza los metadatos '
      'sin cambiar el origen del fondo', () async {
    final currentDate = DateTime(2026, 10, 10);
    final fetchedDate = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'OLD_SYMBOL',
      name: 'Nombre anterior',
      lastValue: 110.0,
      currency: 'EUR',
      date: currentDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(currentDate, 110.0),
      ],
    );

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'NEW_SYMBOL',
      name: 'Nombre actualizado',
      lastValue: 118.0,
      currency: 'USD',
      date: fetchedDate,
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(fetchedDate, 118.0)],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final currentFund = provider.currentFund;

      expect(currentFund, isNotNull);
      expect(currentFund!.symbol, 'NEW_SYMBOL');
      expect(currentFund.name, 'Nombre actualizado');
      expect(currentFund.currency, 'USD');
      expect(currentFund.lastValue, 118.0);
      expect(currentFund.date, fetchedDate);

      // El origen del fondo debe permanecer intacto.
      expect(currentFund.source, FundSource.cnmv);

      // La fuente de la nueva valoración sí debe actualizarse.
      expect(currentFund.valuationSource, FundSource.financialTimes);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'NEW_SYMBOL');
      expect(savedFund.name, 'Nombre actualizado');
      expect(savedFund.currency, 'USD');
      expect(savedFund.lastValue, 118.0);
      expect(savedFund.date, fetchedDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.financialTimes);

      // El historial anterior debe conservarse junto al nuevo precio.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 5 &&
              point.price == 105.0,
        ),
        isTrue,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == fetchedDate.year &&
              point.date.month == fetchedDate.month &&
              point.date.day == fetchedDate.day &&
              point.price == 118.0,
        ),
        isTrue,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.14: una valoración con la misma fecha no sustituye '
      'la valoración vigente ni sus metadatos', () async {
    final valuationDate = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'CURRENT',
      name: 'Fondo vigente',
      lastValue: 118.0,
      currency: 'EUR',
      date: valuationDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(valuationDate, 118.0),
      ],
    );

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'DOWNLOADED',
      name: 'Nombre descargado',
      lastValue: 125.0,
      currency: 'USD',
      date: valuationDate,
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(valuationDate, 125.0)],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final currentFund = provider.currentFund;

      expect(currentFund, isNotNull);
      expect(currentFund!.symbol, 'CURRENT');
      expect(currentFund.name, 'Fondo vigente');
      expect(currentFund.currency, 'EUR');
      expect(currentFund.lastValue, 118.0);
      expect(currentFund.date, valuationDate);
      expect(currentFund.source, FundSource.cnmv);
      expect(currentFund.valuationSource, FundSource.yahoo);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'CURRENT');
      expect(savedFund.name, 'Fondo vigente');
      expect(savedFund.currency, 'EUR');
      expect(savedFund.lastValue, 118.0);
      expect(savedFund.date, valuationDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      // La fecha ya existente conserva su precio vigente.
      final pointsOnValuationDate = savedFund.history
          .where(
            (point) =>
                point.date.year == valuationDate.year &&
                point.date.month == valuationDate.month &&
                point.date.day == valuationDate.day,
          )
          .toList();

      expect(pointsOnValuationDate, hasLength(1));
      expect(pointsOnValuationDate.single.price, 118.0);

      // Los precios históricos anteriores también se conservan.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 5 &&
              point.price == 105.0,
        ),
        isTrue,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.15: selecciona el punto válido más reciente del rango '
      'sin perder el historial existente', () async {
    final currentDate = DateTime(2026, 10, 15);
    final rangeStart = DateTime(2026, 10, 1);
    final rangeEnd = DateTime(2026, 10, 20);

    final range = DateTimeRange(start: rangeStart, end: rangeEnd);

    final existingFund = FundData(
      isin: isin,
      symbol: 'CURRENT',
      name: 'Fondo vigente',
      lastValue: 115.0,
      currency: 'EUR',
      date: currentDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(currentDate, 115.0),
      ],
    );

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'UPDATED',
      name: 'Fondo actualizado',
      lastValue: 999.0,
      currency: 'USD',
      date: DateTime(2026, 10, 30),
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [
        // Punto anterior a la valoración vigente.
        PricePoint(DateTime(2026, 10, 10), 110.0),

        // Punto válido posterior a la valoración vigente.
        PricePoint(DateTime(2026, 10, 17), 117.0),

        // Precio inválido: no debe convertirse en valoración vigente.
        PricePoint(DateTime(2026, 10, 18), 0.0),

        // Fecha posterior al rango solicitado: debe ignorarse.
        PricePoint(DateTime(2026, 10, 21), 121.0),
      ],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final currentFund = provider.currentFund;

      expect(currentFund, isNotNull);
      expect(currentFund!.lastValue, 117.0);
      expect(currentFund.date, DateTime(2026, 10, 17));
      expect(currentFund.symbol, 'UPDATED');
      expect(currentFund.name, 'Fondo actualizado');
      expect(currentFund.currency, 'USD');

      // La identidad original del fondo debe mantenerse.
      expect(currentFund.source, FundSource.cnmv);

      // La valoración adoptada procede de Financial Times.
      expect(currentFund.valuationSource, FundSource.financialTimes);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.lastValue, 117.0);
      expect(savedFund.date, DateTime(2026, 10, 17));
      expect(savedFund.symbol, 'UPDATED');
      expect(savedFund.name, 'Fondo actualizado');
      expect(savedFund.currency, 'USD');
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.financialTimes);

      // Se conserva el historial previo.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 5 &&
              point.price == 105.0,
        ),
        isTrue,
      );

      // El punto válido más reciente dentro del rango se incorpora.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 17 &&
              point.price == 117.0,
        ),
        isTrue,
      );

      // El precio inválido se descarta.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 18 &&
              point.price == 0.0,
        ),
        isFalse,
      );

      // El punto posterior al rango no se incorpora.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 21 &&
              point.price == 121.0,
        ),
        isFalse,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.16: puntos inválidos o fuera del rango no sustituyen '
      'la valoración vigente ni contaminan el historial', () async {
    final currentDate = DateTime(2026, 10, 15);
    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'CURRENT',
      name: 'Fondo vigente',
      lastValue: 115.0,
      currency: 'EUR',
      date: currentDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(currentDate, 115.0),
      ],
    );

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'INVALID',
      name: 'Respuesta inválida',
      lastValue: 999.0,
      currency: 'USD',
      date: DateTime(2026, 10, 30),
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [
        // Precio cero dentro del rango.
        PricePoint(DateTime(2026, 10, 16), 0.0),

        // Precio negativo dentro del rango.
        PricePoint(DateTime(2026, 10, 17), -10.0),

        // Precio positivo, pero posterior al rango solicitado.
        PricePoint(DateTime(2026, 10, 21), 121.0),
      ],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      expect(result, isFalse);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'CURRENT');
      expect(savedFund.name, 'Fondo vigente');
      expect(savedFund.currency, 'EUR');
      expect(savedFund.lastValue, 115.0);
      expect(savedFund.date, currentDate);
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      // Se conserva el historial previo.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 5 &&
              point.price == 105.0,
        ),
        isTrue,
      );

      // Ninguno de los puntos inválidos o fuera del rango
      // debe incorporarse al historial.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 16 &&
              point.price == 0.0,
        ),
        isFalse,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 17 &&
              point.price == -10.0,
        ),
        isFalse,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 21 &&
              point.price == 121.0,
        ),
        isFalse,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.17: puntos históricos anteriores enriquecen el historial '
      'sin hacer retroceder la valoración vigente', () async {
    final currentDate = DateTime(2026, 10, 18);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'CURRENT',
      name: 'Fondo vigente',
      lastValue: 118.0,
      currency: 'EUR',
      date: currentDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(currentDate, 118.0),
      ],
    );

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'HISTORICAL',
      name: 'Respuesta histórica',
      lastValue: 112.0,
      currency: 'USD',
      date: DateTime(2026, 10, 12),
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [
        PricePoint(DateTime(2026, 10, 8), 108.0),
        PricePoint(DateTime(2026, 10, 12), 112.0),
      ],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      // La descarga es válida aunque no actualice la valoración vigente.
      expect(result, isTrue);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.lastValue, 118.0);
      expect(savedFund.date, currentDate);

      // Los metadatos de la valoración vigente deben mantenerse.
      expect(savedFund.symbol, 'CURRENT');
      expect(savedFund.name, 'Fondo vigente');
      expect(savedFund.currency, 'EUR');
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      // El historial previo se conserva.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 5 &&
              point.price == 105.0,
        ),
        isTrue,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 18 &&
              point.price == 118.0,
        ),
        isTrue,
      );

      // Los puntos históricos válidos de la descarga se incorporan.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 8 &&
              point.price == 108.0,
        ),
        isTrue,
      );

      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 12 &&
              point.price == 112.0,
        ),
        isTrue,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.18: un precio histórico descargado reemplaza el de la misma '
      'fecha sin duplicarlo ni alterar la valoración vigente', () async {
    final currentDate = DateTime(2026, 10, 18);
    final historicalDate = DateTime(2026, 10, 12);

    final range = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
    );

    final existingFund = FundData(
      isin: isin,
      symbol: 'CURRENT',
      name: 'Fondo vigente',
      lastValue: 118.0,
      currency: 'EUR',
      date: currentDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(historicalDate, 111.0),
        PricePoint(currentDate, 118.0),
      ],
    );

    final fetchedFund = FundData(
      isin: isin,
      symbol: 'HISTORICAL',
      name: 'Respuesta histórica',
      lastValue: 113.0,
      currency: 'USD',
      date: historicalDate,
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      history: [PricePoint(historicalDate, 112.5)],
    );

    await DatabaseService.saveFund(existingFund);

    final provider = FundProvider(
      fundRangeFetcher: (_, _) async => ScrapeResult(data: fetchedFund),
    );

    try {
      final result = await provider.searchFundByRange(isin, range);

      expect(result, isTrue);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.lastValue, 118.0);
      expect(savedFund.date, currentDate);

      // La identidad y la fuente de valoración vigente se mantienen.
      expect(savedFund.symbol, 'CURRENT');
      expect(savedFund.name, 'Fondo vigente');
      expect(savedFund.currency, 'EUR');
      expect(savedFund.source, FundSource.cnmv);
      expect(savedFund.valuationSource, FundSource.yahoo);

      // El precio de la fecha histórica se actualiza, sin duplicarse.
      final pointsOnHistoricalDate = savedFund.history
          .where(
            (point) =>
                point.date.year == historicalDate.year &&
                point.date.month == historicalDate.month &&
                point.date.day == historicalDate.day,
          )
          .toList();

      expect(pointsOnHistoricalDate, hasLength(1));
      expect(pointsOnHistoricalDate.single.price, 112.5);

      // La valoración vigente continúa presente una sola vez.
      final pointsOnCurrentDate = savedFund.history
          .where(
            (point) =>
                point.date.year == currentDate.year &&
                point.date.month == currentDate.month &&
                point.date.day == currentDate.day,
          )
          .toList();

      expect(pointsOnCurrentDate, hasLength(1));
      expect(pointsOnCurrentDate.single.price, 118.0);

      // El resto del historial se conserva.
      expect(
        savedFund.history.any(
          (point) =>
              point.date.year == 2026 &&
              point.date.month == 10 &&
              point.date.day == 5 &&
              point.price == 105.0,
        ),
        isTrue,
      );
    } finally {
      provider.dispose();
    }
  });

  test('LF-68.19: saveFund conserva el precio del historial cuando '
      'coincide con la fecha de lastValue', () async {
    final valuationDate = DateTime(2026, 10, 12);

    final fund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 113.0,
      currency: 'EUR',
      date: valuationDate,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(valuationDate, 112.5),
      ],
    );

    await DatabaseService.saveFund(fund);

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);

    final pointsOnValuationDate = savedFund!.history
        .where(
          (point) =>
              point.date.year == valuationDate.year &&
              point.date.month == valuationDate.month &&
              point.date.day == valuationDate.day,
        )
        .toList();

    expect(pointsOnValuationDate, hasLength(1));
    expect(pointsOnValuationDate.single.price, 112.5);
  });

  test('LF-68.20: diagnóstico del precio histórico en saveFund', () async {
    final valuationDate = DateTime(2026, 10, 12);

    final fund = FundData(
      isin: 'ES0000000001',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 113.0,
      currency: 'EUR',
      date: valuationDate,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(valuationDate, 112.5),
      ],
    );

    // print(
    //   '[LF-68.21] history tras construir FundData: '
    //   '${fund.history.map((p) => '${p.date.toIso8601String()}=${p.price}').toList()}',
    // );
    // print('[LF-68.21] lastValue=${fund.lastValue}, date=${fund.date}');

    // Comprobar el dato de entrada antes de persistirlo.
    expect(
      fund.history
          .where(
            (point) =>
                point.date.year == 2026 &&
                point.date.month == 10 &&
                point.date.day == 12,
          )
          .map((point) => point.price)
          .toList(),
      [112.5],
    );

    await DatabaseService.saveFund(fund);

    final savedFund = await DatabaseService.getFund(fund.isin);

    expect(savedFund, isNotNull);
    expect(
      savedFund!.history
          .where(
            (point) =>
                point.date.year == 2026 &&
                point.date.month == 10 &&
                point.date.day == 12,
          )
          .map((point) => point.price)
          .toList(),
      [112.5],
    );
  });
  test(
    'LF-68.21: FundData conserva el precio histórico distinto de lastValue',
    () {
      final valuationDate = DateTime(2026, 10, 12);

      final fund = FundData(
        isin: 'ES0000000001',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 113.0,
        currency: 'EUR',
        date: valuationDate,
        history: [
          PricePoint(DateTime(2026, 10, 5), 105.0),
          PricePoint(valuationDate, 112.5),
        ],
      );

      expect(fund.lastValue, 113.0);

      final sameDay = fund.history
          .where(
            (point) =>
                point.date.year == valuationDate.year &&
                point.date.month == valuationDate.month &&
                point.date.day == valuationDate.day,
          )
          .toList();

      expect(sameDay, hasLength(1));
      expect(sameDay.single.price, 112.5);
    },
  );

  test('LF-69.1: replaceFund conserva el precio histórico de la fecha de lastValue', () async {
    final valuationDate = DateTime(2026, 10, 12);

    final fund = FundData(
      isin: 'ES0000000001',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 113.0,
      currency: 'EUR',
      date: valuationDate,
      history: [
        PricePoint(DateTime(2026, 10, 5), 105.0),
        PricePoint(valuationDate, 112.5),
      ],
    );

    await DatabaseService.replaceFund(fund);

    final savedFund = await DatabaseService.getFund(fund.isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.lastValue, 113.0);

    final sameDay = savedFund.history
        .where(
          (point) =>
              point.date.year == valuationDate.year &&
              point.date.month == valuationDate.month &&
              point.date.day == valuationDate.day,
        )
        .toList();

    expect(sameDay, hasLength(1));
    expect(sameDay.single.price, 112.5);
  });

  test('LF-69.2: replaceFund no conserva operaciones antiguas ni duplica las nuevas', () async {
    final date = DateTime(2026, 10, 12);

    final original = FundData(
      isin: 'ES0000000001',
      symbol: 'TEST',
      name: 'Fondo original',
      lastValue: 110.0,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 110.0)],
      operations: [
        FundOperation(
          isin: 'ES0000000001',
          date: DateTime(2026, 10, 1),
          type: OperationType.buy,
          units: 2,
          price: 100.0,
          amount: 200.0,
        ),
      ],
    );

    await DatabaseService.saveFund(original);

    final replacement = FundData(
      isin: 'ES0000000001',
      symbol: 'TEST',
      name: 'Fondo reemplazado',
      lastValue: 115.0,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 115.0)],
      operations: [
        FundOperation(
          isin: 'ES0000000001',
          date: DateTime(2026, 10, 10),
          type: OperationType.buy,
          units: 3,
          price: 105.0,
          amount: 315.0,
        ),
      ],
    );

    await DatabaseService.replaceFund(replacement);
    final saved = await DatabaseService.getFund(replacement.isin);

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo reemplazado');
    expect(saved.operations, hasLength(1));
    expect(saved.operations.single.date, DateTime(2026, 10, 10));
    expect(saved.operations.single.units, 3);
    expect(saved.operations.single.amount, 315.0);
  });

  test(
    'LF-69.3: replaceFund reemplaza los costes de A sin modificar los de B',
    () async {
      final date = DateTime(2026, 10, 12);

      final originalA = FundData(
        isin: 'ES0000000001',
        symbol: 'A',
        name: 'Fondo A original',
        lastValue: 110.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 110.0)],
        costPeriods: [
          FundCostPeriod(
            uid: 'period-a-old',
            concept: FundCostConcept.performance, //  'Gestión antigua A',
            ratePercent: 0.75,
            basis: FundCostRateBasis.positiveProfit,
            /* valor de enum usado en tus tests */
            treatment: FundCostTreatment.chargedSeparately,
            /* valor de enum usado en tus tests */
            validFrom: DateTime(2026, 1, 1),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'charge-a-old',
            concept: FundCostConcept.performance, //'Cargo antiguo A',
            date: DateTime(2026, 10, 1),
            amount: 7.5,
          ),
        ],
      );

      final originalB = FundData(
        isin: 'ES0000000002',
        symbol: 'B',
        name: 'Fondo B',
        lastValue: 220.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 220.0)],
        costPeriods: [
          FundCostPeriod(
            uid: 'period-b',
            concept: FundCostConcept.performance, //'Gestión B',
            ratePercent: 0.40,
            basis: FundCostRateBasis.positiveProfit,
            /* valor de enum usado en tus tests */
            treatment: FundCostTreatment.chargedSeparately,
            /* valor de enum usado en tus tests */
            validFrom: DateTime(2026, 1, 1),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'charge-b',
            concept: FundCostConcept.performance, //'Cargo B',
            date: DateTime(2026, 10, 2),
            amount: 4.0,
          ),
        ],
      );

      await DatabaseService.saveFund(originalA);
      await DatabaseService.saveFund(originalB);

      final replacementA = FundData(
        isin: 'ES0000000001',
        symbol: 'A',
        name: 'Fondo A reemplazado',
        lastValue: 115.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 115.0)],
        costPeriods: [
          FundCostPeriod(
            uid: 'period-a-new',
            concept: FundCostConcept.performance, //'Gestión nueva A',
            ratePercent: 0.50,
            basis: FundCostRateBasis.positiveProfit,
            /* valor de enum usado en tus tests */
            treatment: FundCostTreatment.chargedSeparately,
            /* valor de enum usado en tus tests */
            validFrom: DateTime(2026, 1, 1),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'charge-a-new',
            concept: FundCostConcept.performance, //'Cargo nuevo A',
            date: DateTime(2026, 10, 10),
            amount: 5.0,
          ),
        ],
      );

      await DatabaseService.replaceFund(replacementA);

      final savedA = await DatabaseService.getFund(replacementA.isin);
      final savedB = await DatabaseService.getFund(originalB.isin);

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      expect(savedA!.costPeriods.map((p) => p.uid), ['period-a-new']);
      expect(savedA.costCharges.map((c) => c.uid), ['charge-a-new']);

      expect(savedB!.costPeriods.map((p) => p.uid), ['period-b']);
      expect(savedB.costCharges.map((c) => c.uid), ['charge-b']);
    },
  );

  test(
    'LF-69.4: replaceFund conserva source y valuationSource independientes',
    () async {
      final originalDate = DateTime(2026, 10, 20);
      final valuationDate = DateTime(2026, 10, 21);

      final original = FundData(
        isin: 'TEST-LF-69-4',
        symbol: 'LF694',
        name: 'Fondo LF-69.4',
        lastValue: 100.0,
        currency: 'EUR',
        date: originalDate,
        history: [PricePoint(originalDate, 100.0)],
        source: FundSource.queFondos,
        valuationSource: FundSource.queFondos,
      );

      await DatabaseService.saveFund(original);

      final replacement = FundData(
        isin: 'TEST-LF-69-4',
        symbol: 'LF694',
        name: 'Fondo LF-69.4',
        lastValue: 105.0,
        currency: 'EUR',
        date: valuationDate,
        history: [
          PricePoint(originalDate, 100.0),
          PricePoint(valuationDate, 105.0),
        ],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.replaceFund(replacement);

      final saved = await DatabaseService.getFund('TEST-LF-69-4');

      expect(saved, isNotNull);
      expect(saved!.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);
      expect(saved.source, isNot(saved.valuationSource));
    },
  );

  test(
    'LF-69.5: replaceFund conserva el origen y la valoración de otros fondos',
    () async {
      final dateA = DateTime(2026, 10, 20);
      final dateB = DateTime(2026, 10, 21);

      final fundA = FundData(
        isin: 'TEST-LF-69-5-A',
        symbol: 'LF695A',
        name: 'Fondo A',
        lastValue: 100.0,
        currency: 'EUR',
        date: dateA,
        history: [PricePoint(dateA, 100.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      final fundB = FundData(
        isin: 'TEST-LF-69-5-B',
        symbol: 'LF695B',
        name: 'Fondo B',
        lastValue: 200.0,
        currency: 'EUR',
        date: dateB,
        history: [PricePoint(dateB, 200.0)],
        source: FundSource.ecb,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(fundA);
      await DatabaseService.saveFund(fundB);

      final replacementA = FundData(
        isin: 'TEST-LF-69-5-A',
        symbol: 'LF695A',
        name: 'Fondo A actualizado',
        lastValue: 110.0,
        currency: 'EUR',
        date: dateB,
        history: [PricePoint(dateA, 100.0), PricePoint(dateB, 110.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.queFondos,
      );

      await DatabaseService.replaceFund(replacementA);

      final savedA = await DatabaseService.getFund('TEST-LF-69-5-A');
      final savedB = await DatabaseService.getFund('TEST-LF-69-5-B');

      expect(savedA, isNotNull);
      expect(savedA!.name, 'Fondo A actualizado');
      expect(savedA.lastValue, 110.0);
      expect(savedA.source, FundSource.cnmv);
      expect(savedA.valuationSource, FundSource.queFondos);

      expect(savedB, isNotNull);
      expect(savedB!.name, 'Fondo B');
      expect(savedB.lastValue, 200.0);
      expect(savedB.source, FundSource.ecb);
      expect(savedB.valuationSource, FundSource.financialTimes);
      expect(savedB.history.map((point) => point.price).toList(), [200.0]);
    },
  );

  test('LF-69.6: replaceFund no duplica fechas del historial', () async {
    final date1 = DateTime(2026, 10, 19);
    final date2 = DateTime(2026, 10, 20);
    final date3 = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-6',
      symbol: 'LF696',
      name: 'Fondo LF-69.6',
      lastValue: 100.0,
      currency: 'EUR',
      date: date2,
      history: [PricePoint(date1, 95.0), PricePoint(date2, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(original);

    final replacement = FundData(
      isin: 'TEST-LF-69-6',
      symbol: 'LF696',
      name: 'Fondo LF-69.6',
      lastValue: 102.0,
      currency: 'EUR',
      date: date3,
      history: [
        PricePoint(date1, 96.0),
        PricePoint(date2, 101.0),
        PricePoint(date3, 102.0),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.replaceFund(replacement);

    final saved = await DatabaseService.getFund('TEST-LF-69-6');

    expect(saved, isNotNull);

    final history = saved!.history;
    final dates = history
        .map(
          (point) =>
              DateTime(point.date.year, point.date.month, point.date.day),
        )
        .toList();

    expect(dates.toSet().length, dates.length);
    expect(history.length, 3);
    expect(history.map((point) => point.price).toList(), [96.0, 101.0, 102.0]);
  });

  test(
    'LF-69.7: replaceFund elimina los precios ausentes del historial nuevo',
    () async {
      final date1 = DateTime(2026, 10, 18);
      final date2 = DateTime(2026, 10, 19);
      final date3 = DateTime(2026, 10, 20);

      final original = FundData(
        isin: 'TEST-LF-69-7',
        symbol: 'LF697',
        name: 'Fondo LF-69.7',
        lastValue: 100.0,
        currency: 'EUR',
        date: date3,
        history: [
          PricePoint(date1, 90.0),
          PricePoint(date2, 95.0),
          PricePoint(date3, 100.0),
        ],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final replacement = FundData(
        isin: 'TEST-LF-69-7',
        symbol: 'LF697',
        name: 'Fondo LF-69.7',
        lastValue: 101.0,
        currency: 'EUR',
        date: date3,
        history: [PricePoint(date2, 96.0), PricePoint(date3, 101.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.replaceFund(replacement);

      final saved = await DatabaseService.getFund('TEST-LF-69-7');

      expect(saved, isNotNull);
      expect(saved!.history.length, 2);
      expect(saved.history.map((point) => point.price).toList(), [96.0, 101.0]);
      expect(saved.history.any((point) => point.date == date1), isFalse);
    },
  );

  test(
    'LF-69.8: replaceFund no conserva precios antiguos con historial vacío',
    () async {
      final oldDate = DateTime(2026, 10, 19);
      final newDate = DateTime(2026, 10, 21);

      final original = FundData(
        isin: 'TEST-LF-69-8',
        symbol: 'LF698',
        name: 'Fondo LF-69.8',
        lastValue: 100.0,
        currency: 'EUR',
        date: oldDate,
        history: [
          PricePoint(DateTime(2026, 10, 18), 90.0),
          PricePoint(oldDate, 100.0),
        ],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final replacement = FundData(
        isin: 'TEST-LF-69-8',
        symbol: 'LF698',
        name: 'Fondo LF-69.8',
        lastValue: 110.0,
        currency: 'EUR',
        date: newDate,
        history: [],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.replaceFund(replacement);

      final saved = await DatabaseService.getFund('TEST-LF-69-8');

      expect(saved, isNotNull);
      expect(saved!.lastValue, 110.0);
      expect(
        saved.history.any((point) => point.date == DateTime(2026, 10, 18)),
        isFalse,
      );
      expect(saved.history.any((point) => point.date == oldDate), isFalse);
      expect(
        saved.history.any(
          (point) =>
              point.date.year == newDate.year &&
              point.date.month == newDate.month &&
              point.date.day == newDate.day &&
              point.price == 110.0,
        ),
        isTrue,
      );
    },
  );

  test(
    'LF-69.9: replaceFund no modifica el historial de otros fondos',
    () async {
      final date1 = DateTime(2026, 10, 19);
      final date2 = DateTime(2026, 10, 20);
      final date3 = DateTime(2026, 10, 21);

      final fundA = FundData(
        isin: 'TEST-LF-69-9-A',
        symbol: 'LF699A',
        name: 'Fondo A',
        lastValue: 100.0,
        currency: 'EUR',
        date: date2,
        history: [PricePoint(date1, 95.0), PricePoint(date2, 100.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      final fundB = FundData(
        isin: 'TEST-LF-69-9-B',
        symbol: 'LF699B',
        name: 'Fondo B',
        lastValue: 200.0,
        currency: 'EUR',
        date: date3,
        history: [
          PricePoint(date1, 190.0),
          PricePoint(date2, 195.0),
          PricePoint(date3, 200.0),
        ],
        source: FundSource.ecb,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(fundA);
      await DatabaseService.saveFund(fundB);

      final replacementA = FundData(
        isin: 'TEST-LF-69-9-A',
        symbol: 'LF699A',
        name: 'Fondo A actualizado',
        lastValue: 110.0,
        currency: 'EUR',
        date: date3,
        history: [PricePoint(date2, 105.0), PricePoint(date3, 110.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.queFondos,
      );

      await DatabaseService.replaceFund(replacementA);

      final savedB = await DatabaseService.getFund('TEST-LF-69-9-B');

      expect(savedB, isNotNull);
      expect(savedB!.history.length, 3);
      expect(savedB.history.map((point) => point.price).toList(), [
        190.0,
        195.0,
        200.0,
      ]);
      expect(savedB.lastValue, 200.0);
      expect(savedB.source, FundSource.ecb);
      expect(savedB.valuationSource, FundSource.financialTimes);
    },
  );

  test('LF-69.10: replaceFund revierte los cambios si falla la inserción del historial', () async {
    final originalDate = DateTime(2026, 10, 20);
    final replacementDate = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-10',
      symbol: 'LF6910',
      name: 'Fondo original',
      lastValue: 100.0,
      currency: 'EUR',
      date: originalDate,
      history: [PricePoint(originalDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(original);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER fail_lf_69_10_price_insert
    BEFORE INSERT ON prices
    WHEN NEW.isin = 'TEST-LF-69-10'
      AND NEW.date = '${replacementDate.toIso8601String()}'
    BEGIN
      SELECT RAISE(ABORT, 'LF-69.10: fallo de inserción provocado');
    END;
  ''');

    final replacement = FundData(
      isin: 'TEST-LF-69-10',
      symbol: 'LF6910',
      name: 'Fondo reemplazado',
      lastValue: 200.0,
      currency: 'EUR',
      date: replacementDate,
      history: [PricePoint(replacementDate, 200.0)],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
    );

    await expectLater(
      DatabaseService.replaceFund(replacement),
      throwsA(anything),
    );

    final saved = await DatabaseService.getFund('TEST-LF-69-10');

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo original');
    expect(saved.lastValue, 100.0);
    expect(saved.date, originalDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.history.length, 1);
    expect(saved.history.single.price, 100.0);
  });

  test('LF-69.11: replaceFund revierte los cambios si falla la inserción de costes', () async {
    final originalDate = DateTime(2026, 10, 20);
    final replacementDate = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-11',
      symbol: 'LF6911',
      name: 'Fondo original',
      lastValue: 100.0,
      currency: 'EUR',
      date: originalDate,
      history: [PricePoint(originalDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      costCharges: [
        FundCostCharge(
          uid: 'charge-original-69-11',
          concept: FundCostConcept.management,
          date: originalDate,
          amount: 1.0,
        ),
      ],
    );

    await DatabaseService.saveFund(original);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER fail_lf_69_11_cost_insert
    BEFORE INSERT ON fund_cost_charges
    WHEN NEW.isin = 'TEST-LF-69-11'
      AND NEW.uid = 'charge-replacement-69-11'
    BEGIN
      SELECT RAISE(ABORT, 'LF-69.11: fallo de inserción de costes provocado');
    END;
  ''');

    final replacement = FundData(
      isin: 'TEST-LF-69-11',
      symbol: 'LF6911',
      name: 'Fondo reemplazado',
      lastValue: 200.0,
      currency: 'EUR',
      date: replacementDate,
      history: [PricePoint(replacementDate, 200.0)],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      costCharges: [
        FundCostCharge(
          uid: 'charge-replacement-69-11',
          concept: FundCostConcept.management,
          date: replacementDate,
          amount: 2.0,
        ),
      ],
    );

    await expectLater(
      DatabaseService.replaceFund(replacement),
      throwsA(anything),
    );

    final saved = await DatabaseService.getFund('TEST-LF-69-11');

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo original');
    expect(saved.lastValue, 100.0);
    expect(saved.date, originalDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);

    expect(saved.history.length, 1);
    expect(saved.history.single.price, 100.0);

    expect(saved.costCharges.length, 1);
    expect(saved.costCharges.single.uid, 'charge-original-69-11');
    expect(saved.costCharges.single.amount, 1.0);
  });

  test('LF-69.12: replaceFund revierte los cambios si falla la inserción de operaciones', () async {
    final originalDate = DateTime(2026, 10, 20);
    final replacementDate = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-12',
      symbol: 'LF6912',
      name: 'Fondo original',
      lastValue: 100.0,
      currency: 'EUR',
      date: originalDate,
      history: [PricePoint(originalDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      operations: [
        FundOperation(
          isin: 'TEST-LF-69-12',
          date: originalDate,
          type: OperationType.buy,
          units: 2.0,
          price: 50.0,
          amount: 100.0,
        ),
      ],
    );

    await DatabaseService.saveFund(original);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER fail_lf_69_12_operation_insert
    BEFORE INSERT ON operations
    WHEN NEW.isin = 'TEST-LF-69-12'
      AND NEW.date LIKE '2026-10-21%'
    BEGIN
      SELECT RAISE(ABORT, 'LF-69.12: fallo de inserción de operación provocado');
    END;
  ''');

    final replacement = FundData(
      isin: 'TEST-LF-69-12',
      symbol: 'LF6912',
      name: 'Fondo reemplazado',
      lastValue: 200.0,
      currency: 'EUR',
      date: replacementDate,
      history: [PricePoint(replacementDate, 200.0)],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      operations: [
        FundOperation(
          isin: 'TEST-LF-69-12',
          date: replacementDate,
          type: OperationType.buy,
          units: 4.0,
          price: 50.0,
          amount: 200.0,
        ),
      ],
    );

    await expectLater(
      DatabaseService.replaceFund(replacement),
      throwsA(anything),
    );

    final saved = await DatabaseService.getFund('TEST-LF-69-12');

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo original');
    expect(saved.lastValue, 100.0);
    expect(saved.date, originalDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);

    expect(saved.history.length, 1);
    expect(saved.history.single.price, 100.0);

    expect(saved.operations.length, 1);
    expect(saved.operations.single.date, originalDate);
    expect(saved.operations.single.units, 2.0);
    expect(saved.operations.single.amount, 100.0);
  });

  test(
    'LF-69.13: replaceFund revierte el borrado si falla la inserción del fondo',
    () async {
      final originalDate = DateTime(2026, 10, 20);
      final replacementDate = DateTime(2026, 10, 21);

      final original = FundData(
        isin: 'TEST-LF-69-13',
        symbol: 'LF6913',
        name: 'Fondo original',
        lastValue: 100.0,
        currency: 'EUR',
        date: originalDate,
        history: [PricePoint(originalDate, 100.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final db = await DatabaseService.database;

      await db.execute('''
    CREATE TRIGGER fail_lf_69_13_fund_insert
    BEFORE INSERT ON funds
    WHEN NEW.isin = 'TEST-LF-69-13'
      AND NEW.name = 'Fondo reemplazado'
    BEGIN
      SELECT RAISE(ABORT, 'LF-69.13: fallo de inserción del fondo provocado');
    END;
  ''');

      final replacement = FundData(
        isin: 'TEST-LF-69-13',
        symbol: 'LF6913',
        name: 'Fondo reemplazado',
        lastValue: 200.0,
        currency: 'EUR',
        date: replacementDate,
        history: [PricePoint(replacementDate, 200.0)],
        source: FundSource.ecb,
        valuationSource: FundSource.financialTimes,
      );

      await expectLater(
        DatabaseService.replaceFund(replacement),
        throwsA(anything),
      );

      final saved = await DatabaseService.getFund('TEST-LF-69-13');

      expect(saved, isNotNull);
      expect(saved!.name, 'Fondo original');
      expect(saved.lastValue, 100.0);
      expect(saved.date, originalDate);
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);
      expect(saved.history.length, 1);
      expect(saved.history.single.price, 100.0);
    },
  );

  test('LF-69.14: replaceFund revierte los cambios si falla la actualización de un periodo de coste', () async {
    final originalDate = DateTime(2026, 10, 20);
    final replacementDate = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-14',
      symbol: 'LF6914',
      name: 'Fondo original',
      lastValue: 100.0,
      currency: 'EUR',
      date: originalDate,
      history: [PricePoint(originalDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      costPeriods: [
        FundCostPeriod(
          uid: 'period-69-14',
          concept: FundCostConcept.performance,
          ratePercent: 5.0,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: originalDate,
        ),
      ],
    );

    await DatabaseService.saveFund(original);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER fail_lf_69_14_period_update
    BEFORE UPDATE ON fund_cost_periods
    WHEN NEW.isin = 'TEST-LF-69-14'
      AND NEW.uid = 'period-69-14'
    BEGIN
      SELECT RAISE(ABORT, 'LF-69.14: fallo de actualización de periodo provocado');
    END;
  ''');

    final replacement = FundData(
      isin: 'TEST-LF-69-14',
      symbol: 'LF6914',
      name: 'Fondo reemplazado',
      lastValue: 200.0,
      currency: 'EUR',
      date: replacementDate,
      history: [PricePoint(replacementDate, 200.0)],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      costPeriods: [
        FundCostPeriod(
          uid: 'period-69-14',
          concept: FundCostConcept.performance,
          ratePercent: 8.0,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: replacementDate,
        ),
      ],
    );

    await expectLater(
      DatabaseService.replaceFund(replacement),
      throwsA(anything),
    );

    final saved = await DatabaseService.getFund('TEST-LF-69-14');

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo original');
    expect(saved.lastValue, 100.0);
    expect(saved.date, originalDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);

    expect(saved.history.length, 1);
    expect(saved.history.single.price, 100.0);

    expect(saved.costPeriods.length, 1);
    expect(saved.costPeriods.single.uid, 'period-69-14');
    expect(saved.costPeriods.single.ratePercent, 5.0);
    expect(saved.costPeriods.single.validFrom, originalDate);
  });

  test('LF-69.15: replaceFund revierte los cambios si falla la actualización de un cargo', () async {
    final originalDate = DateTime(2026, 10, 20);
    final replacementDate = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-15',
      symbol: 'LF6915',
      name: 'Fondo original',
      lastValue: 100.0,
      currency: 'EUR',
      date: originalDate,
      history: [PricePoint(originalDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      costCharges: [
        FundCostCharge(
          uid: 'charge-69-15',
          concept: FundCostConcept.management,
          date: originalDate,
          amount: 1.0,
        ),
      ],
    );

    await DatabaseService.saveFund(original);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER fail_lf_69_15_charge_update
    BEFORE UPDATE ON fund_cost_charges
    WHEN NEW.isin = 'TEST-LF-69-15'
      AND NEW.uid = 'charge-69-15'
    BEGIN
      SELECT RAISE(ABORT, 'LF-69.15: fallo de actualización de cargo provocado');
    END;
  ''');

    final replacement = FundData(
      isin: 'TEST-LF-69-15',
      symbol: 'LF6915',
      name: 'Fondo reemplazado',
      lastValue: 200.0,
      currency: 'EUR',
      date: replacementDate,
      history: [PricePoint(replacementDate, 200.0)],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      costCharges: [
        FundCostCharge(
          uid: 'charge-69-15',
          concept: FundCostConcept.management,
          date: replacementDate,
          amount: 2.0,
        ),
      ],
    );

    await expectLater(
      DatabaseService.replaceFund(replacement),
      throwsA(anything),
    );

    final saved = await DatabaseService.getFund('TEST-LF-69-15');

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo original');
    expect(saved.lastValue, 100.0);
    expect(saved.date, originalDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);

    expect(saved.history.length, 1);
    expect(saved.history.single.price, 100.0);

    expect(saved.costCharges.length, 1);
    expect(saved.costCharges.single.uid, 'charge-69-15');
    expect(saved.costCharges.single.date, originalDate);
    expect(saved.costCharges.single.amount, 1.0);
  });

  test('LF-69.16: replaceFund revierte los cambios si falla la eliminación de un cargo', () async {
    final originalDate = DateTime(2026, 10, 20);
    final replacementDate = DateTime(2026, 10, 21);

    final original = FundData(
      isin: 'TEST-LF-69-16',
      symbol: 'LF6916',
      name: 'Fondo original',
      lastValue: 100.0,
      currency: 'EUR',
      date: originalDate,
      history: [PricePoint(originalDate, 100.0)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      costCharges: [
        FundCostCharge(
          uid: 'charge-69-16',
          concept: FundCostConcept.management,
          date: originalDate,
          amount: 1.0,
        ),
      ],
    );

    await DatabaseService.saveFund(original);

    final db = await DatabaseService.database;

    await db.execute('''
      CREATE TRIGGER fail_lf_69_16_charge_delete
      BEFORE DELETE ON fund_cost_charges
      WHEN OLD.isin = 'TEST-LF-69-16'
        AND OLD.uid = 'charge-69-16'
      BEGIN
        SELECT RAISE(
          ABORT,
          'LF-69.16: fallo de eliminación de cargo provocado'
        );
      END;
    ''');

    final replacement = FundData(
      isin: 'TEST-LF-69-16',
      symbol: 'LF6916',
      name: 'Fondo reemplazado',
      lastValue: 200.0,
      currency: 'EUR',
      date: replacementDate,
      history: [PricePoint(replacementDate, 200.0)],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
      costCharges: const [],
    );

    await expectLater(
      DatabaseService.replaceFund(replacement),
      throwsA(anything),
    );

    final saved = await DatabaseService.getFund('TEST-LF-69-16');

    expect(saved, isNotNull);
    expect(saved!.name, 'Fondo original');
    expect(saved.lastValue, 100.0);
    expect(saved.date, originalDate);
    expect(saved.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);

    expect(saved.history.length, 1);
    expect(saved.history.single.date, originalDate);
    expect(saved.history.single.price, 100.0);

    expect(saved.costCharges.length, 1);
    expect(saved.costCharges.single.uid, 'charge-69-16');
    expect(saved.costCharges.single.date, originalDate);
    expect(saved.costCharges.single.amount, 1.0);
  });
}
