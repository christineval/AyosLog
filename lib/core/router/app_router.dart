import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/views/home_page.dart';
import '../../features/assets/presentation/views/assets_page.dart';
import '../../features/assets/presentation/views/add_asset_page.dart';
import '../../features/assets/presentation/views/asset_category_page.dart';
import '../../features/assets/presentation/views/asset_detail_page.dart';
import '../../features/maintenance/presentation/views/setup_maintenance_plan_page.dart';
import '../../features/maintenance/presentation/views/maintenance_history_page.dart';
import '../../features/predictions/presentation/views/maintenance_insights_page.dart';
import '../../features/maintenance/presentation/views/add_service_page.dart';
import '../../features/maintenance/presentation/views/service_record_page.dart';
import '../../features/calendar/presentation/views/calendar_page.dart';
import '../../features/settings/presentation/views/settings_page.dart';
import '../../features/predictions/presentation/views/add_mileage_page.dart';
import '../../features/predictions/presentation/views/task_rule_page.dart';
import '../../features/predictions/presentation/views/insights_page.dart';
import '../../features/predictions/presentation/views/forecast_forms.dart';
import '../../features/predictions/presentation/views/forecast_history_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final idx = path.startsWith('/assets')
        ? 1
        : path.startsWith('/calendar')
            ? 2
            : path.startsWith('/settings')
                ? 3
                : 0;
    return Scaffold(
        body: child,
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(29),
                    child: NavigationBar(
                        height: 70,
                        selectedIndex: idx,
                        onDestinationSelected: (i) {
                          const paths = [
                            '/home',
                            '/assets',
                            '/calendar',
                            '/settings'
                          ];
                          context.go(paths[i]);
                        },
                        destinations: const [
                          NavigationDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home),
                              label: 'Home'),
                          NavigationDestination(
                              icon: Icon(Icons.inventory_2_outlined),
                              label: 'Assets'),
                          NavigationDestination(
                              icon: Icon(Icons.calendar_month_outlined),
                              label: 'Calendar'),
                          NavigationDestination(
                              icon: Icon(Icons.settings_outlined),
                              label: 'Settings')
                        ])))));
  }
}

final appRouter = GoRouter(initialLocation: '/home', routes: [
  ShellRoute(
      pageBuilder: (context, state, child) =>
          NoTransitionPage(key: state.pageKey, child: AppShell(child: child)),
      routes: [
        GoRoute(
            path: '/assets/:id/maintenance-insights',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: MaintenanceInsightsPage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.uri.queryParameters['task'],
                    legacyTaskId: s.uri.queryParameters['legacy']))),
        GoRoute(
            path: '/assets/:id/maintenance-history',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child:
                    MaintenanceHistoryPage(assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/assets/:id/setup-plan',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: SetupMaintenancePlanPage(
                    assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/assets/:id/category',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: AssetCategoryPage(assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/insights',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const InsightsPage())),
        GoRoute(
            path: '/insights/missing-data',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey, child: const InsightsPage(missingOnly: true))),
        GoRoute(
            path: '/assets/:id/insights',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: InsightsPage(assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/assets/:id/insights/:taskId',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: AssetPredictionPage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.pathParameters['taskId']!))),
        GoRoute(
            path: '/assets/:id/prediction-plan',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ForecastPlanPage(
                    assetId: s.pathParameters['id']!,
                    setupFlow: s.uri.queryParameters['setup'] == '1',
                    taskId: s.uri.queryParameters['task']))),
        GoRoute(
            path: '/assets/:id/check-in',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ForecastCheckInPage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.uri.queryParameters['task'],
                    entryId: s.uri.queryParameters['entry']))),
        GoRoute(
            path: '/assets/:id/condition-check',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ForecastCheckInPage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.uri.queryParameters['task'],
                    conditionsOnly: true))),
        GoRoute(
            path: '/assets/:id/usage-history',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ForecastHistoryPage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.uri.queryParameters['task']))),
        GoRoute(
            path: '/assets/:id/prediction-service',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ForecastServicePage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.uri.queryParameters['task'] ?? '',
                    serviceId: s.uri.queryParameters['service']))),
        GoRoute(
            path: '/home',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const HomePage())),
        GoRoute(
            path: '/assets',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const AssetsPage())),
        GoRoute(
            path: '/calendar',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const CalendarPage())),
        GoRoute(
            path: '/settings',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const SettingsPage())),
        GoRoute(
            path: '/assets/new',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const AddAssetPage())),
        GoRoute(
            path: '/assets/:id',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: AssetDetailPage(assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/assets/:id/schedules/new',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ForecastPlanPage(assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/assets/:id/schedules/monthly',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: SetupMaintenancePlanPage(
                    assetId: s.pathParameters['id']!, setupFlow: false))),
        GoRoute(
            path: '/assets/:id/tasks/new',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: TaskRulePage(
                    assetId: s.pathParameters['id']!,
                    ruleId: s.uri.queryParameters['rule'],
                    taskName: s.uri.queryParameters['name'] ?? '',
                    partName: s.uri.queryParameters['part'] ?? ''))),
        GoRoute(
            path: '/assets/:id/usage/new',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: AddMileagePage(
                    assetId: s.pathParameters['id']!,
                    taskId: s.uri.queryParameters['task']))),
        GoRoute(
            path: '/assets/:id/service/new',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: AddServicePage(assetId: s.pathParameters['id']!))),
        GoRoute(
            path: '/assets/:id/service/:recordId',
            pageBuilder: (_, s) => NoTransitionPage(
                key: s.pageKey,
                child: ServiceRecordPage(
                    assetId: s.pathParameters['id']!,
                    recordId: s.pathParameters['recordId']!))),
      ]),
]);
