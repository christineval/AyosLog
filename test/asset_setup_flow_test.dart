import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ayoslog/core/database/app_database.dart';
import 'package:ayoslog/core/providers.dart';
import 'package:ayoslog/core/theme/app_theme.dart';
import 'package:ayoslog/features/assets/presentation/views/add_asset_page.dart';
import 'package:ayoslog/features/maintenance/data/maintenance_repository.dart';
import 'package:ayoslog/features/maintenance/domain/maintenance_schedule.dart';
import 'package:ayoslog/features/maintenance/presentation/views/setup_maintenance_plan_page.dart';
import 'package:ayoslog/features/maintenance/presentation/viewmodels/setup_schedule_viewmodel.dart';
import 'package:ayoslog/shared/widgets/app_dropdown.dart';
import 'package:ayoslog/shared/widgets/app_field.dart';

class _PendingScheduleRepository implements MaintenanceScheduleRepository {
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<void> saveSchedule(MaintenanceScheduleDraft draft) {
    writes++;
    return gate.future;
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'Continue opens step 2 and Skip retains one asset in ${dark ? 'dark' : 'light'}',
        (tester) async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final router = GoRouter(initialLocation: '/assets/new', routes: [
        GoRoute(path: '/assets/new', builder: (_, s) => const AddAssetPage()),
        GoRoute(
            path: '/assets/:id/setup-plan',
            builder: (_, s) =>
                SetupMaintenancePlanPage(assetId: s.pathParameters['id']!)),
        GoRoute(
            path: '/assets/:id',
            builder: (_, s) => const Scaffold(body: Text('Asset saved'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router)));
      await tester.pumpAndSettle();
      final name = find.descendant(
          of: find.byWidgetPredicate(
              (w) => w is AppField && w.label == 'Asset name'),
          matching: find.byType(TextField));
      await tester.enterText(name, 'My motorcycle');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(find.text('Set maintenance plan'), findsOneWidget);
      expect(find.text('Save asset & schedule'), findsOneWidget);
      expect((await db.select(db.assets).get()).length, 1);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Asset saved'), findsOneWidget);
      expect(await db.select(db.maintenancePlans).get(), isEmpty);
      expect((await db.select(db.assets).get()).single.name, 'My motorcycle');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
        'step 2 validates the date and saves repeat/reminder data in ${dark ? 'dark' : 'light'}',
        (tester) async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.assets).insert(AssetsCompanion.insert(
          id: 'a',
          name: 'Bike',
          category: 'vehicle',
          createdAt: DateTime(2025)));
      final router = GoRouter(initialLocation: '/assets/a/setup-plan', routes: [
        GoRoute(
            path: '/assets/:id/setup-plan',
            builder: (_, s) => const SetupMaintenancePlanPage(assetId: 'a')),
        GoRoute(
            path: '/assets/:id',
            builder: (_, s) => const Scaffold(body: Text('Asset saved'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save asset & schedule'));
      await tester.pump();
      expect(find.text('Select the first due date.'), findsOneWidget);
      expect(await db.select(db.maintenancePlans).get(), isEmpty);
      await tester.enterText(
          find.byType(TextFormField).first, 'Change engine oil');
      tester
          .widgetList<AppDropdown<int>>(find.byType(AppDropdown<int>))
          .firstWhere((w) => w.label == 'Repeat schedule')
          .onSelected(6);
      tester
          .widgetList<AppDropdown<int>>(find.byType(AppDropdown<int>))
          .firstWhere((w) => w.label == 'Reminder')
          .onSelected(14);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('28').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save asset & schedule'));
      await tester.pumpAndSettle();
      final plan = (await db.select(db.maintenancePlans).get()).single;
      expect(plan.assetId, 'a');
      expect(plan.title, 'Change engine oil');
      expect(plan.intervalMonths, 6);
      expect(plan.reminderDays, 14);
      expect(plan.nextDue.day, 28);
      expect((await db.select(db.assets).get()).length, 1);
      expect(find.text('Asset saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test(
      'schedule validation, duplicate-submit guard and idempotent local persistence',
      () async {
    final pending = _PendingScheduleRepository();
    final vm = SetupScheduleViewModel(SaveMaintenanceSchedule(pending));
    addTearDown(vm.dispose);
    final draft = MaintenanceScheduleDraft(
        id: 'p',
        assetId: 'a',
        title: 'Oil',
        intervalMonths: 3,
        firstDue: DateTime(2026, 11, 28),
        reminderDays: 7);
    final first = vm.submit(draft);
    expect(vm.state.isLoading, true);
    expect(await vm.submit(draft), false);
    expect(pending.writes, 1);
    pending.gate.complete();
    expect(await first, true);
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.assets).insert(AssetsCompanion.insert(
        id: 'a', name: 'Bike', category: 'vehicle', createdAt: DateTime(2025)));
    final save = SaveMaintenanceSchedule(MaintenanceRepository(db));
    await save(draft);
    await save(draft);
    expect((await db.select(db.maintenancePlans).get()).length, 1);
    expect(
        () => save(MaintenanceScheduleDraft(
            id: 'bad',
            assetId: 'a',
            title: '',
            intervalMonths: 0,
            firstDue: DateTime(2025),
            reminderDays: -1)),
        throwsArgumentError);
  });
}
