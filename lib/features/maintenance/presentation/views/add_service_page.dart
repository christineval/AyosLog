import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import 'package:intl/intl.dart';
import '../../../predictions/domain/prediction_models.dart';
import '../../../predictions/domain/prediction_usecases.dart';
import '../../../predictions/presentation/views/service_tracking_fields.dart';
import '../../../assets/domain/entities/asset.dart';
import '../../../predictions/presentation/views/forecast_widgets.dart';
import '../../domain/category_service_fields.dart';
import '../../../predictions/presentation/forecast_providers.dart';
import '../../../predictions/domain/forecast_repository.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/app_attachment_preview.dart';

class AddServicePage extends ConsumerStatefulWidget {
  const AddServicePage({super.key, required this.assetId});
  final String assetId;
  @override
  ConsumerState<AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends ConsumerState<AddServicePage> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController(),
      cost = TextEditingController(),
      task = TextEditingController(),
      component = TextEditingController(),
      shop = TextEditingController(),
      odometer = TextEditingController();
  TaskRule? selectedTask;
  String kind = 'routine', performer = 'self';
  String? receiptPath;
  DateTime date = DateTime.now();
  bool scanning = false;
  late Future<Asset?> asset;
  final serviceControllers = <String, TextEditingController>{};
  final serviceChoices = <String, String>{};
  String taskType = 'Custom';
  bool batteryReplaced = false;
  String? linkedPlanId;
  String? monthlyPlanId;
  late final serviceId = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    asset = ref.read(assetRepositoryProvider).findById(widget.assetId);
  }

  @override
  void dispose() {
    for (final c in serviceControllers.values) {
      c.dispose();
    }
    description.dispose();
    cost.dispose();
    task.dispose();
    component.dispose();
    shop.dispose();
    odometer.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    if (ref.read(predictiveServiceFormProvider(widget.assetId)).isLoading ||
        scanning) {
      return;
    }
    setState(() => scanning = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      setState(() => receiptPath = image.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final result =
            await recognizer.processImage(InputImage.fromFilePath(image.path));
        if (!mounted) return;
        if (result.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No text found. Try a clearer receipt photo or enter notes manually.')));
          return;
        }
        setState(() {
          receiptPath = image.path;
          description.text = result.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('OCR text extracted. Verify and edit before saving.')));
      } finally {
        await recognizer.close();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(predictiveServiceFormProvider(widget.assetId));
    final trackedState =
        ref.watch(forecastFormProvider('record:${widget.assetId}'));
    final forecasts = ref.watch(insightsProvider);
    final available = forecasts.valueOrNull?.source.tasks
            .where((t) => t.assetId == widget.assetId)
            .toList() ??
        [];
    final linked = available.where((t) => t.id == linkedPlanId).firstOrNull;
    final calendars = ref
            .watch(plansProvider)
            .valueOrNull
            ?.where((p) => p.assetId == widget.assetId && p.active)
            .toList() ??
        [];
    final calendar = calendars.where((p) => p.id == monthlyPlanId).firstOrNull;
    final busy = saveState.isLoading || trackedState.isLoading;
    return Scaffold(
        appBar: const AppPageBar(
            title: 'Record maintenance', eyebrow: 'SERVICE ENTRY'),
        body: FutureBuilder<Asset?>(
            future: asset,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final current = snapshot.data;
              if (snapshot.hasError || current == null) {
                return Center(
                    child: TextButton(
                        onPressed: () {
                          final pending = ref
                              .read(assetRepositoryProvider)
                              .findById(widget.assetId);
                          setState(() {
                            asset = pending;
                          });
                        },
                        child:
                            const Text('Could not load asset details. Retry')));
              }
              return Form(
                  key: form,
                  child: AppFormLayout(
                      footer: AppButton(
                          label: 'Save service record',
                          busy: busy,
                          onPressed: scanning
                              ? null
                              : () async {
                                  if (!form.currentState!.validate() || busy) {
                                    return;
                                  }
                                  final reading = parseCategoryServiceReading(
                                      current.category,
                                      {
                                        ...serviceChoices,
                                        for (final e
                                            in serviceControllers.entries)
                                          e.key: e.value.text
                                      },
                                      customUnit: linked?.unit);
                                  final saved = linked == null
                                      ? await ref.read(predictiveServiceFormProvider(widget.assetId).notifier).saveService(ServiceDraft(
                                          assetId: widget.assetId,
                                          planId: calendar?.id,
                                          description: description.text.trim(),
                                          kind: kind,
                                          cost: double.parse(cost.text),
                                          performedAt: date,
                                          receiptPath: receiptPath,
                                          task: selectedTask?.name ??
                                              calendar?.title ??
                                              (taskType == 'Custom'
                                                  ? task.text
                                                  : taskType),
                                          component: component.text,
                                          taskId: selectedTask?.id,
                                          performedBy: performer == 'self'
                                              ? 'Self'
                                              : shop.text.trim(),
                                          usageValue:
                                              selectedTask?.metric.numeric ==
                                                      true
                                                  ? (parseUsage(odometer.text, selectedTask!.metric) ??
                                                      reading.value)
                                                  : reading.value,
                                          usageUnit: reading.unit,
                                          batteryReplaced: batteryReplaced))
                                      : await ref.read(forecastFormProvider('record:${widget.assetId}').notifier).complete(
                                          ForecastCompletion(
                                              id: serviceId,
                                              assetId: widget.assetId,
                                              taskId: linked.id,
                                              at: date,
                                              description:
                                                  description.text.trim(),
                                              cost: double.parse(cost.text),
                                              value: reading.value,
                                              kind: kind,
                                              receiptPath: receiptPath,
                                              performedBy: performer == 'self'
                                                  ? 'Self'
                                                  : shop.text.trim(),
                                              batteryReplaced: batteryReplaced));
                                  if (!context.mounted) return;
                                  if (saved) {
                                    context.pop();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(linked != null
                                            ? '${ref.read(forecastFormProvider('record:${widget.assetId}')).error}'
                                            : ref
                                                .read(
                                                    predictiveServiceFormProvider(
                                                        widget.assetId))
                                                .error
                                                .toString())));
                                  }
                                }),
                      children: [
                        TextButton.icon(
                            onPressed: () => context
                                .push('/assets/${widget.assetId}/insights'),
                            icon: const Icon(Icons.insights_outlined),
                            label: const Text(
                                'Complete a tracked maintenance task')),
                        AppDropdown<String>(
                            value: kind,
                            label: 'Service type',
                            entries: const [
                              DropdownMenuEntry(
                                  value: 'routine',
                                  label: 'Routine maintenance'),
                              DropdownMenuEntry(
                                  value: 'repair', label: 'Repair'),
                              DropdownMenuEntry(
                                  value: 'inspection', label: 'Inspection'),
                              DropdownMenuEntry(value: 'other', label: 'Other')
                            ],
                            onSelected: (v) =>
                                setState(() => kind = v ?? kind)),
                        const SizedBox(height: 18),
                        AppDropdown<String>(
                            label: 'Maintenance task',
                            value: taskType,
                            entries: [
                              for (final t in serviceTasks(current.category))
                                DropdownMenuEntry(value: t, label: t)
                            ],
                            onSelected: (v) {
                              if (v != null) setState(() => taskType = v);
                            }),
                        const SizedBox(height: 18),
                        if (available.isNotEmpty || calendars.isNotEmpty) ...[
                          AppDropdown<String>(
                              label: 'Maintenance plan (optional)',
                              value: linkedPlanId ??
                                  (monthlyPlanId == null
                                      ? ''
                                      : 'calendar:$monthlyPlanId'),
                              entries: [
                                const DropdownMenuEntry(
                                    value: '', label: 'No linked plan'),
                                for (final p in available)
                                  DropdownMenuEntry(value: p.id, label: p.name),
                                for (final p in calendars)
                                  DropdownMenuEntry(
                                      value: 'calendar:${p.id}',
                                      label: '${p.title} (calendar)'),
                              ],
                              onSelected: (v) => setState(() {
                                    if (v == null || v.isEmpty) {
                                      linkedPlanId = null;
                                      monthlyPlanId = null;
                                    } else if (v.startsWith('calendar:')) {
                                      monthlyPlanId = v.substring(9);
                                      linkedPlanId = null;
                                    } else {
                                      linkedPlanId = v;
                                      monthlyPlanId = null;
                                    }
                                    selectedTask = null;
                                  })),
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                  'Choose a plan to update its next maintenance deadline.')),
                        ],
                        CategoryFormRenderer(
                            fields: categoryServiceFields(current.category,
                                customUnit: linked?.unit),
                            controllers: serviceControllers,
                            choices: serviceChoices,
                            onChoice: (k, v) =>
                                setState(() => serviceChoices[k] = v)),
                        if (current.category == 'laptop')
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('The battery was replaced'),
                              value: batteryReplaced,
                              onChanged: (v) =>
                                  setState(() => batteryReplaced = v ?? false)),
                        AppField(
                            label: 'What was done?',
                            controller: description,
                            hint: 'e.g. Oil and filter replacement',
                            maxLines: 2,
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Describe the work performed.'
                                : null),
                        const SizedBox(height: 18),
                        AppDateInput(
                            label: 'Service date',
                            value: DateUtils.isSameDay(date, DateTime.now())
                                ? 'Today'
                                : DateFormat.yMMMd().format(date),
                            onTap: busy || scanning
                                ? null
                                : () async {
                                    final picked = await showAppDatePicker(
                                        context: context,
                                        initialDate: date,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now());
                                    if (picked != null && mounted) {
                                      setState(() => date = picked);
                                    }
                                  }),
                        const SizedBox(height: 18),
                        AppField(
                            label: 'Service cost (PHP)',
                            controller: cost,
                            hint: 'e.g. 450',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              final amount = double.tryParse(v ?? '');
                              return amount == null ||
                                      !amount.isFinite ||
                                      amount < 0
                                  ? 'Enter a valid cost of zero or more.'
                                  : null;
                            }),
                        const SizedBox(height: 18),
                        AppDropdown<String>(
                            label: 'Performed by',
                            value: performer,
                            entries: const [
                              DropdownMenuEntry(value: 'self', label: 'Self'),
                              DropdownMenuEntry(
                                  value: 'shop', label: 'Repair shop')
                            ],
                            onSelected: (v) =>
                                setState(() => performer = v ?? performer)),
                        if (performer == 'shop') ...[
                          const SizedBox(height: 18),
                          AppField(
                              label: 'Repair shop name',
                              controller: shop,
                              hint: 'e.g. MotoCare',
                              validator: (v) => (v ?? '').trim().isEmpty ||
                                      v!.trim().length > 80
                                  ? 'Enter a shop name within 80 characters.'
                                  : null)
                        ],
                        const SizedBox(height: 18),
                        Text('Receipt / photos',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        AppButton(
                            label: scanning
                                ? 'Reading receipt...'
                                : receiptPath == null
                                    ? 'Add receipt photo +'
                                    : 'Choose another receipt photo',
                            outlined: true,
                            onPressed: busy || scanning ? null : scan),
                        if (receiptPath != null) ...[
                          const SizedBox(height: 12),
                          AppAttachmentPreview(path: receiptPath!)
                        ],
                        const SizedBox(height: 8),
                        Text(
                            receiptPath == null
                                ? 'Text from the receipt will be added above for you to review. Enter the cost yourself.'
                                : 'Receipt photo added. Review the extracted text and enter the cost before saving.',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 18),
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                                'Link a maintenance reminder (optional)',
                                style: Theme.of(context).textTheme.titleMedium),
                            children: [
                              ServiceTrackingFields(
                                  assetId: widget.assetId,
                                  task: task,
                                  component: component,
                                  usage: odometer,
                                  selected: selectedTask,
                                  onSelected: (r) =>
                                      setState(() => selectedTask = r))
                            ]),
                      ]));
            }));
  }
}
