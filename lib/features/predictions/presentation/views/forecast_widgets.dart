import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../domain/category_templates.dart';
import '../../domain/forecast_models.dart';
import '../forecast_providers.dart';
import '../viewmodels/forecast_viewmodels.dart';

String forecastDate(DateTime? at) => at == null
    ? 'Not available'
    : DateFormat.yMMMd().add_jm().format(at.toLocal());
String forecastNumber(double? n) =>
    n == null ? '—' : n.toStringAsFixed(n % 1 == 0 ? 0 : 1);
const localForecastNotice =
    'Saved on this device. Works offline. No automatic sensors or cloud sync.';

class ForecastLoader extends ConsumerWidget {
  const ForecastLoader({super.key, required this.builder});
  final Widget Function(ForecastScreenData) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(insightsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(insightsProvider),
                  child: const Text('Could not load local insights. Retry'))),
          data: builder);
}

class CategoryFormRenderer extends StatelessWidget {
  const CategoryFormRenderer(
      {super.key,
      required this.fields,
      required this.controllers,
      required this.choices,
      required this.onChoice});
  final List<CategoryField> fields;
  final Map<String, TextEditingController> controllers;
  final Map<String, String> choices;
  final void Function(String, String) onChoice;
  Map<String, String> get values =>
      {...choices, for (final e in controllers.entries) e.key: e.value.text};
  @override
  Widget build(BuildContext context) {
    for (final f in fields.where((f) => f.type == CategoryFieldType.choice)) {
      choices.putIfAbsent(
          f.id,
          () => f.options.contains('unknown')
              ? 'unknown'
              : f.required
                  ? f.options.first
                  : '');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in fields)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: f.type == CategoryFieldType.choice
                ? AppDropdown<String>(
                    key: ValueKey('${f.id}:${choices[f.id]}'),
                    label: f.label,
                    value: choices[f.id] ??
                        (f.options.contains('unknown')
                            ? 'unknown'
                            : f.required
                                ? f.options.first
                                : ''),
                    entries: [
                      if (!f.required && !f.options.contains('unknown'))
                        const DropdownMenuEntry(
                            value: '', label: 'Not specified'),
                      for (final option in f.options)
                        DropdownMenuEntry(
                            value: option,
                            label: option == 'unknown'
                                ? 'Unknown / not checked'
                                : option.replaceAll('_', ' '))
                    ],
                    onSelected: (v) {
                      if (v != null) onChoice(f.id, v);
                    })
                : AppField(
                    key: ValueKey(f.id),
                    label: f.label,
                    controller: controllers.putIfAbsent(
                        f.id, () => TextEditingController()),
                    keyboardType: f.type == CategoryFieldType.number
                        ? const TextInputType.numberWithOptions(
                            decimal: true, signed: true)
                        : TextInputType.text,
                    hint: f.help.isEmpty ? null : f.help,
                    validator: (_) =>
                        validateCategoryFields([f], values)[f.id]))
    ]);
  }
}

Future<DateTime?> pickForecastDate(BuildContext context, DateTime current,
    {bool time = true}) async {
  final date = await showAppDatePicker(
      context: context,
      initialDate: current.toLocal(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now());
  if (date == null || !context.mounted) return null;
  if (!time) return date;
  final clock = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(current.toLocal()));
  return clock == null
      ? null
      : DateTime(date.year, date.month, date.day, clock.hour, clock.minute);
}

class ForecastStatus extends StatelessWidget {
  const ForecastStatus(this.prediction, {super.key});
  final ForecastPrediction prediction;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        StatusPill(
            label: prediction.state.label,
            status: prediction.state == ForecastState.overdue ||
                    prediction.state == ForecastState.invalid
                ? 'overdue'
                : prediction.state == ForecastState.dueSoon ||
                        prediction.state == ForecastState.conditionAlert ||
                        prediction.stale
                    ? 'soon'
                    : 'healthy'),
        if (prediction.stale && prediction.state != ForecastState.stale)
          const StatusPill(label: 'Old reading', status: 'soon'),
        if (prediction.alerts.isNotEmpty &&
            prediction.state != ForecastState.conditionAlert)
          const StatusPill(label: 'Review needed', status: 'soon'),
      ]);
}

class ForecastEmpty extends StatelessWidget {
  const ForecastEmpty(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => AppEmptyState(
      icon: Icons.insights_outlined, title: title, message: message);
}

class ReadingChart extends StatelessWidget {
  const ReadingChart({super.key, required this.prediction});
  final ForecastPrediction prediction;
  @override
  Widget build(BuildContext context) {
    final readings =
        prediction.inputs.where((r) => r.values['reading'] != null).toList();
    if (readings.isEmpty) return const SizedBox.shrink();
    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recorded readings (${prediction.task.unit})',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Semantics(
          label: readings
              .map((r) =>
                  '${forecastDate(r.at)}: ${forecastNumber(r.values['reading'])} ${prediction.task.unit}')
              .join('. '),
          child: SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                  painter: _ReadingPainter(
                      readings,
                      prediction.task.minimum,
                      prediction.task.maximum,
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).dividerColor)))),
      Text(
          '${forecastDate(readings.first.at)} → ${forecastDate(readings.last.at)}',
          style: Theme.of(context).textTheme.bodySmall),
      if (prediction.task.minimum != null)
        Text(
            'Configured range: ${forecastNumber(prediction.task.minimum)}–${forecastNumber(prediction.task.maximum)} ${prediction.task.unit}'),
    ]));
  }
}

class _ReadingPainter extends CustomPainter {
  const _ReadingPainter(
      this.readings, this.lower, this.upper, this.accent, this.outline);
  final List<Observation> readings;
  final double? lower, upper;
  final Color accent, outline;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      ...readings.map((r) => r.values['reading']!),
      if (lower != null) lower!,
      if (upper != null) upper!
    ];
    final min = values.reduce((a, b) => a < b ? a : b),
        max = values.reduce((a, b) => a > b ? a : b);
    final span = max == min ? 1 : max - min;
    final first = readings.first.at.millisecondsSinceEpoch;
    final duration = readings.last.at.millisecondsSinceEpoch - first;
    double y(double v) =>
        size.height - 10 - (v - min) / span * (size.height - 20);
    if (lower != null && upper != null) {
      canvas.drawRect(Rect.fromLTRB(0, y(upper!), size.width, y(lower!)),
          Paint()..color = accent.withValues(alpha: .12));
    }
    canvas.drawLine(Offset(0, size.height - 1),
        Offset(size.width, size.height - 1), Paint()..color = outline);
    final path = Path();
    for (var i = 0; i < readings.length; i++) {
      final x = duration == 0
          ? size.width / 2
          : (readings[i].at.millisecondsSinceEpoch - first) /
              duration *
              size.width;
      final point = Offset(x, y(readings[i].values['reading']!));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 3, Paint()..color = accent);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = accent
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _ReadingPainter old) =>
      old.readings != readings || old.accent != accent;
}
