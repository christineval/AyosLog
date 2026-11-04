import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/maintenance/data/local_receipt_store.dart';
import 'package:ayoslog/shared/widgets/app_attachment_preview.dart';

void main() {
  test('retained receipt survives original removal and is reused', () async {
    final root = await Directory.systemTemp.createTemp('ayoslog-receipt-');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/picked.png');
    await source.writeAsBytes([1, 2, 3]);
    final store = LocalReceiptStore(directory: () async => root);
    final saved = await store.retain(source.path);
    expect(saved, isNot(source.path));
    await source.delete();
    expect(await File(saved!).readAsBytes(), [1, 2, 3]);
    expect(await store.retain(saved), saved);
    expect(await store.retain(null), isNull);
    expect(await store.retain('${root.path}/missing.jpg'),
        '${root.path}/missing.jpg');
  });
  for (final dark in [false, true]) {
    testWidgets('photo opens zoom viewer in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      late Directory root;
      late String path;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('ayoslog-preview-');
        path = '${root.path}/photo.png';
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.white, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(1, 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      addTearDown(() async {
        for (var attempt = 0;; attempt++) {
          try {
            await root.delete(recursive: true);
            break;
          } on FileSystemException {
            if (attempt == 4) rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
      });
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const Scaffold()));
      // File reads and image decoding run outside the fake widget-test clock.
      // Await both image variants instead of assuming a fixed delay is enough.
      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        final image = FileImage(File(path));
        await precacheImage(
            ResizeImage.resizeIfNeeded(1000, null, image), context,
            onError: (error, stack) =>
                Error.throwWithStackTrace(error, stack!));
        await precacheImage(image, context,
            onError: (error, stack) =>
                Error.throwWithStackTrace(error, stack!));
      });
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(body: AppAttachmentPreview(path: path))));
      await tester.tap(find.byType(AppAttachmentPreview));
      await tester.pumpAndSettle();
      expect(find.byType(AppAttachmentViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
          tester.widget<RawImage>(find.byType(RawImage).last).image, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
        'missing attachment has a readable recovery state with large text $dark',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                  body: SizedBox(
                      width: 280,
                      child: AppAttachmentPreview(
                          path: '/missing-receipt.png'))))));
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Photo unavailable. The maintenance record is still saved.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
