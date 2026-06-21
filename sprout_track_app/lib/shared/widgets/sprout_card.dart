import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

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
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final effectivePadding = padding == const EdgeInsets.all(20) && isMobile
        ? const EdgeInsets.all(14)
        : padding;
    return Card(
      color: surfaceTint ?? scheme.surface,
      child: Padding(padding: effectivePadding, child: child),
    );
  }
}
