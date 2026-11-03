import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.outlined = false,
      this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool outlined, busy;
  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onPrimary))
        : Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily:
                    Theme.of(context).textTheme.labelLarge?.fontFamily));
    final centered =
        SizedBox(width: double.infinity, child: Center(child: child));
    return SizedBox(
        width: double.infinity,
        child: outlined
            ? OutlinedButton(
                onPressed: busy ? null : onPressed, child: centered)
            : ElevatedButton(
                onPressed: busy ? null : onPressed, child: centered));
  }
}
