import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../domain/entities/asset_category.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});
  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  String query = '', category = 'all';
  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('My assets')),
        body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(children: [
                TextField(
                    onChanged: (s) => setState(() => query = s),
                    decoration: const InputDecoration(
                        hintText: 'Search your assets',
                        prefixIcon: Icon(Icons.search))),
                const SizedBox(height: 12),
                SizedBox(
                    height: 48,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          'all',
                          ...AssetCategory.values.map((c) => c.key)
                        ]
                            .map((c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(c == 'all'
                                        ? 'All'
                                        : AssetCategory.labelFor(c)),
                                    selected: category == c,
                                    onSelected: (_) =>
                                        setState(() => category = c))))
                            .toList())),
                const SizedBox(height: 16),
                Expanded(
                    child: assets.when(
                        data: (list) {
                          final filtered = list
                              .where((a) =>
                                  a.name
                                      .toLowerCase()
                                      .contains(query.toLowerCase()) &&
                                  (category == 'all' || a.category == category))
                              .toList();
                          if (filtered.isEmpty) {
                            return AppEmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: list.isEmpty
                                  ? 'No assets yet'
                                  : 'No matching assets',
                              message: list.isEmpty
                                  ? 'Add an asset to start tracking maintenance.'
                                  : 'Try another search or category.',
                            );
                          }
                          return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final a = filtered[i];
                                return AppCard(
                                    onTap: () =>
                                        context.push('/assets/${a.id}'),
                                    child: Row(children: [
                                      CircleAvatar(
                                          child: Icon(a.category == 'vehicle'
                                              ? Icons.two_wheeler
                                              : Icons.build_outlined)),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(a.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium),
                                            const SizedBox(height: 4),
                                            Text(
                                                '${AssetCategory.labelFor(a.category)} • ${a.brand}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall)
                                          ])),
                                      const Icon(Icons.chevron_right)
                                    ]));
                              });
                        },
                        error: (e, _) =>
                            Center(child: Text('Could not load assets: $e')),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()))),
                const SizedBox(height: 12),
                AppButton(
                    label: '+ Add new asset',
                    onPressed: () => context.push('/assets/new'))
              ])),
        ));
  }
}
