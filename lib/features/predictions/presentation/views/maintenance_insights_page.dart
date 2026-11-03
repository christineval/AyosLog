import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../assets/domain/entities/asset_category.dart';
import '../../domain/maintenance_insight.dart';
import '../forecast_providers.dart';
import '../viewmodels/maintenance_insight_provider.dart';
import 'maintenance_recommendation_card.dart';
import 'forecast_widgets.dart';

class MaintenanceInsightsPage extends ConsumerWidget {
  const MaintenanceInsightsPage(
      {super.key, required this.assetId, this.taskId, this.legacyTaskId});
  final String assetId;
  final String? taskId, legacyTaskId;
  String primaryRoute(MaintenanceInsight s) {
    final id = Uri.encodeComponent(s.taskId ?? '');
    if (s.action == InsightAction.plan) {
      return '/assets/$assetId/prediction-plan';
    }
    if (s.origin == InsightOrigin.legacy) {
      return s.action == InsightAction.service
          ? '/assets/$assetId/service/new'
          : '/assets/$assetId/usage/new?task=$id';
    }
    return s.action == InsightAction.service
        ? '/assets/$assetId/prediction-service?task=$id'
        : '/assets/$assetId/check-in?task=$id';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assetMaintenanceInsightsProvider(assetId));
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(title: const Text('Maintenance insights'), actions: [
          IconButton(
              tooltip: 'Insight options',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (c) => SafeArea(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(
                            leading: const Icon(Icons.list_alt),
                            title: const Text('All maintenance plans'),
                            onTap: () {
                              Navigator.pop(c);
                              context.push('/assets/$assetId/insights');
                            }),
                        ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Maintenance history'),
                            onTap: () {
                              Navigator.pop(c);
                              context
                                  .push('/assets/$assetId/maintenance-history');
                            }),
                      ])))),
        ]),
        body: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () {
                      ref.invalidate(insightsProvider);
                      ref.invalidate(predictionProvider(assetId));
                    },
                    child: const Text('Could not load asset insights. Retry'))),
            data: (items) {
              if (items.isEmpty) {
                return const ForecastEmpty('Asset unavailable',
                    'Open an active asset to view its maintenance insights.');
              }
              final matches = items.where((s) => legacyTaskId != null
                  ? s.origin == InsightOrigin.legacy && s.taskId == legacyTaskId
                  : taskId != null
                      ? s.origin == InsightOrigin.forecast && s.taskId == taskId
                      : true);
              if (matches.isEmpty) {
                return const ForecastEmpty('Plan unavailable',
                    'Return to this asset’s plan list to choose an existing task.');
              }
              final s = matches.first;
              final data = ref.watch(insightsProvider).valueOrNull;
              final asset =
                  data?.source.assets.where((a) => a.id == assetId).firstOrNull;
              final vehicleType = asset?.setup['vehicle_type'];
              final category = s.category == 'vehicle' && vehicleType != null
                  ? switch (vehicleType) {
                      'motorcycle' => 'Motorcycle',
                      'car' => 'Car',
                      _ => 'Vehicle'
                    }
                  : AssetCategory.labelFor(s.category);
              final p = s.prediction;
              return SafeArea(
                  top: false,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    if (items.length > 1) ...[
                      AppDropdown<String>(
                          label: 'Maintenance task',
                          value: maintenanceInsightLocation(s),
                          entries: [
                            for (final i in items)
                              DropdownMenuEntry(
                                  value: maintenanceInsightLocation(i),
                                  label: i.title)
                          ],
                          onSelected: (location) {
                            if (location != null) {
                              context.pushReplacement(location);
                            }
                          }),
                      const SizedBox(height: 14)
                    ],
                    AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Icon(maintenanceAssetIcon(s.category),
                                    color: theme.colorScheme.primary)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(s.assetName,
                                      style: theme.textTheme.titleLarge),
                                  const SizedBox(height: 4),
                                  Text(
                                      '$category · ${s.isCondition ? 'Condition review' : s.isScheduled ? 'Scheduled maintenance' : 'Service forecast'}',
                                      style: theme.textTheme.bodySmall)
                                ]))
                          ]),
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                              s.isCondition
                                  ? 'Recorded condition'
                                  : s.isScheduled
                                      ? 'Scheduled service'
                                      : 'Estimated time / usage to next service',
                              style: theme.textTheme.bodySmall),
                          const SizedBox(height: 10),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Text(s.headline,
                                        style: theme.textTheme.headlineLarge)),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 110),
                                    child: InsightBadge(s, detailed: true))
                              ]),
                          const SizedBox(height: 12),
                          Text(s.explanation, style: theme.textTheme.bodySmall),
                          if (s.progress != null) ...[
                            const SizedBox(height: 16),
                            LinearProgressIndicator(value: s.progress),
                            const SizedBox(height: 8),
                            Text(s.progressLabel ?? '',
                                style: theme.textTheme.bodySmall)
                          ],
                        ])),
                    const SizedBox(height: 14),
                    AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Why this recommendation?',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 14),
                          if (s.evidence.isEmpty) Text(s.explanation),
                          for (final line in s.evidence)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 18,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(line))
                                    ])),
                          for (final line in s.alerts)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 18,
                                          color: insightToneColor(
                                              context, InsightTone.review)),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(line))
                                    ])),
                        ])),
                    const SizedBox(height: 14),
                    AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Text('Prediction reliability',
                                    style: theme.textTheme.titleLarge),
                                Chip(
                                    label: Text(
                                        s.origin == InsightOrigin.unconfigured
                                            ? 'Needs data'
                                            : s.isScheduled
                                                ? 'Scheduled'
                                                : s.isCondition
                                                    ? 'Recorded trend'
                                                    : 'Estimated'))
                              ]),
                          const SizedBox(height: 12),
                          Text(s.reliability, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 16),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 17, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                const Expanded(
                                    child: Text(
                                        'This is planning guidance, not a diagnosis.'))
                              ]),
                        ])),
                    const SizedBox(height: 14),
                    AppButton(
                        label: '+ ${s.actionLabel}',
                        onPressed: () => context.push(primaryRoute(s))),
                    const SizedBox(height: 12),
                    AppButton(
                        label: 'View maintenance history',
                        outlined: true,
                        onPressed: () => context
                            .push('/assets/$assetId/maintenance-history')),
                    if (p != null) ...[
                      const SizedBox(height: 14),
                      ExpansionTile(
                          title: const Text('Readings and plan details'),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          children: [
                            ReadingChart(prediction: p),
                            if (data?.costs[s.taskId] case final cost?)
                              AppCard(
                                  child: Text(
                                      'Service costs for this task: PHP ${cost.total.toStringAsFixed(2)} in the last 90 days; ${cost.samples} comparable services.')),
                            for (final r in p.rationale)
                              ListTile(title: Text(r)),
                            ListTile(
                                title: const Text('Calculation evidence'),
                                subtitle: Text(
                                    '${p.inputs.length} inputs · ${p.ratePairs} rate pairs · ${p.reliability.name} · ${forecastDate(p.latestAt)}')),
                            Text(
                                'Policy ${p.task.version} · ${p.inputHash} · rules_v1',
                                style: theme.textTheme.bodySmall),
                          ])
                    ],
                    const SizedBox(height: 14),
                    TextButton(
                        onPressed: () => context.push(s.origin ==
                                InsightOrigin.legacy
                            ? '/assets/$assetId/tasks/new?rule=${Uri.encodeComponent(s.taskId ?? '')}'
                            : '/assets/$assetId/prediction-plan${s.taskId == null ? '' : '?task=${Uri.encodeComponent(s.taskId!)}'}'),
                        child: const Text('Edit maintenance plan')),
                  ]));
            }));
  }
}
