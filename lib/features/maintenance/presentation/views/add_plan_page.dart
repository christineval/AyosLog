import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_page_layout.dart';

class AddPlanPage extends ConsumerStatefulWidget {
  const AddPlanPage({super.key, required this.assetId});
  final String assetId;
  @override
  ConsumerState<AddPlanPage> createState() => _AddPlanPageState();
}

class _AddPlanPageState extends ConsumerState<AddPlanPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(text: 'Routine service');
  int months = 3;
  DateTime due = DateTime.now().add(const Duration(days: 30));
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          const AppPageBar(title: 'Schedule maintenance', eyebrow: 'REMINDER'),
      body: Form(
          key: form,
          child: AppFormLayout(
              footer: AppButton(
                  label: 'Save schedule',
                  busy: busy,
                  onPressed: () async {
                    if (busy || !form.currentState!.validate()) return;
                    setState(() => busy = true);
                    try {
                      await ref.read(maintenanceRepositoryProvider).createPlan(
                          assetId: widget.assetId,
                          title: title.text.trim(),
                          intervalMonths: months,
                          nextDue: due);
                      if (context.mounted) context.pop();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Could not save this schedule. Please try again.')));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  }),
              children: [
                AppField(
                    label: 'What needs to be done?',
                    controller: title,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter the job to schedule.'
                        : null),
                const SizedBox(height: 18),
                AppDropdown<int>(
                    value: months,
                    label: 'Repeat every',
                    entries: [
                      for (final n in [1, 2, 3, 6, 12])
                        DropdownMenuEntry(
                            value: n, label: '$n month${n == 1 ? '' : 's'}')
                    ],
                    onSelected: (v) => setState(() => months = v ?? months)),
                const SizedBox(height: 18),
                AppDateInput(
                    label: 'Next due date',
                    value: DateFormat.yMMMd().format(due),
                    onTap: busy
                        ? null
                        : () async {
                            final date = await showAppDatePicker(
                                context: context,
                                initialDate: due,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100));
                            if (date != null && mounted) {
                              setState(() => due = date);
                            }
                          }),
              ])));
}
