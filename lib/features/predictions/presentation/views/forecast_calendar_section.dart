import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_card.dart';
import 'forecast_widgets.dart';

/// Lazy loading keeps the existing calendar usable independently of insights.
class ForecastCalendarSection extends StatefulWidget {
  const ForecastCalendarSection({super.key, this.selected});
  final DateTime? selected;
  @override
  State<ForecastCalendarSection> createState() =>
      _ForecastCalendarSectionState();
}

class _ForecastCalendarSectionState extends State<ForecastCalendarSection> {
  bool open = false;
  @override
  Widget build(BuildContext context) => ExpansionTile(
          title: const Text('Forecast dates'),
          subtitle: const Text('Usage estimates and calendar limits'),
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (v) => setState(() => open = v),
          children: [
            if (open)
              SizedBox(
                  height: 280,
                  child: ForecastLoader(builder: (data) {
                    final dated = data.insights
                        .where((i) =>
                            i.prediction?.dueAt != null &&
                            (widget.selected == null ||
                                DateUtils.isSameDay(widget.selected,
                                    i.prediction!.dueAt!.toLocal())))
                        .toList()
                      ..sort((a, b) =>
                          a.prediction!.dueAt!.compareTo(b.prediction!.dueAt!));
                    if (dated.isEmpty) {
                      return const ForecastEmpty('No forecast dates',
                          'Set up a plan and add readings. No notification is scheduled automatically.');
                    }
                    return ListView(children: [
                      for (final i in dated)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                                onTap: () => context.push(
                                    '/assets/${i.assetId}/insights/${i.prediction!.task.id}'),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(i.assetName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(
                                          '${i.prediction!.task.name} · ${forecastDate(i.prediction!.dueAt)}'),
                                      ForecastStatus(i.prediction!),
                                      const Text(
                                          'Planning date; no automatic notification.')
                                    ])))
                    ]);
                  }))
          ]);
}
