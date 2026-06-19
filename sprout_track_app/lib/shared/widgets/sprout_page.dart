import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../app/app_theme.dart';

class SproutPage extends StatelessWidget {
  const SproutPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
    super.key,
  });

  final String       title;
  final String       subtitle;
  final Widget?      action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bp              = ResponsiveBreakpoints.of(context);
    final isMobile        = bp.isMobile;
    final isTablet        = bp.isTablet;
    final hPad            = isMobile ? 16.0 : (isTablet ? 22.0 : 30.0);
    final scheme          = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, isMobile ? 16 : 26, hPad, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Accent bar above title
                        Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.moss,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          title,
                          style: (isMobile
                                  ? Theme.of(context).textTheme.headlineMedium
                                  : Theme.of(context).textTheme.headlineLarge)
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: (isMobile
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : Theme.of(context).textTheme.bodyLarge)
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 16),
                    action!,
                  ],
                ],
              ),
              SizedBox(height: isMobile ? 18 : 24),

              // ── Page body ──────────────────────────────────────────────────
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
