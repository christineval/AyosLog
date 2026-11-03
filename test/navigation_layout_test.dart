import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/router/app_router.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/domain/entities/asset.dart';
import 'package:ayoslog/features/assets/presentation/views/assets_page.dart';
import 'package:ayoslog/features/calendar/presentation/views/calendar_page.dart';
import 'package:ayoslog/shared/widgets/app_dropdown.dart';
import 'package:ayoslog/shared/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.dark() : AppTheme.light();
    final mode = dark ? 'dark' : 'light';

    testWidgets('Dropdown fits the field and opens below it in $mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selected = 'appliance';
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              AppDropdown<String>(
                label: 'Category',
                value: 'appliance',
                entries: const [
                  DropdownMenuEntry(value: 'appliance', label: 'Appliance'),
                  DropdownMenuEntry(value: 'electronics', label: 'Electronics'),
                  DropdownMenuEntry(value: 'other', label: 'Other'),
                ],
                onSelected: (value) => selected = value,
              ),
            ]),
          ),
        ),
      ));
      final field = tester.getRect(find.byType(TextField));
      expect(field.width, 276);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final options = find.byType(MenuItemButton).hitTestable();
      expect(options, findsNWidgets(3));
      final first = tester.getRect(options.first);
      expect(first.top, greaterThanOrEqualTo(field.bottom));
      expect(first.left, greaterThanOrEqualTo(field.left));
      expect(first.right, lessThanOrEqualTo(field.right));
      await tester.tap(find.text('Electronics').hitTestable());
      await tester.pumpAndSettle();
      expect(selected, 'electronics');
      expect(find.widgetWithText(TextField, 'Electronics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final calendar in [false, true]) {
      testWidgets(
          '${calendar ? 'Calendar' : 'Assets'} empty state is centered in $mode',
          (tester) async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            assetsProvider.overrideWith((ref) => Stream.value(<Asset>[])),
            plansProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: theme,
            home: calendar ? const CalendarPage() : const AssetsPage(),
          ),
        ));
        await tester.pumpAndSettle();
        final state = find.byType(AppEmptyState);
        expect(state, findsOneWidget);
        final icon = find.descendant(of: state, matching: find.byType(Icon));
        final title =
            find.text(calendar ? 'Nothing scheduled yet' : 'No assets yet');
        final area = tester.getRect(state);
        final group = tester.getRect(find.descendant(
          of: state,
          matching: find.byType(Column),
        ));
        expect(group.center.dx, closeTo(area.center.dx, 1));
        expect(group.center.dy, closeTo(area.center.dy, 1));
        expect(
            tester.getRect(icon).bottom, lessThan(tester.getRect(title).top));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('An empty asset search shows filter guidance', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        assetsProvider.overrideWith((ref) => Stream.value([
              Asset(
                  id: '1',
                  name: 'Refrigerator',
                  category: 'appliance',
                  createdAt: DateTime(2026)),
            ])),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const AssetsPage()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'car');
    await tester.pump();
    expect(find.text('No matching assets'), findsOneWidget);
    expect(find.text('Try another search or category.'), findsOneWidget);
  });

  testWidgets('Navigation pushes immediately and back returns to assets',
      (tester) async {
    appRouter.go('/assets');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        assetsProvider.overrideWith((ref) => Stream.value(<Asset>[])),
        plansProvider.overrideWith((ref) => Stream.value([])),
      ],
      child:
          MaterialApp.router(theme: AppTheme.light(), routerConfig: appRouter),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add new asset'));
    await tester.pumpAndSettle();
    expect(appRouter.canPop(), isTrue);
    expect(find.text('Add an asset'), findsOneWidget);
    for (final navigator
        in tester.widgetList<Navigator>(find.byType(Navigator))) {
      for (final page in navigator.pages) {
        expect(page, isA<NoTransitionPage>());
        final routePage = page as NoTransitionPage;
        expect(routePage.transitionDuration, Duration.zero);
        expect(routePage.reverseTransitionDuration, Duration.zero);
      }
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My assets'), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
