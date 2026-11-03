import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.status});
  final String label, status;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = status == 'overdue'
        ? (dark ? AppColors.errorDark : AppColors.error)
        : status == 'soon'
            ? (dark ? AppColors.warningDark : AppColors.warning)
            : (dark ? AppColors.brandDark : AppColors.brand);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}
