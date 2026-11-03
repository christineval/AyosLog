import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/core/theme/app_theme.dart';

void main() {
  testWidgets('AyosLog light theme renders basic content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: Center(child: Text('AyosLog'))),
    ));
    expect(find.text('AyosLog'), findsOneWidget);
  });

  testWidgets('AyosLog dark theme renders basic content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(body: Center(child: Text('AyosLog'))),
    ));
    expect(find.text('AyosLog'), findsOneWidget);
  });
}
