import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// A full-width selector whose menu opens below the field.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.entries,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) => DropdownMenu<T>(
            width: constraints.maxWidth,
            initialSelection: value,
            inputDecorationTheme: Theme.of(context).inputDecorationTheme,
            requestFocusOnTap: false,
            enableSearch: false,
            alignmentOffset: const Offset(0, AppSpacing.xs),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).inputDecorationTheme.fillColor),
              surfaceTintColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              alignment: AlignmentDirectional.bottomStart,
              maximumSize:
                  WidgetStatePropertyAll(Size(constraints.maxWidth, 240)),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.field),
              )),
            ),
            dropdownMenuEntries: entries,
            onSelected: onSelected,
          ),
        ),
      ]);
}
