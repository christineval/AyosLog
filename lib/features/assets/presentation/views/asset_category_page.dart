import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_category.dart';
import '../viewmodels/asset_form_viewmodel.dart';
import '../../domain/usecases/create_asset.dart';
import '../../../predictions/domain/category_templates.dart';
import '../../../predictions/presentation/views/forecast_widgets.dart';

class AssetCategoryPage extends ConsumerStatefulWidget {
  const AssetCategoryPage({super.key, required this.assetId});
  final String assetId;
  @override
  ConsumerState<AssetCategoryPage> createState() => _AssetCategoryPageState();
}

class _AssetCategoryPageState extends ConsumerState<AssetCategoryPage> {
  late Future<Asset?> asset;
  String? selected;
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final choices = <String, String>{};
  final initialized = <String>{};
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void reloadAsset() {
    final pending = ref.read(assetRepositoryProvider).findById(widget.assetId);
    setState(() {
      asset = pending;
    });
  }

  @override
  void initState() {
    super.initState();
    asset = ref.read(assetRepositoryProvider).findById(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetFormViewModelProvider);
    return Scaffold(
        appBar: const AppPageBar(title: 'Asset category'),
        body: FutureBuilder<Asset?>(
            future: asset,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                        onPressed: reloadAsset,
                        child: const Text('Could not load asset. Retry')));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final a = snapshot.data;
              if (a == null) {
                return const Center(child: Text('Asset not found.'));
              }
              selected ??= AssetCategory.fromKey(a.category)?.key ?? 'custom';
              final category = selected ?? 'custom';
              if (initialized.add(category)) {
                final profile =
                    a.profiles[category] ?? const <String, String>{};
                for (final f in assetSetupFields(category)) {
                  if (f.type == CategoryFieldType.choice) {
                    if (profile.containsKey(f.id)) {
                      choices.putIfAbsent(f.id, () => profile[f.id]!);
                    }
                  } else {
                    controllers.putIfAbsent(f.id,
                        () => TextEditingController(text: profile[f.id] ?? ''));
                  }
                }
              }
              return Form(
                  key: form,
                  child: AppFormLayout(
                      footer: AppButton(
                          label: 'Save category',
                          busy: state.isLoading,
                          onPressed: () async {
                            if (state.isLoading ||
                                !form.currentState!.validate()) {
                              return;
                            }
                            final ok = await ref
                                .read(assetFormViewModelProvider.notifier)
                                .changeCategory(a.id, category, setup: {
                              ...choices,
                              for (final e in controllers.entries)
                                e.key: e.value.text
                            });
                            if (ok && context.mounted) context.pop();
                          }),
                      children: [
                        Text(a.name,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        CategoryFormRenderer(
                            fields: assetSetupFields(category),
                            controllers: controllers,
                            choices: choices,
                            onChoice: (k, v) => setState(() => choices[k] = v)),
                        if (a.legacyCategory != null) ...[
                          Text(
                              'Original category: ${a.legacyCategory}. Choose the specific asset type if needed.'),
                          const SizedBox(height: 16)
                        ],
                        AppDropdown<String>(
                            label: 'Category',
                            value: category,
                            entries: [
                              for (final c in AssetCategory.values)
                                DropdownMenuEntry(value: c.key, label: c.label)
                            ],
                            onSelected: (v) {
                              if (v != null) setState(() => selected = v);
                            }),
                        const SizedBox(height: 16),
                        const Text(
                            'Your service records stay with this asset. Existing plans keep their measurement units.'),
                        if (state.hasError)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text('${state.error}',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                      ]));
            }));
  }
}
