import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/forecast_repository.dart';
import '../forecast_providers.dart';
import 'forecast_widgets.dart';

Future<bool> confirmForecastDeletion(BuildContext context, String title) =>
    showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(title),
                content: const Text(
                    'The entry will be excluded from forecasts. Its earlier version remains in the correction audit.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Keep entry')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'))
                ])).then((v) => v ?? false);

class ForecastHistoryPage extends ConsumerWidget {
  const ForecastHistoryPage({super.key, required this.assetId, this.taskId});
  final String assetId;
  final String? taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(forecastFormProvider('history:$assetId'));
    return Scaffold(
        appBar: const AppPageBar(title: 'Readings & service history'),
        body: ForecastLoader(builder: (data) {
          final task = data.source.tasks
              .where((t) =>
                  t.assetId == assetId && (taskId == null || t.id == taskId))
              .firstOrNull;
          if (task == null) {
            return const ForecastEmpty('No plan history',
                'Create a maintenance plan and record a reading first.');
          }
          final readings = data.source.observations
              .where((r) =>
                  r.assetId == assetId && r.taskId == task.id && !r.deleted)
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at));
          final services = data.source.completions
              .where((c) =>
                  c.assetId == assetId && c.taskId == task.id && !c.voided)
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at));
          final audits = data.source.audit
              .where((a) => a.taskId == task.id)
              .toList()
            ..sort((a, b) => b.at.compareTo(a.at));
          final prediction = data.insights
              .where((i) => i.prediction?.task.id == task.id)
              .firstOrNull
              ?.prediction;
          return AppFormLayout(
              footer: AppButton(
                  label: 'Add reading',
                  onPressed: () => context
                      .push('/assets/$assetId/check-in?task=${task.id}')),
              children: [
                Text(task.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                const Text(localForecastNotice),
                const SizedBox(height: 16),
                if (prediction != null) ReadingChart(prediction: prediction),
                const SizedBox(height: 16),
                Text('Usage and condition checks',
                    style: Theme.of(context).textTheme.titleLarge),
                if (readings.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                          'No observations yet. Add a reading or condition report.')),
                for (final o in readings)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(forecastDate(o.at),
                                style: Theme.of(context).textTheme.titleMedium),
                            for (final e in o.values.entries)
                              Text(
                                  '${e.key.replaceAll('_', ' ')}: ${forecastNumber(e.value)}${e.key == 'reading' ? ' ${task.unit}' : ''}'),
                            for (final e in o.conditions.entries)
                              Text(
                                  '${e.key.replaceAll('_', ' ')}: ${e.value.replaceAll('_', ' ')}'),
                            Text(
                                'Source: ${o.source.name} • revision ${o.version}${o.reset ? ' • meter reset' : ''}'),
                            if (o.notes.isNotEmpty) Text(o.notes),
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: state.isLoading
                                      ? null
                                      : () => context.push(
                                          '/assets/$assetId/check-in?task=${task.id}&entry=${o.id}'),
                                  child: const Text('Correct')),
                              TextButton(
                                  onPressed: state.isLoading
                                      ? null
                                      : () async {
                                          if (!await confirmForecastDeletion(
                                              context,
                                              'Delete this observation?')) {
                                            return;
                                          }
                                          await ref
                                              .read(forecastFormProvider(
                                                      'history:$assetId')
                                                  .notifier)
                                              .deleteReading(o);
                                        },
                                  child: const Text('Delete'))
                            ]),
                          ]))),
                const SizedBox(height: 24),
                Text('Completed services',
                    style: Theme.of(context).textTheme.titleLarge),
                if (services.isEmpty)
                  const Text('No linked completed services yet.'),
                for (final c in services)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(forecastDate(c.at),
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(c.description),
                            Text('PHP ${c.cost.toStringAsFixed(2)}'),
                            if (c.value != null)
                              Text(
                                  '${forecastNumber(c.value)} ${task.unit} at service'),
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: () => context
                                      .push('/assets/$assetId/service/${c.id}'),
                                  child: const Text('Details / receipt')),
                              TextButton(
                                  onPressed: state.isLoading
                                      ? null
                                      : () => context.push(
                                          '/assets/$assetId/prediction-service?task=${task.id}&service=${c.id}'),
                                  child: const Text('Correct')),
                              TextButton(
                                  onPressed: state.isLoading
                                      ? null
                                      : () async {
                                          if (!await confirmForecastDeletion(
                                              context,
                                              'Cancel this completed service?')) {
                                            return;
                                          }
                                          await ref
                                              .read(forecastFormProvider(
                                                      'history:$assetId')
                                                  .notifier)
                                              .complete(ForecastCompletion(
                                                  id: c.id,
                                                  assetId: c.assetId,
                                                  taskId: c.taskId,
                                                  at: c.at,
                                                  description: c.description,
                                                  cost: c.cost,
                                                  value: c.value,
                                                  version: c.version,
                                                  batteryReplaced:
                                                      c.batteryReplaced,
                                                  receiptPath: c.receiptPath,
                                                  performedBy: c.performedBy,
                                                  kind: c.kind,
                                                  voided: true));
                                        },
                                  child: const Text('Cancel service')),
                            ]),
                          ]))),
                const SizedBox(height: 24),
                ExpansionTile(
                    title: const Text('Correction audit'),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      for (final a in audits)
                        ListTile(
                            title: Text(a.action.replaceAll('_', ' ')),
                            subtitle:
                                Text('${forecastDate(a.at)} • ${a.recordId}'),
                            onTap: () => showDialog<void>(
                                context: context,
                                builder: (c) =>
                                    AlertDialog(
                                        title:
                                            const Text('Local audit evidence'),
                                        content: SingleChildScrollView(
                                            child: SelectableText(
                                                'Before:\n${a.before ?? 'No earlier version'}\n\nAfter:\n${a.after ?? 'Excluded from forecasts'}')),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text('Close'))
                                        ]))),
                    ]),
                if (state.hasError)
                  Text('${state.error}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]);
        }));
  }
}
