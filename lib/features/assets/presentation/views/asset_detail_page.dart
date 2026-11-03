import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_category.dart';
import '../../../predictions/presentation/views/maintenance_recommendation_card.dart';
import '../../../../shared/widgets/app_attachment_preview.dart';

class AssetDetailPage extends ConsumerStatefulWidget {
  const AssetDetailPage({super.key, required this.assetId});
  final String assetId;
  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  late Future<Asset?> asset;
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

  Future<void> archive() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Archive this asset?'),
                content: const Text('Its service records will be kept.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Archive'))
                ]));
    if (confirmed != true) return;
    try {
      await ref.read(assetRepositoryProvider).archive(widget.assetId);
      if (mounted) context.go('/assets');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not archive this asset. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(serviceHistoryProvider(widget.assetId));
    final plans = ref.watch(plansProvider);
    final theme = Theme.of(context);
    final subtle = theme.brightness == Brightness.dark
        ? AppColors.darkSubtle
        : AppColors.lightSubtle;
    return Scaffold(
        appBar: AppPageBar(title: 'Asset details', actions: [
          IconButton(
              tooltip: 'Change asset category',
              onPressed: () async {
                await context.push('/assets/${widget.assetId}/category');
                if (mounted) {
                  reloadAsset();
                }
              },
              icon: const Icon(Icons.category_outlined)),
          IconButton(
              tooltip: 'Insights',
              onPressed: () => context
                  .push('/assets/${widget.assetId}/maintenance-insights'),
              icon: const Icon(Icons.insights_outlined)),
          IconButton(
              tooltip: 'Archive asset',
              onPressed: archive,
              icon: const Icon(Icons.archive_outlined))
        ]),
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
              return ExpansionTileTheme(
                  data: ExpansionTileTheme.of(context).copyWith(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    expansionAnimationStyle: const AnimationStyle(
                      duration: Duration(milliseconds: 280),
                      reverseDuration: Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      reverseCurve: Curves.easeInOutCubic,
                    ),
                  ),
                  child: AppFormLayout(
                      footer: AppButton(
                          label: '+ Record maintenance',
                          onPressed: a.archived
                              ? null
                              : () => context.push(
                                  '/assets/${widget.assetId}/service/new')),
                      children: [
                        if (a.category == 'custom' && a.legacyCategory != null)
                          Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.md),
                              child: TextButton.icon(
                                  icon: const Icon(Icons.category_outlined),
                                  label: Text(
                                      'Previously ${a.legacyCategory}. Choose a specific asset category.'),
                                  onPressed: () async {
                                    await context.push(
                                        '/assets/${widget.assetId}/category');
                                    if (mounted) {
                                      reloadAsset();
                                    }
                                  })),
                        Card(
                            color: subtle,
                            child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(a.name,
                                          style: theme.textTheme.titleLarge),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                          [
                                            AssetCategory.labelFor(a.category),
                                            a.brand,
                                            a.model
                                          ]
                                              .where((s) => s.isNotEmpty)
                                              .join(' · '),
                                          style: theme.textTheme.bodySmall),
                                      const SizedBox(height: AppSpacing.md),
                                      Text(
                                          'Added ${DateFormat.yMMM().format(a.createdAt)}',
                                          style: theme.textTheme.bodySmall),
                                    ]))),
                        const SizedBox(height: AppSpacing.xl),
                        Text('Overview & service history',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.lg),
                        plans.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (_, __) => TextButton(
                                onPressed: () => ref.invalidate(plansProvider),
                                child: const Text(
                                    'Could not load the next service. Retry')),
                            data: (all) {
                              final upcoming = all
                                  .where((p) =>
                                      p.active && p.assetId == widget.assetId)
                                  .toList()
                                ..sort(
                                    (x, y) => x.nextDue.compareTo(y.nextDue));
                              final next =
                                  upcoming.isEmpty ? null : upcoming.first;
                              final days = next == null
                                  ? null
                                  : DateUtils.dateOnly(next.nextDue)
                                      .difference(
                                          DateUtils.dateOnly(DateTime.now()))
                                      .inDays;
                              return AppAccentCard(
                                  title: 'Next service',
                                  highlighted: true,
                                  subtitle: next == null
                                      ? 'No task scheduled yet.'
                                      : '${next.title} · ${DateFormat.yMMMd().format(next.nextDue)}',
                                  badge: days == null
                                      ? null
                                      : days < 0
                                          ? 'Overdue'
                                          : days <= next!.reminderDays
                                              ? 'Due soon'
                                              : 'Scheduled',
                                  onTap: () => context.push(
                                      '/assets/${widget.assetId}/schedules/new'),
                                  child: TextButton(
                                      onPressed: () => context.push(
                                          '/assets/${widget.assetId}/schedules/new'),
                                      child: const Text('Schedule a task')));
                            }),
                        const SizedBox(height: AppSpacing.lg),
                        records.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (_, __) => TextButton(
                                onPressed: () => ref.invalidate(
                                    serviceHistoryProvider(widget.assetId)),
                                child: const Text(
                                    'Could not load service history. Retry')),
                            data: (history) {
                              final last =
                                  history.isEmpty ? null : history.first;
                              final attachments = history
                                  .where((r) => r.receiptPath != null)
                                  .toList();
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AppAccentCard(
                                        title: 'Last completed',
                                        subtitle: last == null
                                            ? 'No maintenance recorded yet.'
                                            : '${last.title} · ${DateFormat.MMMd().format(last.performedAt)}',
                                        badge:
                                            last == null ? null : 'Completed',
                                        onTap: last == null
                                            ? null
                                            : () => context.push(
                                                '/assets/${widget.assetId}/service/${last.id}')),
                                    const SizedBox(height: AppSpacing.lg),
                                    AppAccentCard(
                                        title: 'Receipts and photos',
                                        subtitle: attachments.isEmpty
                                            ? 'No receipt photos added.'
                                            : '${attachments.length} saved receipt ${attachments.length == 1 ? 'photo' : 'photos'}',
                                        badge: attachments.isEmpty
                                            ? null
                                            : 'View receipt',
                                        onTap: attachments.isEmpty
                                            ? null
                                            : () => context.push(
                                                '/assets/${widget.assetId}/service/${attachments.first.id}')),
                                    if (history.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.lg),
                                      ExpansionTile(
                                          maintainState: true,
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(
                                              'All service records (${history.length})',
                                              style:
                                                  theme.textTheme.titleMedium),
                                          children: [
                                            for (final r in history)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom:
                                                              AppSpacing.md),
                                                  child: AppAccentCard(
                                                      title: r.title,
                                                      subtitle:
                                                          '${DateFormat.yMMMd().format(r.performedAt)} · PHP ${r.cost.toStringAsFixed(2)}',
                                                      child: r.receiptPath ==
                                                              null
                                                          ? null
                                                          : AppAttachmentPreview(
                                                              path: r
                                                                  .receiptPath!,
                                                              height: 110),
                                                      onTap: () => context.push(
                                                          '/assets/${widget.assetId}/service/${r.id}')))
                                          ]),
                                    ],
                                  ]);
                            }),
                        const SizedBox(height: AppSpacing.lg),
                        ExpansionTile(
                            maintainState: true,
                            tilePadding: EdgeInsets.zero,
                            title: Text('Maintenance recommendations',
                                style: theme.textTheme.titleMedium),
                            subtitle: const Text(
                                'Usage totals, checks and suggested timing'),
                            children: [
                              AssetMaintenanceRecommendations(
                                  assetId: widget.assetId)
                            ]),
                      ]));
            }));
  }
}
