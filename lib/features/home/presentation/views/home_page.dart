import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/upcoming_maintenance_card.dart';
import '../../../predictions/presentation/views/maintenance_recommendation_card.dart';
import '../../../predictions/presentation/forecast_providers.dart';
import '../../../predictions/domain/forecast_models.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);
    final plans = ref.watch(plansProvider);
    final forecast = ref.watch(insightsProvider);
    final dated = (forecast.valueOrNull?.insights ?? const <AssetInsight>[])
        .where((i) => i.prediction?.dueAt != null)
        .toList()
      ..sort((a, b) => a.prediction!.dueAt!.compareTo(b.prediction!.dueAt!));
    final accent = Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        appBar: AppBar(title: const Text('AyosLog'), actions: [
          IconButton(
              tooltip: 'Maintenance insights',
              onPressed: () => context.push('/insights'),
              icon: const Icon(Icons.insights_outlined)),
          IconButton(
              tooltip: 'Settings',
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_outlined))
        ]),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(22), children: [
            Text('Keep your things running.',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text('Your maintenance at a glance',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            Container(
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: dark ? AppColors.darkSubtle : AppColors.lightSubtle),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your maintenance overview',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(assets.valueOrNull?.length.toString() ?? '—',
                                  style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: accent)),
                              const Text('Active assets')
                            ])),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  plans.valueOrNull == null
                                      ? '—'
                                      : '${plans.valueOrNull!.where((p) => p.active).length + (forecast.valueOrNull?.source.tasks.length ?? 0)}',
                                  style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: accent)),
                              const Text('Maintenance plans')
                            ]))
                      ])
                    ])),
            const SizedBox(height: 20),
            Text('Upcoming maintenance',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            plans.when(
                data: (list) {
                  final ordered = [...list.where((p) => p.active)]
                    ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
                  if (ordered.isEmpty) {
                    if (dated.isNotEmpty || forecast.isLoading) {
                      return const SizedBox.shrink();
                    }
                    return const AppCard(
                        child: Text(
                            'No reminders yet. Open an asset to add a maintenance plan.'));
                  }
                  return Column(
                      children: ordered.take(10).map((p) {
                    final days = DateUtils.dateOnly(p.nextDue)
                        .difference(DateUtils.dateOnly(DateTime.now()))
                        .inDays;
                    final status = days < 0
                        ? 'overdue'
                        : days <= p.reminderDays
                            ? 'soon'
                            : 'healthy';
                    return UpcomingMaintenanceCard(
                      assetName: assets.valueOrNull
                              ?.where((a) => a.id == p.assetId)
                              .firstOrNull
                              ?.name ??
                          'Asset',
                      serviceType: p.title,
                      date: p.nextDue,
                      status: status,
                      label: days < 0
                          ? 'Overdue'
                          : days <= p.reminderDays
                              ? 'Due soon'
                              : 'Scheduled',
                      onTap: () => context.push('/assets/${p.assetId}'),
                    );
                  }).toList());
                },
                error: (e, _) => Text('Could not load plans: $e'),
                loading: () =>
                    const Center(child: CircularProgressIndicator())),
            forecast.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => TextButton(
                    onPressed: () => ref.invalidate(insightsProvider),
                    child: const Text(
                        'Could not load predicted maintenance. Retry')),
                data: (_) => Column(children: [
                      for (final item in dated.take(10))
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: UpcomingMaintenanceCard(
                                assetName: item.assetName,
                                serviceType: item.prediction!.task.name,
                                date: item.prediction!.dueAt!,
                                label: item.state.label,
                                status: item.state == ForecastState.overdue
                                    ? 'overdue'
                                    : item.state == ForecastState.dueSoon
                                        ? 'soon'
                                        : 'healthy',
                                onTap: () => context.push(
                                    '/assets/${item.assetId}/insights/${item.prediction!.task.id}')))
                    ])),
            const SizedBox(height: 20),
            Text('Maintenance recommendations',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const AssetMaintenanceRecommendations(),
            const SizedBox(height: 20),
            AppButton(
                label: '+ Add new asset',
                onPressed: () => context.push('/assets/new')),
            const SizedBox(height: 12),
            AppButton(
                label: 'View maintenance insights',
                outlined: true,
                onPressed: () => context.push('/insights')),
            const SizedBox(height: 20),
          ]),
        ));
  }
}
