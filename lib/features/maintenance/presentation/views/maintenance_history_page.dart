import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_attachment_preview.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';

class MaintenanceHistoryPage extends ConsumerWidget {
  const MaintenanceHistoryPage({super.key, required this.assetId});
  final String assetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('Maintenance history')),
      body: ref.watch(serviceHistoryProvider(assetId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: TextButton(
                  onPressed: () =>
                      ref.invalidate(serviceHistoryProvider(assetId)),
                  child:
                      const Text('Could not load maintenance history. Retry'))),
          data: (records) => records.isEmpty
              ? const AppEmptyState(
                  icon: Icons.history,
                  title: 'No maintenance recorded yet',
                  message:
                      'Completed services and their receipt photos will appear here.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (c, index) {
                    final r = records[index];
                    return AppCard(
                        onTap: () =>
                            context.push('/assets/$assetId/service/${r.id}'),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.assetName,
                                  style: Theme.of(c).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                  '${r.title} · ${DateFormat.yMMMd().format(r.performedAt.toLocal())}',
                                  style: Theme.of(c).textTheme.bodySmall),
                              const SizedBox(height: 10),
                              Text(r.description),
                              const SizedBox(height: 8),
                              Text('PHP ${r.cost.toStringAsFixed(2)}'),
                              if (r.receiptPath != null) ...[
                                const SizedBox(height: 12),
                                AppAttachmentPreview(
                                    path: r.receiptPath!, height: 130)
                              ],
                              TextButton(
                                  onPressed: () => context
                                      .push('/assets/$assetId/service/${r.id}'),
                                  child: const Text('View maintenance record')),
                            ]));
                  })));
}
