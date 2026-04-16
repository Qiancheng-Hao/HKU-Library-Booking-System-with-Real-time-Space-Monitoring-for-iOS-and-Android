import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'section_label.dart';

class SettingsSection extends StatelessWidget {
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.xs,
  );

  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionLabel(title), ...children],
    );
  }
}
