import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../domain/prediction_models.dart';
import '../../domain/prediction_usecases.dart';

// The route/class name is retained for old deep links; the form is task-specific.
class AddMileagePage extends ConsumerStatefulWidget {
  const AddMileagePage({super.key, required this.assetId, this.taskId});
  final String assetId;
  final String? taskId;
  @override
  ConsumerState<AddMileagePage> createState() => _AddMileagePageState();
}

class _AddMileagePageState extends ConsumerState<AddMileagePage> {
  final form = GlobalKey<FormState>();
  final usage = TextEditingController(), notes = TextEditingController();
  DateTime recordedAt = DateTime.now();
  String? selectedId;
  ObservedCondition condition = ObservedCondition.good;
  @override
  void initState() {
    super.initState();
    selectedId = widget.taskId;
  }

  @override
  void dispose() {
    usage.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mileageFormProvider(widget.assetId));
    final report = ref.watch(predictionProvider(widget.assetId));
    return Scaffold(
        appBar: AppBar(title: const Text('Add a total or a check')),
        body: report.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(predictionProvider(widget.assetId)),
                    child: const Text('Could not load tasks. Retry'))),
            data: (data) {
              final tasks = data.rules
                  .where((r) =>
                      r.metric != TrackingMetric.time &&
                      (r.metric != TrackingMetric.kilometres || data.isCar))
                  .toList();
              if (tasks.isEmpty) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.page),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.tune_outlined, size: 48),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                              'Set up a reminder first. Jobs based only on days use the last service date and need no usage total.'),
                          TextButton(
                              onPressed: () => context
                                  .push('/assets/${widget.assetId}/tasks/new'),
                              child: const Text('Set up a reminder')),
                        ])));
              }
              if (!tasks.any((r) => r.id == selectedId)) {
                selectedId = tasks.first.id;
              }
              final task = tasks.firstWhere((r) => r.id == selectedId);
              return SafeArea(
                  child: Form(
                      key: form,
                      child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          children: [
                            AppDropdown<String>(
                                label: 'What needs to be done?',
                                value: task.id,
                                entries: [
                                  for (final r in tasks)
                                    DropdownMenuEntry(
                                        value: r.id, label: r.displayName)
                                ],
                                onSelected: state.isLoading
                                    ? (_) {}
                                    : (v) => setState(() {
                                          selectedId = v;
                                          usage.clear();
                                          notes.clear();
                                        })),
                            const SizedBox(height: AppSpacing.xl),
                            if (task.metric.numeric) ...[
                              Text(
                                  '${task.metric.explanation} Keep a running total: if the previous total was 100 and you add 5, enter 105. Keep the total after each service.'),
                              const SizedBox(height: AppSpacing.md),
                              AppField(
                                  label: task.metric.totalLabel,
                                  controller: usage,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: !task.metric.whole),
                                  validator: (v) {
                                    try {
                                      return parseUsage(v ?? '', task.metric) ==
                                              null
                                          ? 'Enter the total.'
                                          : null;
                                    } on PredictionValidationException catch (e) {
                                      return e.message;
                                    }
                                  }),
                            ] else ...[
                              const Text(
                                  'Record what you observed. This is not an automated diagnosis.'),
                              const SizedBox(height: AppSpacing.md),
                              AppDropdown<ObservedCondition>(
                                  label: 'What do you notice?',
                                  value: condition,
                                  entries: const [
                                    DropdownMenuEntry(
                                        value: ObservedCondition.good,
                                        label: 'Looks normal'),
                                    DropdownMenuEntry(
                                        value: ObservedCondition.watch,
                                        label: 'Keep an eye on it'),
                                    DropdownMenuEntry(
                                        value: ObservedCondition.attention,
                                        label: 'Needs attention')
                                  ],
                                  onSelected: state.isLoading
                                      ? (_) {}
                                      : (v) => setState(
                                          () => condition = v ?? condition)),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            AppField(
                                label: 'Notes (optional)',
                                controller: notes,
                                maxLines: 3,
                                validator: (v) => (v ?? '').length > 1000
                                    ? 'Use 1,000 characters or fewer.'
                                    : null),
                            const SizedBox(height: AppSpacing.md),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Date recorded'),
                                subtitle: Text(
                                    '${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}'),
                                trailing:
                                    const Icon(Icons.calendar_today_outlined),
                                onTap: state.isLoading
                                    ? null
                                    : () async {
                                        final date = await showAppDatePicker(
                                            context: context,
                                            initialDate: recordedAt,
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime.now());
                                        if (date != null && mounted) {
                                          setState(() => recordedAt = date);
                                        }
                                      }),
                            if (state.hasError)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md),
                                  child: Text(state.error.toString(),
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                                label: 'Save reading',
                                busy: state.isLoading,
                                onPressed: () async {
                                  if (!form.currentState!.validate()) return;
                                  final reading = TaskUsageReading(
                                      taskId: task.id,
                                      recordedAt: recordedAt,
                                      value: task.metric.numeric
                                          ? parseUsage(usage.text, task.metric)
                                          : null,
                                      condition: task.metric ==
                                              TrackingMetric.condition
                                          ? condition
                                          : null,
                                      notes: notes.text);
                                  final saved = await ref
                                      .read(mileageFormProvider(widget.assetId)
                                          .notifier)
                                      .saveTaskReading(widget.assetId, reading);
                                  if (saved && context.mounted) context.pop();
                                }),
                          ])));
            }));
  }
}
