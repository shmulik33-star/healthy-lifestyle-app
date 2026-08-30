import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String value;
  final String label;
  // Optional -- a card with no onTap (the default) renders and behaves
  // exactly as before, no ripple/tap target at all.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(children: [
              Icon(icon, size: 22),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}
