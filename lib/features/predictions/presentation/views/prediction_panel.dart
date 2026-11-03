import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/prediction_models.dart';

String _number(num value) => NumberFormat('#,##0.##', 'en_PH').format(value);

class PredictionPanel extends ConsumerWidget {
  const PredictionPanel(
      {super.key,
      required this.assetId,
      required this.assetName,
      this.compact = false});
  final String assetId, assetName;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(predictionProvider(assetId));
    final theme = Theme.of(context);
    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Maintenance recommendations', style: theme.textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      Text(assetName, style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      state.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator())),
          error: (_, __) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Could not load recommendations.'),
                TextButton(
                    onPressed: () =>
                        ref.invalidate(predictionProvider(assetId)),
                    child: const Text('Retry')),
              ]),
          data: (report) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (report.recommendations.isEmpty) ...[
                  const Icon(Icons.tune_outlined, size: 40),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No maintenance reminders yet'),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                      'Add a job you want to remember, then choose whether to count days, hours, uses, pages, litres or distance, or record what you notice.'),
                ],
                for (final r in compact
                    ? report.recommendations.take(1)
                    : report.recommendations)
                  _Recommendation(recommendation: r, assetId: assetId),
                if (compact && report.recommendations.length > 1)
                  TextButton(
                      onPressed: () => context.push('/assets/$assetId'),
                      child: Text(
                          'View all ${report.recommendations.length} tasks')),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                    onPressed: () => context.push('/assets/$assetId/tasks/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add maintenance reminder')),
                const SizedBox(height: AppSpacing.md),
                Text(
                    'Suggested timing is an estimate, not a diagnosis. Follow your product manual. Manual details shown here were added by you.',
                    style: theme.textTheme.bodySmall),
              ])),
    ]));
  }
}

class _Recommendation extends StatelessWidget {
  const _Recommendation({required this.recommendation, required this.assetId});
  final MaintenanceRecommendation recommendation;
  final String assetId;
  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final rule = r.rule;
    final theme = Theme.of(context);
    final unit = rule?.metric.unit ?? '';
    final remaining = r.remainingValue;
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(),
          Text(r.task, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (rule != null) ...[
            Text('${rule.metric.label} · ${rule.source.label}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            if (rule.metric.numeric) ...[
              if (remaining != null)
                Text(
                    remaining > 0
                        ? '~${_number(remaining)} $unit remaining'
                        : remaining == 0
                            ? 'At the usage target'
                            : '~${_number(remaining.abs())} $unit past target',
                    style: theme.textTheme.titleLarge)
              else
                const Text(
                    'Add the last service and your latest total to see how much use is left.'),
              if (r.currentValue != null)
                Text(
                    'Latest recorded usage: ${_number(r.currentValue!)} $unit'),
              if (r.currentDate != null)
                Text('Recorded ${DateFormat.yMMMd().format(r.currentDate!)}',
                    style: theme.textTheme.bodySmall),
              if (r.targetValue != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Last service: ${_number(r.lastValue!)} $unit'),
                Text('Estimated target: ${_number(r.targetValue!)} $unit'),
                if (remaining != null &&
                    r.intervalValue != null &&
                    r.intervalValue! > 0)
                  Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: LinearProgressIndicator(
                          value: ((r.currentValue! - r.lastValue!) /
                                  r.intervalValue!)
                              .clamp(0.0, 1.0),
                          minHeight: AppSpacing.sm,
                          semanticsLabel:
                              'Recorded usage since service relative to the task interval')),
              ],
              if (r.usageDue != null)
                Text(
                    'Usage-based date: ${DateFormat.yMMMd().format(r.usageDue!)} at ~${_number(r.perDay!)} $unit/day.',
                    style: theme.textTheme.bodySmall),
            ],
            if (rule.metric == TrackingMetric.condition) ...[
              Text(
                  switch (r.condition) {
                    ObservedCondition.good => 'Looks normal',
                    ObservedCondition.watch => 'Keep an eye on it',
                    ObservedCondition.attention =>
                      'Needs attention — reported by you',
                    null => 'No recent check recorded'
                  },
                  style: theme.textTheme.titleLarge),
              if (r.currentDate != null)
                Text('Checked ${DateFormat.yMMMd().format(r.currentDate!)}'),
              if (r.conditionNotes.isNotEmpty) Text(r.conditionNotes),
            ],
            if (r.calendarDue != null)
              Text(
                  'Based on days: ${DateFormat.yMMMd().format(r.calendarDue!)}'),
            if (r.estimatedDue != null)
              Text(
                  'Next reminder: ${DateFormat.yMMMd().format(r.estimatedDue!)}',
                  style: theme.textTheme.titleMedium),
            if (r.manufacturerLimitApplied)
              const Text('Your product manual calls for an earlier limit.'),
            if ((rule.manufacturerReference ?? '').isNotEmpty)
              Text(
                  'Product manual (added by you): ${rule.manufacturerReference}',
                  style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(r.reason, style: theme.textTheme.bodySmall),
          if (rule != null)
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              if (rule.metric != TrackingMetric.time)
                TextButton.icon(
                    onPressed: () => context.push(
                        '/assets/$assetId/usage/new?task=${Uri.encodeComponent(rule.id)}'),
                    icon: Icon(rule.metric == TrackingMetric.condition
                        ? Icons.fact_check_outlined
                        : Icons.edit_outlined),
                    label: Text(rule.metric == TrackingMetric.condition
                        ? 'Add a check'
                        : rule.metric == TrackingMetric.kilometres
                            ? 'Update distance'
                            : 'Update total')),
              TextButton(
                  onPressed: () => context.push(
                      '/assets/$assetId/tasks/new?rule=${Uri.encodeComponent(rule.id)}'),
                  child: const Text('Reminder settings')),
            ])
          else
            TextButton(
                onPressed: () => context.push(
                    '/assets/$assetId/tasks/new?name=${Uri.encodeComponent(r.unconfiguredName ?? r.task)}&part=${Uri.encodeComponent(r.unconfiguredComponent)}'),
                child: const Text('Set up a reminder')),
          const SizedBox(height: AppSpacing.sm),
          if (r.highCost)
            Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadii.field)),
                child: Text(
                    'Higher cost than usual: PHP ${r.latestCost!.toStringAsFixed(2)} is ${r.costIncreasePercent!.round()}% above the earlier average of PHP ${r.baselineCost!.toStringAsFixed(2)} (${r.costSampleCount} comparable paid services). Threshold: more than 50% above average.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onErrorContainer)))
          else
            Text(
                r.baselineCost == null
                    ? 'Cost comparison needs 3 earlier paid services for the same asset, component, task and service type.'
                    : 'Earlier cost average: PHP ${r.baselineCost!.toStringAsFixed(2)} (${r.costSampleCount} comparable paid services). No high-cost flag.',
                style: theme.textTheme.bodySmall),
        ]));
  }
}
