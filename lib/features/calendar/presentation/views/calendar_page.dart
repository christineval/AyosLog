import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_layout.dart';
import '../../../predictions/presentation/views/forecast_calendar_section.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime focus = DateTime.now();
  DateTime? selected;
  Future<void> schedule() async {
    final assets = ref.read(assetsProvider).valueOrNull ?? [];
    if (assets.isEmpty) {
      context.go('/assets');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add an asset before scheduling maintenance.')));
      return;
    }
    var id = assets.first.id;
    if (assets.length > 1) {
      final chosen = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Text('Choose an asset',
                        style: Theme.of(c).textTheme.titleLarge)),
                for (final a in assets)
                  ListTile(
                      title: Text(a.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(c, a.id)),
              ])));
      if (chosen == null || !mounted) return;
      id = chosen;
    }
    if (mounted) context.push('/assets/$id/schedules/new');
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);
    final assets = ref.watch(assetsProvider);
    final names = {for (final a in assets.valueOrNull ?? []) a.id: a.name};
    final weekStart =
        DateUtils.dateOnly(focus).subtract(Duration(days: focus.weekday - 1));
    Widget footer() => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.xl),
        child: AppButton(
            label: 'Schedule a task',
            onPressed: assets.isLoading ? null : schedule));
    Widget fill(Widget content) => SliverFillRemaining(
        hasScrollBody: false,
        child: Column(children: [Expanded(child: content), footer()]));
    return Scaffold(
        appBar: const AppPageBar(title: 'Maintenance calendar'),
        body: SafeArea(
            top: false,
            child: CustomScrollView(slivers: [
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                      AppSpacing.md, AppSpacing.page, AppSpacing.lg),
                  sliver: SliverToBoxAdapter(
                      child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .inputDecorationTheme
                                  .fillColor,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.card)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(children: [
                                      for (var i = 0; i < 7; i++)
                                        Builder(builder: (context) {
                                          final date =
                                              weekStart.add(Duration(days: i));
                                          final active = selected != null &&
                                              DateUtils.isSameDay(
                                                  date, selected);
                                          return SizedBox(
                                              width: 48,
                                              child: TextButton(
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                      backgroundColor: active
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .surface
                                                          : null,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical:
                                                              AppSpacing.md)),
                                                  onPressed: () => setState(
                                                      () => selected =
                                                          active ? null : date),
                                                  child:
                                                      Column(mainAxisSize: MainAxisSize.min, children: [
                                                    Text(
                                                        DateFormat.E()
                                                            .format(date)
                                                            .substring(0, 1),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall),
                                                    const SizedBox(
                                                        height: AppSpacing.sm),
                                                    Text('${date.day}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleLarge)
                                                  ])));
                                        })
                                    ])),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Select a date to view scheduled tasks',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ])))),
              SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  sliver: SliverToBoxAdapter(
                      child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.onSurface),
                            onPressed: () async {
                              final date = await showAppDatePicker(
                                  context: context,
                                  initialDate: focus,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100));
                              if (date != null && mounted) {
                                setState(() {
                                  focus = date;
                                  selected = date;
                                });
                              }
                            },
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            label: Text(
                                '${DateFormat.yMMMM().format(focus).toUpperCase()} · Month')),
                        if (selected != null)
                          TextButton(
                              onPressed: () => setState(() => selected = null),
                              child: const Text('Show all')),
                      ]))),
              SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  sliver: SliverToBoxAdapter(
                      child: ForecastCalendarSection(selected: selected))),
              ...plans.when(
                  loading: () =>
                      [fill(const Center(child: CircularProgressIndicator()))],
                  error: (_, __) => [
                        fill(Center(
                            child: TextButton(
                                onPressed: () => ref.invalidate(plansProvider),
                                child: const Text(
                                    'Could not load the calendar. Retry'))))
                      ],
                  data: (all) {
                    final sorted = all
                        .where((p) =>
                            p.active &&
                            (selected == null ||
                                DateUtils.isSameDay(selected, p.nextDue)))
                        .toList()
                      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
                    if (sorted.isEmpty) {
                      return [
                        fill(AppEmptyState(
                            icon: Icons.calendar_month_outlined,
                            title: selected == null
                                ? 'Nothing scheduled yet'
                                : 'No tasks on this date',
                            message: selected == null
                                ? 'Add a maintenance plan to an asset to see upcoming dates.'
                                : 'Choose another date or schedule a task.'))
                      ];
                    }
                    return [
                      SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                              AppSpacing.sm, AppSpacing.page, 0),
                          sliver: SliverList.list(children: [
                            for (var i = 0; i < sorted.length; i++)
                              Builder(builder: (context) {
                                final p = sorted[i];
                                final days = DateUtils.dateOnly(p.nextDue)
                                    .difference(
                                        DateUtils.dateOnly(DateTime.now()))
                                    .inDays;
                                final badge = days < 0
                                    ? 'Overdue'
                                    : days == 0
                                        ? 'Due today'
                                        : days == 1
                                            ? 'Due tomorrow'
                                            : days <= p.reminderDays
                                                ? 'Due in $days days'
                                                : 'Upcoming';
                                return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.md),
                                    child: AppAccentCard(
                                        title: names[p.assetId] ?? 'Asset',
                                        subtitle:
                                            '${p.title} · ${DateFormat.yMMMd().format(p.nextDue.toLocal())}',
                                        badge: badge,
                                        highlighted: i == 0,
                                        onTap: () => context
                                            .push('/assets/${p.assetId}')));
                              })
                          ])),
                      SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [footer()])),
                    ];
                  }),
            ])));
  }
}
