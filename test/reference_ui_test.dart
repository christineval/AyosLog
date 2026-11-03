import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:ayoslog/core/database/app_database.dart' show MaintenancePlan;
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/domain/entities/asset.dart';
import 'package:ayoslog/features/assets/presentation/views/add_asset_page.dart';
import 'package:ayoslog/features/assets/presentation/views/asset_detail_page.dart';
import 'package:ayoslog/features/calendar/presentation/views/calendar_page.dart';
import 'package:ayoslog/features/maintenance/domain/service_history.dart';
import 'package:ayoslog/features/maintenance/presentation/views/add_service_page.dart';
import 'package:ayoslog/features/maintenance/presentation/views/service_record_page.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_asset_repository.dart';
import 'helpers/fake_prediction_repository.dart';
import 'helpers/fake_service_history_repository.dart';
import 'helpers/fake_forecast_repository.dart';
import 'package:ayoslog/features/predictions/presentation/forecast_providers.dart';
import 'package:ayoslog/features/predictions/domain/forecast_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages = (jsonDecode(await config.readAsString())
        as Map<String, dynamic>)['packages'] as List;
    final flutter = packages
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final sdk =
        Directory.fromUri(config.uri.resolve(flutter['rootUri'] as String))
            .parent
            .parent
            .path;
    final fonts = '$sdk/bin/cache/artifacts/material_fonts';
    final text = FontLoader('Roboto');
    final fallback = FontLoader('Ahem');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf'
    ]) {
      final font = File('$fonts/$name')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes));
      text.addFont(font);
      fallback.addFont(font);
    }
    await text.load();
    await fallback.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(File('$fonts/materialicons-regular.otf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
    await icons.load();
  });
  final asset = Asset(
      id: 'a',
      name: 'Honda Click 125',
      category: 'vehicle',
      brand: 'Honda',
      model: 'Click 125',
      createdAt: DateTime(2024, 5));
  final records = [
    ServiceRecord(
        id: 's',
        assetId: 'a',
        assetName: asset.name,
        task: 'Brake inspection',
        description: 'Pad wear checked · Fluid topped up',
        kind: 'inspection',
        cost: 350,
        performedAt: DateTime(2026, 9, 11),
        performedBy: 'MotoCare',
        receiptPath: 'preview-receipt.jpg')
  ];
  final plans = [
    MaintenancePlan(
        id: 'p',
        assetId: 'a',
        title: 'Change engine oil',
        intervalMonths: 3,
        reminderDays: 7,
        nextDue: DateTime.now().add(const Duration(days: 4)),
        active: true)
  ];
  final screens = <String, Widget>{
    'asset_form': const AddAssetPage(),
    'service_form': const AddServicePage(assetId: 'a'),
    'asset_details': const AssetDetailPage(assetId: 'a'),
    'calendar': const CalendarPage(),
    'service_details': const ServiceRecordPage(assetId: 'a', recordId: 's')
  };
  for (final dark in [false, true]) {
    for (final entry in screens.entries) {
      testWidgets(
          '${entry.key} uses the reference layout in ${dark ? 'dark' : 'light'}',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(384, 832));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: ProviderScope(
                overrides: [
                  forecastRepositoryProvider.overrideWithValue(
                      FakeForecastRepository(const ForecastData(assets: [
                    ForecastAsset(
                        "a", "Honda Click 125", "vehicle", false, null)
                  ]))),
                  assetRepositoryProvider
                      .overrideWithValue(FakeAssetRepository([asset])),
                  assetsProvider.overrideWith((ref) => Stream.value([asset])),
                  plansProvider.overrideWith((ref) => Stream.value(plans)),
                  predictionRepositoryProvider
                      .overrideWithValue(FakePredictionRepository()),
                  serviceHistoryRepositoryProvider
                      .overrideWithValue(FakeServiceHistoryRepository(records)),
                ],
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: dark ? AppTheme.dark() : AppTheme.light(),
                    home: entry.value))));
        await tester.pumpAndSettle();
        if (entry.key == 'service_form') {
          for (final field
              in tester.widgetList<AppField>(find.byType(AppField))) {
            if (field.label == 'What was done?') {
              field.controller!.text = 'Oil and filter replacement';
            }
            if (field.label == 'Service cost (PHP)') {
              field.controller!.text = '450';
            }
          }
          await tester.pumpAndSettle();
        }
        if (['asset_form', 'asset_details', 'service_form']
            .contains(entry.key)) {
          final label = entry.key == 'asset_form'
              ? 'Continue'
              : entry.key == 'service_form'
                  ? 'Save service record'
                  : '+ Record maintenance';
          final button = find.widgetWithText(ElevatedButton, label);
          final text = find.text(label);
          expect(button, findsOneWidget);
          expect(tester.getCenter(text).dx,
              closeTo(tester.getCenter(button).dx, .5));
          expect(tester.getCenter(text).dy,
              closeTo(tester.getCenter(button).dy, .5));
          expect(tester.getRect(button).bottom, lessThanOrEqualTo(832));
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/ui_previews');
          await directory.create(recursive: true);
          await File(
                  '${directory.path}/${entry.key}_${dark ? 'dark' : 'light'}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        if (entry.key == 'asset_details') {
          for (final label in [
            'All service records (1)',
            'Maintenance recommendations'
          ]) {
            await Scrollable.ensureVisible(tester.element(find.text(label)),
                alignment: .2);
            await tester.pumpAndSettle();
            await tester.tap(find.text(label));
            await tester.pump(const Duration(milliseconds: 140));
            expect(tester.takeException(), isNull);
            await tester.pumpAndSettle();
          }
          await Scrollable.ensureVisible(
              tester.element(find.text('Maintenance recommendations')),
              alignment: .15);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'build/ui_previews/asset_details_expanded_${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  for (final dark in [false, true]) {
    for (final entry in screens.entries) {
      testWidgets(
          '${entry.key} supports large text in ${dark ? 'dark' : 'light'}',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ProviderScope(
            overrides: [
              forecastRepositoryProvider.overrideWithValue(
                  FakeForecastRepository(const ForecastData(assets: [
                ForecastAsset("a", "Honda Click 125", "vehicle", false, null)
              ]))),
              assetRepositoryProvider
                  .overrideWithValue(FakeAssetRepository([asset])),
              assetsProvider.overrideWith((ref) => Stream.value([asset])),
              plansProvider.overrideWith((ref) => Stream.value(plans)),
              predictionRepositoryProvider
                  .overrideWithValue(FakePredictionRepository()),
              serviceHistoryRepositoryProvider
                  .overrideWithValue(FakeServiceHistoryRepository(records)),
            ],
            child: MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(2),
                        viewInsets: entry.key.endsWith('form')
                            ? const EdgeInsets.only(bottom: 200)
                            : EdgeInsets.zero),
                    child: child!),
                home: entry.value)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'Service details show a missing record instead of sample information',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          serviceHistoryRepositoryProvider
              .overrideWithValue(FakeServiceHistoryRepository([]))
        ],
        child: MaterialApp(
            theme: AppTheme.light(),
            home: const ServiceRecordPage(assetId: 'a', recordId: 'missing'))));
    await tester.pumpAndSettle();
    expect(find.text('Service record not found.'), findsOneWidget);
    expect(find.text('Brake inspection'), findsNothing);
  });
}
