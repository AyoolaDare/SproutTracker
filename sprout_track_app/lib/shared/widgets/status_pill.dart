import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = switch (normalized) {
      'paid' => const Color(0xFF606C38),
      'pending' => const Color(0xFFC08E3A),
      'overdue' => const Color(0xFFC66B3D),
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
      ),
    );
  }
}
