import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../shared/widgets/app_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(themeProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(22), children: [
            Text('Make AyosLog yours',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 20),
            AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Appearance',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  RadioGroup<ThemeMode>(
                      groupValue: value,
                      onChanged: (mode) {
                        ref.read(themeProvider.notifier).set(mode!);
                      },
                      child: Column(children: [
                        for (final mode in ThemeMode.values)
                          RadioListTile<ThemeMode>(
                              value: mode,
                              title: Text(mode == ThemeMode.system
                                  ? 'Use device setting'
                                  : mode == ThemeMode.dark
                                      ? 'Dark mode'
                                      : 'Light mode'))
                      ]))
                ])),
            const SizedBox(height: 12),
            const AppCard(
                child: ListTile(
                    title: Text('Storage'),
                    subtitle: Text(
                        'Your data is stored locally on this device. Cloud synchronization is planned and is not enabled in this build.'),
                    leading: Icon(Icons.storage_outlined))),
            const SizedBox(height: 12),
            const AppCard(
                child: ListTile(
                    title: Text('About'),
                    subtitle:
                        Text('AyosLog v0.1 · Offline maintenance tracker'),
                    leading: Icon(Icons.info_outline)))
          ]),
        ));
  }
}
