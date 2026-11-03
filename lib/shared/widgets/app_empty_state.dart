import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
        child: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ExcludeSemantics(
                      child: Icon(icon,
                          size: 64, color: theme.colorScheme.primary)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ]))));
  }
}
