import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/maintenance_insight.dart';
import '../forecast_providers.dart';
import '../viewmodels/maintenance_insight_provider.dart';

IconData maintenanceAssetIcon(String category) => switch (category) {
      'vehicle' => Icons.two_wheeler,
      'air_conditioner' => Icons.air,
      'refrigerator' => Icons.kitchen_outlined,
      'laptop' => Icons.laptop_mac_outlined,
      'water_filter' => Icons.water_drop_outlined,
      'washing_machine' => Icons.local_laundry_service_outlined,
      _ => Icons.build_outlined
    };
Color insightToneColor(BuildContext context, InsightTone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tone) {
    InsightTone.overdue => Theme.of(context).colorScheme.error,
    InsightTone.review => dark ? AppColors.warningDark : AppColors.warning,
    InsightTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    InsightTone.normal => Theme.of(context).colorScheme.primary
  };
}

String maintenanceInsightLocation(MaintenanceInsight s) =>
    '/assets/${s.assetId}/maintenance-insights${s.taskId == null ? '' : '?${s.origin == InsightOrigin.legacy ? 'legacy' : 'task'}=${Uri.encodeComponent(s.taskId!)}'}';

class InsightBadge extends StatelessWidget {
  const InsightBadge(this.insight, {super.key, this.detailed = false});
  final MaintenanceInsight insight;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final color = insightToneColor(context, insight.tone);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(99)),
        child: Text(
            detailed && insight.status == 'Soon' ? 'Due soon' : insight.status,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700)));
  }
}

class MaintenanceRecommendationCard extends StatelessWidget {
  const MaintenanceRecommendationCard(
      {super.key, required this.insight, this.onTap});
  final MaintenanceInsight insight;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context),
        s = insight,
        color = insightToneColor(context, insight.tone);
    return AppCard(
        onTap: onTap ?? () => context.push(maintenanceInsightLocation(s)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(maintenanceAssetIcon(s.category), color: color)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(s.assetName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(s.subtitle, style: theme.textTheme.bodySmall)
                ])),
            const SizedBox(width: 8),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: InsightBadge(s)),
          ]),
          if (s.progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                    value: s.progress,
                    minHeight: 7,
                    semanticsLabel:
                        'Recorded usage relative to this task’s configured interval')),
            const SizedBox(height: 10),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (s.progressLabel != null)
                    Text(s.progressLabel!, style: theme.textTheme.bodySmall),
                  if (s.remainingLabel != null)
                    Text(s.remainingLabel!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                ])
          ],
          if (s.window != null) ...[
            const SizedBox(height: 16),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 17, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(s.windowTitle ?? 'Maintenance review',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary)))
                      ]),
                      const SizedBox(height: 10),
                      Text(s.window!),
                    ]))
          ] else ...[
            const SizedBox(height: 12),
            Text(s.explanation, style: theme.textTheme.bodySmall)
          ],
        ]));
  }
}

class AssetMaintenanceRecommendations extends ConsumerWidget {
  const AssetMaintenanceRecommendations({super.key, this.assetId});
  final String? assetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(insightsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(insightsProvider),
              child: const Text('Could not load recommendations. Retry')),
          data: (data) {
            final assets = data.source.assets
                .where(
                    (a) => !a.archived && (assetId == null || a.id == assetId))
                .toList();
            if (assets.isEmpty) {
              return const AppCard(
                  child: Text(
                      'Add an asset to see its maintenance recommendations.'));
            }
            return Column(children: [
              for (final a in assets)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AssetRecommendation(assetId: a.id))
            ]);
          });
}

class _AssetRecommendation extends ConsumerWidget {
  const _AssetRecommendation({required this.assetId});
  final String assetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(assetMaintenanceInsightsProvider(assetId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => TextButton(
              onPressed: () {
                ref.invalidate(insightsProvider);
                ref.invalidate(predictionProvider(assetId));
              },
              child: const Text('Could not load asset recommendation. Retry')),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : MaintenanceRecommendationCard(insight: items.first));
}
