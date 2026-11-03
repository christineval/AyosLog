import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/widgets/app_attachment_preview.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../domain/category_templates.dart';
import '../../domain/forecast_models.dart';
import '../../domain/forecast_repository.dart';
import '../forecast_providers.dart';
import 'forecast_widgets.dart';

String methodLabel(UsageMethod m) => switch (m) {
      UsageMethod.counter => 'Actual cumulative counter',
      UsageMethod.estimated => 'Estimated usage',
      UsageMethod.trend => 'Dated condition measurements',
      UsageMethod.calendar => 'Calendar only'
    };

class ForecastPlanPage extends ConsumerStatefulWidget {
  const ForecastPlanPage(
      {super.key, required this.assetId, this.taskId, this.setupFlow = false});
  final String assetId;
  final String? taskId;
  final bool setupFlow;
  @override
  ConsumerState<ForecastPlanPage> createState() => _ForecastPlanPageState();
}

class _ForecastPlanPageState extends ConsumerState<ForecastPlanPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final choices = <String, String>{};
  final name = TextEditingController(), reference = TextEditingController();
  late final id = widget.taskId ?? const Uuid().v4();
  bool initialized = false;
  AssetSubtype subtype = AssetSubtype.custom;
  UsageMethod method = UsageMethod.counter;
  PlanSource source = PlanSource.owner;
  DateTime at = DateTime.now();
  int version = 1;
  String taskType = 'Custom';
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    name.dispose();
    reference.dispose();
    super.dispose();
  }

  Map<String, String> get values =>
      {...choices, for (final e in fields.entries) e.key: e.value.text};
  void initialize(ForecastAsset asset, ForecastTask? t) {
    if (initialized) return;
    initialized = true;
    final available = subtypesForCategory(asset.category);
    subtype = t?.subtype ??
        (available.contains(asset.subtype) ? asset.subtype : available.first)!;
    method = t?.method ?? methodsFor(subtype).first;
    source = t?.source ?? PlanSource.owner;
    at = t?.baselineAt.toLocal() ?? DateTime.now();
    version = t?.version ?? 1;
    name.text = t?.name ?? '';
    taskType = categoryTemplates[subtype]!.tasks.contains(t?.name)
        ? t!.name
        : 'Custom';
    reference.text = t?.reference ?? '';
    fields['warning_days'] =
        TextEditingController(text: '${t?.warningDays ?? 7}');
    fields['warning_percent'] =
        TextEditingController(text: '${(t?.warningFraction ?? .1) * 100}');
    fields['freshness_days'] =
        TextEditingController(text: '${t?.freshnessDays ?? 30}');
    {
      for (final e in {
        if (t != null) 'baseline': '${t.baseline}',
        'interval': t?.interval?.toString() ?? '',
        'interval_days': t?.intervalDays?.toString() ?? '',
        'minimum': t?.minimum?.toString() ?? '',
        'maximum': t?.maximum?.toString() ?? '',
        'custom_unit': t?.customUnit ?? '',
        ...asset.setup,
        ...?t?.setup
      }.entries) {
        final f = planFieldsFor(subtype, method)
            .where((f) => f.id == e.key)
            .firstOrNull;
        if (f?.type == CategoryFieldType.choice) {
          choices[e.key] = e.value;
        } else {
          fields[e.key] = TextEditingController(text: e.value);
        }
      }
    }
    choices['unit'] = subtype == AssetSubtype.refrigerator ? '°C' : 'km';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forecastFormProvider('plan:$id'));
    return Scaffold(
        appBar: AppPageBar(
            title:
                widget.setupFlow ? 'Set maintenance plan' : 'Maintenance plan',
            eyebrow: widget.setupFlow ? 'STEP 2 OF 2' : 'MAINTENANCE PLAN',
            actions: [
              if (widget.setupFlow)
                TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => context.go('/assets/${widget.assetId}'),
                    child: const Text('Skip'))
            ]),
        body: ForecastLoader(builder: (data) {
          final asset = data.source.assets
              .where((a) => a.id == widget.assetId && !a.archived)
              .firstOrNull;
          final existing = data.source.tasks
              .where(
                  (t) => t.id == widget.taskId && t.assetId == widget.assetId)
              .firstOrNull;
          if (asset == null || widget.taskId != null && existing == null) {
            return const ForecastEmpty('Plan unavailable',
                'Open an active asset to configure maintenance.');
          }
          initialize(asset, existing);
          return Form(
              key: form,
              child: AppFormLayout(
                  footer: AppButton(
                      label: widget.setupFlow
                          ? 'Save asset & schedule'
                          : 'Save maintenance plan',
                      busy: state.isLoading,
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        final ok = await ref
                            .read(forecastFormProvider('plan:$id').notifier)
                            .savePlan(
                                id: id,
                                assetId: widget.assetId,
                                name: name.text,
                                subtype: subtype,
                                method: method,
                                baselineAt: at,
                                source: source,
                                reference: reference.text,
                                values: values,
                                version: version);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Maintenance plan saved locally.')));
                          if (widget.setupFlow) {
                            context.go('/assets/${widget.assetId}');
                          } else {
                            context.pop();
                          }
                        }
                      }),
                  children: [
                    Text(asset.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    const Text(
                        'Enter intervals from your own plan or product manual. The app does not supply manufacturer schedules.'),
                    const SizedBox(height: 16),
                    if (existing == null) ...[
                      AppDropdown<AssetSubtype>(
                          label: 'Asset type',
                          value: subtype,
                          entries: [
                            for (final s in subtypesForCategory(asset.category))
                              DropdownMenuEntry(value: s, label: s.label)
                          ],
                          onSelected: (s) {
                            if (s != null) {
                              setState(() {
                                subtype = s;
                                method = methodsFor(s).first;
                                choices.clear();
                                choices['unit'] = s == AssetSubtype.refrigerator
                                    ? '°C'
                                    : 'km';
                              });
                            }
                          }),
                      const SizedBox(height: 16),
                      AppDropdown<UsageMethod>(
                          label: 'How will you track this?',
                          value: method,
                          entries: [
                            for (final m in methodsFor(subtype))
                              DropdownMenuEntry(value: m, label: methodLabel(m))
                          ],
                          onSelected: (m) {
                            if (m != null) setState(() => method = m);
                          }),
                      const SizedBox(height: 16),
                    ] else
                      Text(
                          '${subtype.label} • ${methodLabel(method)}. Create another plan to change the measurement.'),
                    const SizedBox(height: 12),
                    if (existing == null) ...[
                      AppDropdown<String>(
                          label: 'Maintenance task',
                          value: taskType,
                          entries: [
                            for (final t in categoryTemplates[subtype]!.tasks)
                              DropdownMenuEntry(value: t, label: t)
                          ],
                          onSelected: (v) {
                            if (v != null) {
                              setState(() {
                                taskType = v;
                                if (v != 'Custom') name.text = v;
                              });
                            }
                          }),
                      const SizedBox(height: 16)
                    ],
                    AppField(
                        label: 'Task name',
                        controller: name,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter a task name.'
                            : null),
                    const SizedBox(height: 16),
                    if (existing == null)
                      TextButton(
                          onPressed: () => context.push(
                              '/assets/${widget.assetId}/schedules/monthly'),
                          child: const Text('Use a monthly calendar reminder')),
                    AppDateInput(
                        label: 'Last service / starting date',
                        value: forecastDate(at),
                        onTap: () async {
                          final chosen = await pickForecastDate(context, at);
                          if (chosen != null && mounted) {
                            setState(() => at = chosen);
                          }
                        }),
                    const SizedBox(height: 16),
                    CategoryFormRenderer(
                        fields: planFieldsFor(subtype, method),
                        controllers: fields,
                        choices: choices,
                        onChoice: (k, v) => setState(() => choices[k] = v)),
                    AppDropdown<PlanSource>(
                        label: 'Where does this interval come from?',
                        value: source,
                        entries: const [
                          DropdownMenuEntry(
                              value: PlanSource.owner, label: 'My own plan'),
                          DropdownMenuEntry(
                              value: PlanSource.manufacturer,
                              label: 'Product manual')
                        ],
                        onSelected: (s) {
                          if (s != null) setState(() => source = s);
                        }),
                    const SizedBox(height: 16),
                    AppField(
                        label:
                            'Model, manual page or link${source == PlanSource.owner ? ' (optional)' : ''}',
                        controller: reference),
                    if (state.hasError)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('${state.error}',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    const SizedBox(height: 16),
                    const Text(localForecastNotice),
                  ]));
        }));
  }
}

class ForecastCheckInPage extends ConsumerStatefulWidget {
  const ForecastCheckInPage(
      {super.key,
      required this.assetId,
      this.taskId,
      this.entryId,
      this.conditionsOnly = false});
  final String assetId;
  final String? taskId, entryId;
  final bool conditionsOnly;
  @override
  ConsumerState<ForecastCheckInPage> createState() =>
      _ForecastCheckInPageState();
}

class _ForecastCheckInPageState extends ConsumerState<ForecastCheckInPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final choices = <String, String>{};
  final notes = TextEditingController();
  late final id = widget.entryId ?? const Uuid().v4();
  String? selected;
  bool initialized = false, reset = false, confirmed = false;
  DateTime at = DateTime.now();
  EvidenceSource source = EvidenceSource.manual;
  int version = 1;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forecastFormProvider('reading:$id'));
    return Scaffold(
        appBar: AppPageBar(
            title:
                widget.conditionsOnly ? 'Condition check' : 'Record a reading'),
        body: ForecastLoader(builder: (data) {
          final tasks = data.source.tasks
              .where((t) => t.assetId == widget.assetId)
              .toList();
          if (tasks.isEmpty) {
            return const ForecastEmpty('Set up a plan first',
                'A plan defines which units and measurements belong to this asset.');
          }
          final existing = data.source.observations
              .where((o) =>
                  o.id == widget.entryId &&
                  o.assetId == widget.assetId &&
                  !o.deleted)
              .firstOrNull;
          if (widget.entryId != null && existing == null) {
            return const ForecastEmpty('Reading unavailable',
                'This reading may have been deleted. Return to history.');
          }
          if (!initialized) {
            initialized = true;
            selected = existing?.taskId ?? widget.taskId ?? tasks.first.id;
            if (existing != null) {
              at = existing.at.toLocal();
              source = existing.source;
              notes.text = existing.notes;
              reset = existing.reset;
              confirmed = existing.confirmed;
              version = existing.version;
              for (final e in existing.values.entries) {
                fields[e.key] = TextEditingController(text: e.value.toString());
              }
              choices.addAll(existing.conditions);
            }
          }
          final task = tasks.where((t) => t.id == selected).firstOrNull;
          if (task == null) {
            return const ForecastEmpty('Plan unavailable',
                'Select a valid maintenance plan from the asset.');
          }
          final template = categoryTemplates[task.subtype]!;
          choices.putIfAbsent('unit',
              () => task.subtype == AssetSubtype.refrigerator ? '°C' : 'km');
          final conditionOnly = widget.conditionsOnly ||
              existing != null && existing.values.isEmpty;
          final definitions = conditionOnly
              ? template.conditions
              : template.fields(task.method);
          return Form(
              key: form,
              child: AppFormLayout(
                  footer: AppButton(
                      label: 'Save observation',
                      busy: state.isLoading,
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        final ok = await ref
                            .read(forecastFormProvider('reading:$id').notifier)
                            .saveReading(
                                task: task,
                                id: id,
                                values: {
                                  ...choices,
                                  for (final e in fields.entries)
                                    e.key: e.value.text
                                },
                                at: at,
                                source: source,
                                notes: notes.text,
                                reset: reset,
                                confirmed: confirmed,
                                version: version,
                                conditionsOnly: conditionOnly);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Observation saved locally; forecast updated.')));
                          context.pop();
                        }
                      }),
                  children: [
                    Text(task.subtype.label,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (widget.taskId == null && existing == null) ...[
                      AppDropdown<String>(
                          label: 'Maintenance plan',
                          value: task.id,
                          entries: [
                            for (final t in tasks)
                              DropdownMenuEntry(value: t.id, label: t.name)
                          ],
                          onSelected: (v) {
                            if (v != null) {
                              setState(() {
                                selected = v;
                                choices.clear();
                                for (final c in fields.values) {
                                  c.clear();
                                }
                                reset = false;
                              });
                            }
                          }),
                      const SizedBox(height: 16)
                    ] else
                      Text(task.name,
                          style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text(task.method == UsageMethod.estimated
                        ? 'These are your usage estimates, not readings from a sensor.'
                        : 'Enter what you measured or checked; choose Unknown for unchecked conditions.'),
                    const SizedBox(height: 16),
                    CategoryFormRenderer(
                        fields: definitions,
                        controllers: fields,
                        choices: choices,
                        onChoice: (k, v) => setState(() => choices[k] = v)),
                    AppDateInput(
                        label: 'Observed at',
                        value: forecastDate(at),
                        onTap: () async {
                          final d = await pickForecastDate(context, at);
                          if (d != null && mounted) setState(() => at = d);
                        }),
                    const SizedBox(height: 16),
                    AppDropdown<EvidenceSource>(
                        label: 'Measurement source',
                        value: source,
                        entries: const [
                          DropdownMenuEntry(
                              value: EvidenceSource.manual, label: 'Manual'),
                          DropdownMenuEntry(
                              value: EvidenceSource.imported,
                              label: 'Imported (entered from another record)')
                        ],
                        onSelected: (s) {
                          if (s != null) setState(() => source = s);
                        }),
                    const SizedBox(height: 16),
                    AppField(
                        label: 'Notes (optional; required for a meter reset)',
                        controller: notes,
                        maxLines: 3),
                    if (task.metric.counter &&
                        task.method == UsageMethod.counter)
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('The meter was replaced or reset'),
                          value: reset,
                          onChanged: (v) => setState(() => reset = v ?? false)),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                            'I checked any unusual reading and confirm it is correct'),
                        value: confirmed,
                        onChanged: (v) =>
                            setState(() => confirmed = v ?? false)),
                    if (state.hasError)
                      Text('${state.error}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    const Text(localForecastNotice),
                  ]));
        }));
  }
}

class ForecastServicePage extends ConsumerStatefulWidget {
  const ForecastServicePage(
      {super.key, required this.assetId, required this.taskId, this.serviceId});
  final String assetId, taskId;
  final String? serviceId;
  @override
  ConsumerState<ForecastServicePage> createState() =>
      _ForecastServicePageState();
}

class _ForecastServicePageState extends ConsumerState<ForecastServicePage> {
  String distanceUnit = 'km';
  String? receiptPath;
  bool picking = false;
  bool batteryReplaced = false;
  final description = TextEditingController(),
      cost = TextEditingController(),
      counter = TextEditingController(),
      performer = TextEditingController();
  final form = GlobalKey<FormState>();
  late final id = widget.serviceId ?? const Uuid().v4();
  bool initialized = false;
  DateTime at = DateTime.now();
  int version = 1;
  @override
  void dispose() {
    description.dispose();
    cost.dispose();
    counter.dispose();
    performer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forecastFormProvider('service:$id'));
    return Scaffold(
        appBar: const AppPageBar(
            title: 'Complete maintenance', eyebrow: 'SERVICE ENTRY'),
        body: ForecastLoader(builder: (data) {
          final task = data.source.tasks
              .where(
                  (t) => t.id == widget.taskId && t.assetId == widget.assetId)
              .firstOrNull;
          final existing = data.source.completions
              .where((c) =>
                  c.id == widget.serviceId &&
                  c.taskId == widget.taskId &&
                  !c.voided)
              .firstOrNull;
          if (task == null || widget.serviceId != null && existing == null) {
            return const ForecastEmpty(
                'Service unavailable', 'Return to the asset to select a plan.');
          }
          if (!initialized) {
            initialized = true;
            if (existing != null) {
              description.text = existing.description;
              cost.text = '${existing.cost}';
              counter.text = existing.value?.toString() ?? '';
              at = existing.at.toLocal();
              version = existing.version;
              batteryReplaced = existing.batteryReplaced;
              receiptPath = existing.receiptPath;
              performer.text = existing.performedBy;
            }
          }
          final needsCounter =
              task.metric.counter && task.method == UsageMethod.counter;
          return Form(
              key: form,
              child: AppFormLayout(
                  footer: AppButton(
                      label: 'Save completed service',
                      busy: state.isLoading,
                      onPressed: picking
                          ? null
                          : () async {
                              if (!form.currentState!.validate()) return;
                              final ok = await ref
                                  .read(forecastFormProvider('service:$id')
                                      .notifier)
                                  .complete(
                                      ForecastCompletion(
                                          id: id,
                                          assetId: widget.assetId,
                                          taskId: widget.taskId,
                                          at: at.toUtc(),
                                          description: description.text,
                                          cost: double.tryParse(cost.text) ??
                                              double.nan,
                                          value: needsCounter
                                              ? double.tryParse(counter.text)
                                              : null,
                                          version: version,
                                          batteryReplaced: batteryReplaced,
                                          receiptPath: receiptPath,
                                          performedBy: performer.text.trim()),
                                      distanceUnit: distanceUnit);
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Service saved; this task’s next deadline recalculated.')));
                                context.pop();
                              }
                            }),
                  children: [
                    Text(task.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    AppField(
                        label: 'What was done?',
                        controller: description,
                        maxLines: 3,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Describe the work.'
                            : null),
                    const SizedBox(height: 16),
                    AppField(
                        label: 'Service cost (PHP)',
                        controller: cost,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          return n == null || !n.isFinite || n < 0
                              ? 'Enter a nonnegative cost.'
                              : null;
                        }),
                    const SizedBox(height: 16),
                    AppField(
                        label: 'Performed by (optional)',
                        controller: performer),
                    const SizedBox(height: 16),
                    if (needsCounter) ...[
                      AppField(
                          label: task.subtype == AssetSubtype.vehicle
                              ? 'Odometer at service'
                              : 'Counter at service (${task.unit})',
                          controller: counter,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) => (v ?? '').trim().isEmpty &&
                                  task.subtype != AssetSubtype.vehicle
                              ? null
                              : double.tryParse(v ?? '') == null
                                  ? 'Enter the actual cumulative counter.'
                                  : null),
                      const SizedBox(height: 16)
                    ],
                    if (task.subtype == AssetSubtype.vehicle &&
                        needsCounter) ...[
                      AppDropdown<String>(
                          label: 'Distance unit',
                          value: distanceUnit,
                          entries: const [
                            DropdownMenuEntry(value: 'km', label: 'km'),
                            DropdownMenuEntry(value: 'mi', label: 'mi')
                          ],
                          onSelected: (v) {
                            if (v != null) setState(() => distanceUnit = v);
                          }),
                      const SizedBox(height: 16)
                    ],
                    AppDateInput(
                        label: 'Actual service date',
                        value: forecastDate(at),
                        onTap: () async {
                          final d = await pickForecastDate(context, at);
                          if (d != null && mounted) setState(() => at = d);
                        }),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(receiptPath == null
                            ? 'Add receipt / service photo'
                            : 'Change receipt / service photo'),
                        onPressed: state.isLoading || picking
                            ? null
                            : () async {
                                setState(() => picking = true);
                                try {
                                  final photo = await ImagePicker()
                                      .pickImage(source: ImageSource.gallery);
                                  if (photo != null && mounted) {
                                    setState(() => receiptPath = photo.path);
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Could not open photos. Retry.')));
                                  }
                                } finally {
                                  if (mounted) setState(() => picking = false);
                                }
                              }),
                    if (receiptPath != null)
                      AppAttachmentPreview(path: receiptPath!),
                    const SizedBox(height: 16),
                    if (task.subtype == AssetSubtype.laptop)
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('The battery was replaced'),
                          value: batteryReplaced,
                          onChanged: (v) =>
                              setState(() => batteryReplaced = v ?? false)),
                    const Text(
                        'This resets only the selected task. Backdated services use the actual service date, not today. Battery trends restart only when a replacement is recorded.'),
                    if (state.hasError)
                      Text('${state.error}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    const Text(localForecastNotice),
                  ]));
        }));
  }
}
