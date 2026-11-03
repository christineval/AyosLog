import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../viewmodels/asset_form_viewmodel.dart';
import '../../domain/entities/asset_category.dart';
import '../../domain/usecases/create_asset.dart';
import '../../../predictions/presentation/views/forecast_widgets.dart';

class AddAssetPage extends ConsumerStatefulWidget {
  const AddAssetPage({super.key});
  @override
  ConsumerState<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends ConsumerState<AddAssetPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      brand = TextEditingController(),
      model = TextEditingController();
  String category = 'vehicle';
  final setupControllers = <String, TextEditingController>{};
  final setupChoices = <String, String>{};
  Map<String, String> get setupValues => {
        ...setupChoices,
        for (final e in setupControllers.entries) e.key: e.value.text
      };
  @override
  void dispose() {
    for (final c in setupControllers.values) {
      c.dispose();
    }
    name.dispose();
    brand.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetFormViewModelProvider);
    return Scaffold(
        appBar: const AppPageBar(title: 'Add an asset', eyebrow: 'STEP 1 OF 2'),
        body: Form(
            key: form,
            child: AppFormLayout(
                footer: AppButton(
                    label: 'Continue',
                    busy: state.isLoading,
                    onPressed: () async {
                      if (state.isLoading || !form.currentState!.validate()) {
                        return;
                      }
                      final id = await ref
                          .read(assetFormViewModelProvider.notifier)
                          .submit(
                              name: name.text,
                              category: category,
                              setup: setupValues,
                              brand: brand.text,
                              model: setupValues['model'] ?? model.text);
                      if (!context.mounted) return;
                      if (id != null) {
                        context.go('/assets/$id/setup-plan');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Could not save asset. Please try again.')));
                      }
                    }),
                children: [
                  AppField(
                      label: 'Asset name',
                      controller: name,
                      hint: 'e.g. LG Refrigerator',
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter an asset name.'
                          : null),
                  const SizedBox(height: 18),
                  AppDropdown<String>(
                      value: category,
                      label: 'Category',
                      entries: [
                        for (final c in AssetCategory.values)
                          DropdownMenuEntry(value: c.key, label: c.label),
                      ],
                      onSelected: (v) =>
                          setState(() => category = v ?? category)),
                  const SizedBox(height: 18),
                  CategoryFormRenderer(
                      fields: assetSetupFields(category),
                      controllers: setupControllers,
                      choices: setupChoices,
                      onChoice: (k, v) => setState(() => setupChoices[k] = v)),
                  AppField(
                      label: 'Brand (optional)',
                      controller: brand,
                      hint: 'e.g. LG, Honda, Samsung'),
                  const SizedBox(height: 18),
                  if (!assetSetupFields(category).any((f) => f.id == 'model'))
                    AppField(
                        label: 'Model (optional)',
                        controller: model,
                        hint: 'Enter the model name'),
                  const SizedBox(height: 24),
                  Text(
                      'You can add service records and set up reminders after saving.',
                      style: Theme.of(context).textTheme.bodySmall),
                ])));
  }
}
