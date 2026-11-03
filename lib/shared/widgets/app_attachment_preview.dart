import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

class AppAttachmentPreview extends StatelessWidget {
  const AppAttachmentPreview(
      {super.key,
      required this.path,
      this.height = 160,
      this.label = 'Receipt / service photo'});
  final String path, label;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label. Tap to view larger.',
      button: true,
      child: InkWell(
          onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) =>
                  AppAttachmentViewer(path: path, title: label))),
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: SizedBox(
                  height: height,
                  width: double.infinity,
                  child: Image.file(File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 1000,
                      errorBuilder: (_, __, ___) =>
                          const _UnavailableAttachment())))));
}

class AppAttachmentViewer extends StatelessWidget {
  const AppAttachmentViewer(
      {super.key, required this.path, this.title = 'Receipt / service photo'});
  final String path, title;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
          child: Center(
              child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 6,
                  child: Image.file(File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const _UnavailableAttachment())))));
}

class _UnavailableAttachment extends StatelessWidget {
  const _UnavailableAttachment();
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
          child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.broken_image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                        'Photo unavailable. The maintenance record is still saved.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall)
                  ])))));
}
