import 'package:flutter/material.dart';

import '../../../../core/models/library.dart';
import '../../../../theme/app_theme.dart';

class ReportFilterBar extends StatelessWidget {
  final List<Library> libraries;
  final String? selectedLocation;
  final bool isLoading;
  final ValueChanged<String> onLocationChanged;

  const ReportFilterBar({
    super.key,
    required this.libraries,
    required this.selectedLocation,
    required this.isLoading,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedLocation,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Library',
          prefixIcon: Icon(Icons.local_library_outlined),
        ),
        items: libraries
            .map(
              (library) => DropdownMenuItem<String>(
                value: library.name,
                child: Text(library.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: isLoading
            ? null
            : (value) {
                if (value != null) onLocationChanged(value);
              },
      ),
    );
  }
}
