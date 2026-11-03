import 'package:flutter/material.dart';

class AppField extends StatelessWidget {
  const AppField(
      {super.key,
      required this.label,
      this.controller,
      this.validator,
      this.keyboardType,
      this.maxLines = 1,
      this.readOnly = false,
      this.hint});
  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final String? hint;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Semantics(
            label: label,
            child: TextFormField(
                controller: controller,
                validator: validator,
                keyboardType: keyboardType,
                maxLines: maxLines,
                readOnly: readOnly,
                textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
                decoration: InputDecoration(
                    hintText: hint, alignLabelWithHint: maxLines > 1))),
      ]);
}
