import 'dart:async';

import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/features/maintenance/presentation/views/add_service_page.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_prediction_repository.dart';
import 'helpers/fake_asset_repository.dart';
import 'helpers/fake_forecast_repository.dart';
import 'package:ayoslog/features/predictions/presentation/forecast_providers.dart';
import 'package:ayoslog/features/predictions/domain/forecast_repository.dart';
import 'package:ayoslog/features/assets/domain/entities/asset.dart';

void main() {
  const picker = MethodChannel('plugins.flutter.io/image_picker');
  const ocr = MethodChannel('google_mlkit_text_recognizer');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(picker, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ocr, null);
  });

  Future<void> showForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
          overrides: [
            plansProvider.overrideWith((ref) => Stream.value([])),
            forecastRepositoryProvider.overrideWithValue(
                FakeForecastRepository(const ForecastData())),
            assetRepositoryProvider.overrideWithValue(FakeAssetRepository([
              Asset(
                  id: 'asset',
                  name: 'Custom asset',
                  category: 'custom',
                  createdAt: DateTime(2025))
            ])),
            predictionRepositoryProvider
                .overrideWithValue(FakePredictionRepository())
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AddServicePage(assetId: 'asset'),
          )),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startScan(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.text('Add receipt photo +').evaluate().isNotEmpty
        ? find.text('Add receipt photo +')
        : find.text('Choose another receipt photo');
    await Scrollable.ensureVisible(
        tester.element(button),
        alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(button.hitTestable());
  }

  Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate(
            (widget) => widget is AppField && widget.label == label),
        matching: find.byType(TextField),
      );

  for (final dark in [false, true]) {
    testWidgets(
        'Multiline label starts at the top in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: const Scaffold(
            body: AppField(label: 'What was done?', maxLines: 5)),
      ));
      final label = tester.getRect(find.text('What was done?'));
      final input = tester.getRect(find.byType(TextField));
      expect(label.top - input.top, lessThan(24));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Full OCR result stays editable, cost unchanged, image not resized',
      (tester) async {
    final text = List.filled(40, 'Oil change PHP 1250.00').join('\n');
    bool closed = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(picker,
        (call) async {
      expect(call.method, 'pickImage');
      expect(call.arguments['maxWidth'], isNull);
      expect(call.arguments['maxHeight'], isNull);
      return '/receipt.jpg';
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ocr, (call) async {
      if (call.method == 'vision#closeTextRecognizer') {
        closed = true;
        return null;
      }
      expect(call.arguments['imageData']['path'], '/receipt.jpg');
      return {'text': text, 'blocks': []};
    });
    await showForm(tester);
    final originalCost =
        tester.widget<TextField>(field('Service cost (PHP)')).controller!.text;
    await startScan(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('What was done?')).controller!.text,
        text);
    expect(
        tester.widget<TextField>(field('Service cost (PHP)')).controller!.text,
        originalCost);
    expect(closed, isTrue);
    await tester.enterText(field('What was done?'), 'Corrected notes');
    expect(tester.widget<TextField>(field('What was done?')).controller!.text,
        'Corrected notes');
  });

  for (final outcome in ['empty', 'error', 'cancel']) {
    testWidgets('$outcome scan preserves existing notes and allows retry',
        (tester) async {
      bool closed = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
          picker, (call) async => outcome == 'cancel' ? null : '/receipt.jpg');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(ocr,
          (call) async {
        if (call.method == 'vision#closeTextRecognizer') {
          closed = true;
          return null;
        }
        if (outcome == 'error') throw PlatformException(code: 'scan_error');
        return {'text': '  ', 'blocks': []};
      });
      await showForm(tester);
      await tester.enterText(field('What was done?'), 'Existing notes');
      await startScan(tester);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('What was done?')).controller!.text,
          'Existing notes');
      expect(closed, outcome != 'cancel');
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull);
      if (outcome == 'empty') {
        expect(find.textContaining('No text found.'), findsOneWidget);
      }
      if (outcome == 'error') {
        expect(find.textContaining('Scan failed:'), findsOneWidget);
      }
    });
  }

  testWidgets('A pending scan blocks repeat scanning and saving',
      (tester) async {
    final result = Completer<Map<String, Object>>();
    int scans = 0;
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(picker, (call) async => '/receipt.jpg');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(ocr, (call) async {
      if (call.method == 'vision#closeTextRecognizer') return null;
      scans++;
      return result.future;
    });
    await showForm(tester);
    await startScan(tester);
    await tester.pumpAndSettle();
    expect(scans, 1);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    await tester.scrollUntilVisible(find.text('Save service record'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    result.complete({'text': 'Service completed', 'blocks': []});
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
  });
}
