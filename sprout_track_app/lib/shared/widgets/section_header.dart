import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.trailing,
    super.key,
  });

  final String  title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final titleWidget = Text(
      title,
      maxLines: isMobile ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isMobile ? 16 : null,
          ),
    );

    if (isMobile && trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: trailing!),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleWidget),
        if (trailing != null) trailing!,
      ],
    );
  }
}
