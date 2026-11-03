import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../../assets/domain/entities/asset_category.dart';
import '../../domain/maintenance_insight.dart';
import '../forecast_providers.dart';
import '../viewmodels/maintenance_insight_provider.dart';
import 'forecast_widgets.dart';
import 'maintenance_recommendation_card.dart';
import 'maintenance_insights_page.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key, this.assetId, this.missingOnly = false});
  final String? assetId;
  final bool missingOnly;
  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  String? category, status;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const AppPageBar(title: 'Maintenance insights'),
      body: ref.watch(insightsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(insightsProvider),
                  child: const Text('Could not load local insights. Retry'))),
          data: (data) {
            final assets = data.source.assets
                .where((a) =>
                    !a.archived &&
                    (widget.assetId == null || a.id == widget.assetId))
                .toList();
            if (assets.isEmpty) {
              return const ForecastEmpty(
                  'No assets yet', 'Add an asset to start a maintenance plan.');
            }
            final cards = <MaintenanceInsight>[];
            final pending = <String>[], failed = <String>[];
            for (final a in assets) {
              final state = ref.watch(assetMaintenanceInsightsProvider(a.id));
              if (state.isLoading) pending.add(a.name);
              if (state.hasError) failed.add(a.id);
              if (state.valueOrNull?.isNotEmpty ?? false) {
                cards.add(state.requireValue.first);
              }
            }
            final filtered = cards
                .where((i) =>
                    (category == null || i.category == category) &&
                    (status == null || i.status == status) &&
                    (!widget.missingOnly ||
                        i.origin == InsightOrigin.unconfigured ||
                        i.tone == InsightTone.neutral))
                .toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(
                    label: Text(
                        'Overdue: ${cards.where((i) => i.tone == InsightTone.overdue).length}')),
                Chip(
                    label: Text(
                        'Review / soon: ${cards.where((i) => i.tone == InsightTone.review).length}')),
                ActionChip(
                    label: Text(
                        'Needs data: ${cards.where((i) => i.origin == InsightOrigin.unconfigured || i.tone == InsightTone.neutral).length}'),
                    onPressed: () => context.push('/insights/missing-data')),
              ]),
              ExpansionTile(
                  title: const Text('Filter assets'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    Wrap(spacing: 6, children: [
                      ChoiceChip(
                          showCheckmark: false,
                          label: const Text('All statuses'),
                          selected: status == null,
                          onSelected: (_) => setState(() => status = null)),
                      for (final s in cards.map((i) => i.status).toSet())
                        ChoiceChip(
                            showCheckmark: false,
                            label: Text(s),
                            selected: status == s,
                            onSelected: (_) => setState(() => status = s))
                    ]),
                    if (widget.assetId == null)
                      Wrap(spacing: 6, children: [
                        ChoiceChip(
                            showCheckmark: false,
                            label: const Text('All categories'),
                            selected: category == null,
                            onSelected: (_) => setState(() => category = null)),
                        for (final c in assets.map((a) => a.category).toSet())
                          ChoiceChip(
                              showCheckmark: false,
                              label: Text(AssetCategory.labelFor(c)),
                              selected: category == c,
                              onSelected: (_) => setState(() => category = c))
                      ]),
                  ]),
              const SizedBox(height: 12),
              if (pending.isNotEmpty)
                const Center(child: CircularProgressIndicator()),
              for (final id in failed)
                TextButton(
                    onPressed: () => ref.invalidate(predictionProvider(id)),
                    child: const Text(
                        'Could not load an asset recommendation. Retry')),
              if (filtered.isEmpty && pending.isEmpty && failed.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No recommendations match these filters.')),
              for (final s in filtered)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MaintenanceRecommendationCard(insight: s)),
              if (widget.assetId != null)
                TextButton(
                    onPressed: () => context
                        .push('/assets/${widget.assetId}/prediction-plan'),
                    child: const Text('Add maintenance plan')),
            ]);
          }));
}

/// Retains existing task links while using the redesigned asset insight view.
class AssetPredictionPage extends StatelessWidget {
  const AssetPredictionPage(
      {super.key, required this.assetId, required this.taskId});
  final String assetId, taskId;
  @override
  Widget build(BuildContext context) =>
      MaintenanceInsightsPage(assetId: assetId, taskId: taskId);
}
