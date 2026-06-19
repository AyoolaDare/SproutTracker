import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SproutPage extends StatelessWidget {
  const SproutPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final horizontalPadding = isMobile ? 14.0 : (isTablet ? 20.0 : 28.0);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 14 : 24, horizontalPadding, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 620,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: (isMobile
                                  ? Theme.of(context).textTheme.headlineMedium
                                  : Theme.of(context).textTheme.headlineLarge)
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          subtitle,
                          style: (isMobile
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : Theme.of(context).textTheme.bodyLarge)
                              ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              SizedBox(height: isMobile ? 16 : 22),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
