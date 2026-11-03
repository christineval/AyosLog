import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar(
      {super.key,
      required this.title,
      this.eyebrow = 'OVERVIEW',
      this.actions});
  final String title, eyebrow;
  final List<Widget>? actions;
  @override
  Size get preferredSize => const Size.fromHeight(104);
  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: 104,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: Navigator.of(context).canPop() ? 0 : AppSpacing.page,
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(eyebrow,
                  textScaler: TextScaler.noScaling,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(title,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.25),
                  style: Theme.of(context).textTheme.headlineLarge),
            ]),
        actions: actions,
      );
}

class AppFormLayout extends StatelessWidget {
  const AppFormLayout(
      {super.key, required this.children, required this.footer});
  final List<Widget> children;
  final Widget footer;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Column(children: [
        Expanded(
            child: CustomScrollView(
                key: const ValueKey('form-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                      AppSpacing.md, AppSpacing.page, AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children))),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg),
            child: footer),
      ]));
}

class AppDateInput extends StatelessWidget {
  const AppDateInput(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap});
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Material(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadii.field),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        child: Row(children: [
                          Expanded(child: Text(value)),
                          const Icon(Icons.keyboard_arrow_down, size: 20)
                        ]))))),
      ]);
}

class AppAccentCard extends StatelessWidget {
  const AppAccentCard(
      {super.key,
      required this.title,
      required this.subtitle,
      this.badge,
      this.highlighted = false,
      this.onTap,
      this.child});
  final String title, subtitle;
  final String? badge;
  final bool highlighted;
  final VoidCallback? onTap;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.brightness == Brightness.dark
        ? AppColors.darkSubtle
        : AppColors.lightSubtle;
    return Card(
        margin: EdgeInsets.zero,
        color: highlighted ? subtle : theme.colorScheme.surface,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Container(
                          width: 5,
                          decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.field))),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Text(subtitle, style: theme.textTheme.bodySmall),
                            if (badge != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                      color: subtle,
                                      borderRadius: BorderRadius.circular(
                                          AppRadii.field)),
                                  child: Text(badge!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)))
                            ],
                            if (child != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              child!
                            ],
                          ])),
                    ])))));
  }
}
