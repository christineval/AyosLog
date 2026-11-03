import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../../../shared/widgets/app_attachment_preview.dart';

class ServiceRecordPage extends ConsumerWidget {
  const ServiceRecordPage(
      {super.key, required this.assetId, required this.recordId});
  final String assetId, recordId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceRecordProvider((assetId, recordId)));
    return Scaffold(
        appBar: const AppPageBar(title: 'Service record details'),
        body: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref
                        .invalidate(serviceRecordProvider((assetId, recordId))),
                    child: const Text(
                        'Could not load the service record. Retry'))),
            data: (record) {
              if (record == null) {
                return const Center(child: Text('Service record not found.'));
              }
              return AppFormLayout(
                  footer: AppButton(
                      label: 'Record maintenance',
                      onPressed: () =>
                          context.push('/assets/$assetId/service/new')),
                  children: [
                    Text(DateFormat.yMMMMd().format(record.performedAt),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.lg),
                    AppAccentCard(
                        title: record.title,
                        subtitle: '${record.assetName} · Completed',
                        badge: 'PHP ${record.cost.toStringAsFixed(2)}',
                        highlighted: true),
                    const SizedBox(height: AppSpacing.lg),
                    AppAccentCard(
                        title: 'Work performed',
                        subtitle: record.description,
                        badge: record.performedBy.isEmpty
                            ? null
                            : 'Performed by: ${record.performedBy}',
                        highlighted: true),
                    if (record.usageValue != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppAccentCard(
                          title: 'Usage at service',
                          subtitle:
                              '${NumberFormat('#,##0.##').format(record.usageValue)} ${record.usageUnit}'),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppAccentCard(
                        title: 'Attachments',
                        subtitle: record.receiptPath == null
                            ? 'No receipt photo added.'
                            : 'Receipt photo',
                        child: record.receiptPath == null
                            ? null
                            : Column(children: [
                                AppAttachmentPreview(path: record.receiptPath!),
                                TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                        PageRouteBuilder<void>(
                                            transitionDuration: Duration.zero,
                                            reverseTransitionDuration:
                                                Duration.zero,
                                            pageBuilder: (_, __, ___) =>
                                                AppAttachmentViewer(
                                                    path:
                                                        record.receiptPath!))),
                                    child: const Text('View receipt'))
                              ])),
                  ]);
            }));
  }
}
