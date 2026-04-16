import 'package:flutter/material.dart';
import 'settings_section.dart';

class AppearanceSection extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onChanged;

  const AppearanceSection({
    super.key,
    required this.themeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Appearance',
      children: [
        Padding(
          padding: SettingsSection.contentPadding,
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.contrast_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ),
      ],
    );
  }
}
