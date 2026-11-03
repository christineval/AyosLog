import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../domain/prediction_models.dart';
import '../../domain/prediction_usecases.dart';

class ServiceTrackingFields extends ConsumerWidget {
  const ServiceTrackingFields(
      {super.key,
      required this.assetId,
      required this.task,
      required this.component,
      required this.usage,
      required this.selected,
      required this.onSelected});
  final String assetId;
  final TextEditingController task, component, usage;
  final TaskRule? selected;
  final ValueChanged<TaskRule?> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(predictionProvider(assetId));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Link to a reminder (optional)',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      settings.when(
          loading: () => const Text('Loading task settings...'),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(predictionProvider(assetId)),
              child: const Text('Reminder settings unavailable. Retry')),
          data: (report) => AppDropdown<String>(
              label: 'Saved maintenance job',
              value: selected?.id ?? '',
              entries: [
                const DropdownMenuEntry(value: '', label: 'No saved job'),
                for (final r in report.rules)
                  if (r.metric != TrackingMetric.kilometres || report.isCar)
                    DropdownMenuEntry(value: r.id, label: r.displayName)
              ],
              onSelected: (id) {
                TaskRule? chosen;
                for (final r in report.rules) {
                  if (r.id == id) chosen = r;
                }
                task.text = chosen?.name ?? '';
                component.text = chosen?.component ?? '';
                usage.clear();
                onSelected(chosen);
              })),
      const SizedBox(height: 14),
      if (selected == null) ...[
        const Text(
            'Use the same job and part names each time so costs can be compared. You can also set up a reminder on the item page.'),
        const SizedBox(height: 14),
        AppField(
            label: 'What needs to be done?',
            controller: task,
            hint: 'e.g. Cleaning, oil change, replacement',
            validator: (v) => (v ?? '').trim().length > 80
                ? 'Use 80 characters or fewer.'
                : null),
        const SizedBox(height: 14),
        AppField(
            label: 'Which part? (optional)',
            controller: component,
            validator: (v) => (v ?? '').trim().length > 80
                ? 'Use 80 characters or fewer.'
                : null),
      ] else ...[
        Text('Tracking: ${selected!.metric.label}'),
        if (selected!.metric.numeric) ...[
          const SizedBox(height: 8),
          Text(
              'Enter the total ${selected!.metric.unit} at this service, not today’s reading. Leave blank if unknown; the app will not guess.'),
          const SizedBox(height: 14),
          AppField(
              label: selected!.metric.serviceLabel,
              controller: usage,
              keyboardType: TextInputType.numberWithOptions(
                  decimal: !selected!.metric.whole),
              validator: (v) {
                try {
                  parseUsage(v ?? '', selected!.metric);
                  return null;
                } on PredictionValidationException catch (e) {
                  return e.message;
                }
              }),
        ] else
          const Text(
              'The date tells the app when you last did this job. You can record what you notice separately.'),
      ],
    ]);
  }
}
