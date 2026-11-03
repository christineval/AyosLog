import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../domain/prediction_models.dart';

class TaskRulePage extends ConsumerStatefulWidget {
  const TaskRulePage(
      {super.key,
      required this.assetId,
      this.ruleId,
      this.taskName = '',
      this.partName = ''});
  final String assetId, taskName, partName;
  final String? ruleId;
  @override
  ConsumerState<TaskRulePage> createState() => _TaskRulePageState();
}

class _TaskRulePageState extends ConsumerState<TaskRulePage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      component = TextEditingController(),
      usage = TextEditingController(),
      days = TextEditingController(),
      manualUsage = TextEditingController(),
      manualDays = TextEditingController(),
      reference = TextEditingController();
  TrackingMetric metric = TrackingMetric.time;
  RuleSource source = RuleSource.user;
  bool initialized = false, markAsCar = false, applyManual = false;
  @override
  void dispose() {
    for (final c in [
      name,
      component,
      usage,
      days,
      manualUsage,
      manualDays,
      reference
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void initialize(PredictionReport report) {
    if (initialized) return;
    initialized = true;
    name.text = widget.taskName;
    component.text = widget.partName;
    for (final r in report.rules) {
      if (r.id == widget.ruleId) {
        name.text = r.name;
        component.text = r.component;
        metric = r.metric;
        source = r.source;
        usage.text = r.usageInterval?.toString() ?? '';
        days.text = r.daysInterval?.toString() ?? '';
        manualUsage.text = r.manufacturerUsageLimit?.toString() ?? '';
        manualDays.text = r.manufacturerDaysLimit?.toString() ?? '';
        reference.text = r.manufacturerReference ?? '';
        applyManual =
            r.manufacturerUsageLimit != null || r.manufacturerDaysLimit != null;
      }
    }
  }

  String? positive(String? text, {bool whole = false, bool dayCount = false}) {
    if ((text ?? '').trim().isEmpty) return null;
    final n = double.tryParse(text!.trim());
    if (n == null ||
        !n.isFinite ||
        n <= 0 ||
        n > (dayCount ? 36500 : 1e12) ||
        (whole && n != n.roundToDouble())) {
      return dayCount
          ? 'Enter 1–36,500 whole days.'
          : 'Enter a positive value in the selected unit.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(predictionProvider(widget.assetId));
    final saving = ref.watch(taskRuleFormProvider(widget.assetId));
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.ruleId == null
                ? 'Add maintenance reminder'
                : 'Reminder settings')),
        body: report.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(predictionProvider(widget.assetId)),
                    child: const Text('Could not load task settings. Retry'))),
            data: (data) {
              initialize(data);
              if (widget.ruleId != null &&
                  !data.rules.any((r) => r.id == widget.ruleId)) {
                return const Center(child: Text('Task not found.'));
              }
              final canEnableCar =
                  ['vehicle', 'car'].contains(data.category.toLowerCase());
              final canUseMileage = data.isCar || markAsCar;
              return SafeArea(
                  child: Form(
                      key: form,
                      child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          children: [
                            const Text(
                                'Set a reminder for a job, such as cleaning a filter, changing oil or replacing a battery.'),
                            const SizedBox(height: AppSpacing.xl),
                            AppField(
                                label: 'What needs to be done?',
                                controller: name,
                                hint:
                                    'e.g. Clean the filter or replace the battery',
                                readOnly: widget.ruleId != null,
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'Tell us what needs to be done.'
                                    : null),
                            const SizedBox(height: AppSpacing.md),
                            AppField(
                                label: 'Which part? (optional)',
                                controller: component,
                                readOnly: widget.ruleId != null,
                                hint: 'e.g. Drum, air filter, battery'),
                            if (canEnableCar && !data.isCar)
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('This is a car'),
                                  subtitle: const Text(
                                      'Show distance-driven reminders for this car.'),
                                  value: markAsCar,
                                  onChanged: saving.isLoading
                                      ? null
                                      : (v) => setState(() {
                                            markAsCar = v ?? false;
                                            if (!markAsCar &&
                                                metric ==
                                                    TrackingMetric.kilometres) {
                                              metric = TrackingMetric.time;
                                            }
                                          })),
                            const SizedBox(height: AppSpacing.md),
                            if (widget.ruleId != null)
                              Text(
                                  'Remind me based on: ${metric.label}. Create another task to use a different component or measure.')
                            else
                              AppDropdown<TrackingMetric>(
                                  label: 'Remind me based on',
                                  value: metric,
                                  entries: [
                                    for (final m in TrackingMetric.values)
                                      if (m != TrackingMetric.kilometres ||
                                          canUseMileage)
                                        DropdownMenuEntry(
                                            value: m, label: m.label)
                                  ],
                                  onSelected: saving.isLoading
                                      ? (_) {}
                                      : (v) => setState(() {
                                            metric = v ?? metric;
                                            usage.clear();
                                            manualUsage.clear();
                                            if (metric ==
                                                    TrackingMetric.condition &&
                                                source == RuleSource.history) {
                                              source = RuleSource.user;
                                            }
                                          })),
                            const SizedBox(height: AppSpacing.md),
                            Text(metric.explanation),
                            const SizedBox(height: AppSpacing.md),
                            AppDropdown<RuleSource>(
                                label: 'Base the timing on',
                                value: source,
                                entries: [
                                  for (final s in RuleSource.values)
                                    if (metric != TrackingMetric.condition ||
                                        s != RuleSource.history)
                                      DropdownMenuEntry(
                                          value: s, label: s.label)
                                ],
                                onSelected: saving.isLoading
                                    ? (_) {}
                                    : (v) =>
                                        setState(() => source = v ?? source)),
                            const SizedBox(height: AppSpacing.md),
                            if (source == RuleSource.history)
                              const Text(
                                  'AyosLog uses at least 3 records of this same routine job to estimate when you usually do it. Repairs are kept out of this estimate.'),
                            if (source == RuleSource.user) ...[
                              if (metric.numeric)
                                AppField(
                                    label: 'Repeat every (${metric.unit})',
                                    controller: usage,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (v) =>
                                        positive(v, whole: metric.whole)),
                              const SizedBox(height: AppSpacing.md),
                              AppField(
                                  label: metric.numeric
                                      ? 'Also repeat every (days, optional)'
                                      : 'Repeat every (days)',
                                  controller: days,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      positive(v, whole: true, dayCount: true)),
                            ],
                            if (metric == TrackingMetric.condition)
                              const Text(
                                  'Tell us whether it looks normal, needs watching, or needs attention. This records what you noticed; it does not diagnose a fault.'),
                            if (source != RuleSource.manufacturer)
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                      'Use limits from the product manual'),
                                  value: applyManual,
                                  onChanged: saving.isLoading
                                      ? null
                                      : (v) => setState(
                                          () => applyManual = v ?? false)),
                            if (source == RuleSource.manufacturer ||
                                applyManual) ...[
                              const Text(
                                  'Use the instructions for your exact model. Add the manual page or link so you can check it later. AyosLog has not checked these instructions.'),
                              const SizedBox(height: AppSpacing.md),
                              if (metric.numeric)
                                AppField(
                                    label:
                                        'Manual: repeat every (${metric.unit})',
                                    controller: manualUsage,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (v) =>
                                        positive(v, whole: metric.whole)),
                              const SizedBox(height: AppSpacing.md),
                              AppField(
                                  label: 'Manual: repeat every (days)',
                                  controller: manualDays,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      positive(v, whole: true, dayCount: true)),
                              const SizedBox(height: AppSpacing.md),
                              AppField(
                                  label: 'Manual page, model or link',
                                  controller: reference,
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Add the manual page, model or link.'
                                      : null),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                                'If both days and usage apply, the earlier reminder wins. The app will not suggest waiting past a limit you entered from the manual.'),
                            if (saving.hasError)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md),
                                  child: Text(saving.error.toString(),
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                                label: 'Save reminder',
                                busy: saving.isLoading,
                                onPressed: () async {
                                  if (!form.currentState!.validate()) return;
                                  final manual =
                                      source == RuleSource.manufacturer ||
                                          applyManual;
                                  final rule = TaskRule(
                                      id: widget.ruleId ?? '',
                                      name: name.text,
                                      component: component.text,
                                      metric: metric,
                                      source: source,
                                      usageInterval: source ==
                                                  RuleSource.user &&
                                              metric.numeric
                                          ? double.tryParse(usage.text.trim())
                                          : null,
                                      daysInterval: source == RuleSource.user
                                          ? double.tryParse(days.text.trim())
                                              ?.toInt()
                                          : null,
                                      manufacturerUsageLimit:
                                          manual && metric.numeric
                                              ? double.tryParse(
                                                  manualUsage.text.trim())
                                              : null,
                                      manufacturerDaysLimit: manual
                                          ? double.tryParse(
                                                  manualDays.text.trim())
                                              ?.toInt()
                                          : null,
                                      manufacturerReference:
                                          manual ? reference.text : null);
                                  final saved = await ref
                                      .read(taskRuleFormProvider(widget.assetId)
                                          .notifier)
                                      .saveRule(widget.assetId, rule,
                                          markAsCar: markAsCar);
                                  if (saved && context.mounted) context.pop();
                                }),
                          ])));
            }));
  }
}
