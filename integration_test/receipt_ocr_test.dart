import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';

/// Exercises native ML Kit with a known, clean receipt fixture.
/// This is a smoke test, not an accuracy benchmark for photographed receipts.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Native OCR reads known receipt lines and amount',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('OCR verification'))));
    const lines = ['AYOSLOG SERVICE', 'Oil change', 'TOTAL PHP 1250.00'];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1000, 400), Paint()..color = Colors.white);
    for (var i = 0; i < lines.length; i++) {
      final paragraph = (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 40))
            ..pushStyle(ui.TextStyle(color: Colors.black))
            ..addText(lines[i]))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 900));
      canvas.drawParagraph(paragraph, Offset(40, 40 + i * 100));
      paragraph.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1000, 400);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory.systemTemp.createTemp('ayoslog_ocr_');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final file = await File('${directory.path}/receipt.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      final result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      final normalized =
          result.text.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
      for (final line in lines) {
        expect(normalized, contains(line.toUpperCase()));
      }
    } finally {
      await recognizer.close();
      image.dispose();
      picture.dispose();
      await directory.delete(recursive: true);
    }
  });
}
