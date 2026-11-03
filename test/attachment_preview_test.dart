import 'dart:convert';
import 'dart:io';
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
        await File(path).writeAsBytes(base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8/x8AAwMCAO+a14kAAAAASUVORK5CYII='));
      });
      addTearDown(() async {
        for (var attempt = 0; ; attempt++) {
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
          home: Scaffold(body: AppAttachmentPreview(path: path))));
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.tap(find.byType(AppAttachmentPreview));
      await tester.pumpAndSettle();
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byType(AppAttachmentViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.widget<RawImage>(find.byType(RawImage).last).image, isNotNull);
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
