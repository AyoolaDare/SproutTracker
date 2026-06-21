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
    final hPad            = isMobile ? 14.0 : (isTablet ? 22.0 : 30.0);
    final scheme          = Theme.of(context).colorScheme;
    final titleStyle      = (isMobile
            ? Theme.of(context).textTheme.headlineSmall
            : Theme.of(context).textTheme.headlineLarge)
        ?.copyWith(fontWeight: FontWeight.w900);
    final subtitleStyle   = (isMobile
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, isMobile ? 12 : 26, hPad, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ────────────────────────────────────────────────
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccentBar(),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: action!),
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AccentBar(),
                          Text(title, style: titleStyle),
                          const SizedBox(height: 6),
                          Text(subtitle, style: subtitleStyle),
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

class _AccentBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 3,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.moss,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
