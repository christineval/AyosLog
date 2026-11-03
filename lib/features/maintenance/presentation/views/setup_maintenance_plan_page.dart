import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../domain/maintenance_schedule.dart';
import '../viewmodels/setup_schedule_viewmodel.dart';

class SetupMaintenancePlanPage extends ConsumerStatefulWidget {
  const SetupMaintenancePlanPage(
      {super.key, required this.assetId, this.setupFlow = true});
  final String assetId;
  final bool setupFlow;
  @override
  ConsumerState<SetupMaintenancePlanPage> createState() =>
      _SetupMaintenancePlanPageState();
}

class _SetupMaintenancePlanPageState
    extends ConsumerState<SetupMaintenancePlanPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final id = const Uuid().v4();
  int months = 3, reminderDays = 7;
  DateTime? firstDue;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  void finish() => widget.setupFlow
      ? context.go('/assets/${widget.assetId}')
      : context.pop();
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupScheduleProvider(id));
    return Scaffold(
        appBar: AppPageBar(
            title: 'Set maintenance plan',
            eyebrow: widget.setupFlow ? 'STEP 2 OF 2' : 'MAINTENANCE PLAN',
            actions: [
              if (widget.setupFlow)
                TextButton(
                    onPressed: state.isLoading ? null : finish,
                    child: const Text('Skip'))
            ]),
        body: Form(
            key: form,
            child: AppFormLayout(
                footer: AppButton(
                    label: widget.setupFlow
                        ? 'Save asset & schedule'
                        : 'Save schedule',
                    busy: state.isLoading,
                    onPressed: () async {
                      if (state.isLoading || !form.currentState!.validate()) {
                        return;
                      }
                      final due = firstDue;
                      if (due == null) return;
                      final ok = await ref
                          .read(setupScheduleProvider(id).notifier)
                          .submit(MaintenanceScheduleDraft(
                              id: id,
                              assetId: widget.assetId,
                              title: title.text,
                              intervalMonths: months,
                              firstDue: due,
                              reminderDays: reminderDays));
                      if (ok && context.mounted) finish();
                    }),
                children: [
                  AppField(
                      label: 'Task title',
                      controller: title,
                      hint: 'e.g. Change engine oil',
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter a task title.'
                          : (v ?? '').trim().length > 80
                              ? 'Keep the title within 80 characters.'
                              : null),
                  const SizedBox(height: 18),
                  AppDropdown<int>(
                      label: 'Repeat schedule',
                      value: months,
                      entries: [
                        for (final n in [1, 2, 3, 6, 12])
                          DropdownMenuEntry(
                              value: n,
                              label: 'Every $n month${n == 1 ? '' : 's'}')
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => months = v);
                      }),
                  const SizedBox(height: 18),
                  FormField<DateTime>(
                      validator: (_) => firstDue == null
                          ? 'Select the first due date.'
                          : null,
                      builder: (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppDateInput(
                                    label: 'First due date',
                                    value: firstDue == null
                                        ? 'Select date'
                                        : DateFormat.yMMMd().format(firstDue!),
                                    onTap: state.isLoading
                                        ? null
                                        : () async {
                                            final date =
                                                await showAppDatePicker(
                                                    context: context,
                                                    initialDate: firstDue ??
                                                        DateTime.now(),
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100));
                                            if (date != null && mounted) {
                                              setState(() => firstDue = date);
                                              field.didChange(date);
                                            }
                                          }),
                                if (field.errorText != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(field.errorText!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                              ])),
                  const SizedBox(height: 18),
                  AppDropdown<int>(
                      label: 'Reminder',
                      value: reminderDays,
                      entries: [
                        for (final n in [0, 1, 3, 7, 14, 30])
                          DropdownMenuEntry(
                              value: n,
                              label: n == 0
                                  ? 'On the due date'
                                  : '$n day${n == 1 ? '' : 's'} before')
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => reminderDays = v);
                      }),
                  const SizedBox(height: 12),
                  const Text(
                      'This is your schedule. Reminder lead time is used in the app’s upcoming maintenance list.'),
                  const SizedBox(height: 18),
                  TextButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context.push(
                              '/assets/${widget.assetId}/prediction-plan${widget.setupFlow ? '?setup=1' : ''}'),
                      child: const Text(
                          'Use category-specific usage or condition settings')),
                  if (state.hasError)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('${state.error}',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                ])));
  }
}
