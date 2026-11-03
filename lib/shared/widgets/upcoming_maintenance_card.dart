import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_card.dart';
import 'status_pill.dart';

class UpcomingMaintenanceCard extends StatelessWidget {
  const UpcomingMaintenanceCard(
      {super.key,
      required this.assetName,
      required this.serviceType,
      required this.date,
      required this.label,
      required this.status,
      required this.onTap});
  final String assetName, serviceType, label, status;
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
      onTap: onTap,
      child: Row(children: [
        CircleAvatar(
            child: Icon(Icons.build_outlined,
                color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(assetName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('$serviceType · ${DateFormat.yMMMd().format(date.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          StatusPill(label: label, status: status),
        ])),
        const Icon(Icons.chevron_right),
      ]));
}
