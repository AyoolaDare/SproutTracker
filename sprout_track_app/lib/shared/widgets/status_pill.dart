import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final (bg, fg) = switch (normalized) {
      'paid'    => (const Color(0xFFD6E8C0), const Color(0xFF3A5C18)),
      'pending' => (const Color(0xFFF5E6C0), const Color(0xFF7A5A10)),
      'overdue' => (const Color(0xFFF7D5C0), const Color(0xFF8C3410)),
      _         => (
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.onPrimaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: .2,
            ),
      ),
    );
  }
}
