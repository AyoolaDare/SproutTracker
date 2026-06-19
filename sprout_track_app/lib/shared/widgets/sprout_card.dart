import 'package:flutter/material.dart';

class SproutCard extends StatelessWidget {
  const SproutCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.surfaceTint,
    super.key,
  });

  final Widget              child;
  final EdgeInsetsGeometry  padding;
  final Color?              surfaceTint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: surfaceTint ?? scheme.surface,
      child: Padding(padding: padding, child: child),
    );
  }
}
