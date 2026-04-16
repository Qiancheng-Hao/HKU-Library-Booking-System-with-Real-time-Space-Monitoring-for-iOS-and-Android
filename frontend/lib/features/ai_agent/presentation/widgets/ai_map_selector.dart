import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/facility.dart';
import '../../../../core/models/library.dart';
import '../../../../core/ui/widgets/library_map_viewer.dart';
import '../../../../theme/app_theme.dart';
import '../../../library/data/library_repository.dart';

class AiMapSelectorSheet extends StatefulWidget {
  final String? locationHint;
  final List<String> availableRoomNames;
  final String? roomTypeCode;
  final String? roomTypeLabel;
  final Function(List<String>) onConfirm;

  const AiMapSelectorSheet({
    super.key,
    this.locationHint,
    required this.availableRoomNames,
    this.roomTypeCode,
    this.roomTypeLabel,
    required this.onConfirm,
  });

  @override
  State<AiMapSelectorSheet> createState() => _AiMapSelectorSheetState();
}

class _AiMapSelectorSheetState extends State<AiMapSelectorSheet> {
  late final LibraryRepository _libraryRepository;
  final Map<int, Library> _libraryDetailsCache = {};
  List<Facility>? _facilities;
  bool _loading = true;
  String? _error;
  final Set<String> _selectedRooms = {};

  bool _matchesRoom(Facility facility, Iterable<String> targetRooms) {
    return facility.matchesRoom(targetRooms);
  }

  bool _matchesFacilityType(Facility facility) {
    return facility.matchesType(
      code: widget.roomTypeCode,
      label: widget.roomTypeLabel,
    );
  }

  List<Facility> _filterFacilitiesByType(List<Facility> facilities) {
    final typedFacilities = facilities.where(_matchesFacilityType).toList();
    return typedFacilities.isNotEmpty ? typedFacilities : facilities;
  }

  List<Facility> _findMatchedFacilities(List<Facility> facilities) {
    final sourceFacilities = _filterFacilitiesByType(facilities);

    return sourceFacilities
        .where((facility) => _matchesRoom(facility, widget.availableRoomNames))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _libraryRepository = context.read<LibraryRepository>();
    _loadFacilities();
  }

  Future<Library> _getLibraryDetails(int libraryId) async {
    final cached = _libraryDetailsCache[libraryId];
    if (cached != null) return cached;
    final details = await _libraryRepository.getLibraryDetails(libraryId);
    _libraryDetailsCache[libraryId] = details;
    return details;
  }

  Future<Library?> _findHintedLibrary(List<Library> libraries) async {
    final hint = widget.locationHint?.trim().toLowerCase();
    if (hint == null || hint.isEmpty) return null;

    for (final library in libraries) {
      final name = library.name.toLowerCase();
      if (name.contains(hint) || hint.contains(name)) {
        return _getLibraryDetails(library.id);
      }
    }
    return null;
  }

  Future<Library?> _findLibraryByRooms(List<Library> libraries) async {
    if (widget.availableRoomNames.isEmpty) return null;
    final detailsList = await Future.wait(
      libraries.map((library) => _getLibraryDetails(library.id)),
    );
    for (final details in detailsList) {
      if (_findMatchedFacilities(details.facilities).isNotEmpty) {
        return details;
      }
    }
    return null;
  }

  Future<void> _loadFacilities() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final libs = await _libraryRepository.getLibraries();
      var details = await _findHintedLibrary(libs);
      final needsRoomMatch =
          widget.availableRoomNames.isNotEmpty &&
          (details == null ||
              _findMatchedFacilities(details.facilities).isEmpty);
      if (needsRoomMatch) {
        details = await _findLibraryByRooms(libs) ?? details;
      }

      if (mounted) {
        setState(() {
          final facilities = _filterFacilitiesByType(
            details?.facilities ?? const [],
          );
          _facilities = facilities;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _toggleRoom(String label) {
    setState(() {
      if (_selectedRooms.contains(label)) {
        _selectedRooms.remove(label);
      } else {
        _selectedRooms.clear();
        _selectedRooms.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.map_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Room',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.availableRoomNames.length} available · tap to select one',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // Map
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load map',
                          style: TextStyle(color: cs.error),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _loadFacilities,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : (_facilities == null || _facilities!.isEmpty)
                ? Center(
                    child: Text(
                      'No map data available',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : LibraryMapViewer(
                    facilities: _facilities!,
                    availableFacilityNames: Set<String>.from(
                      widget.availableRoomNames,
                    ),
                    selectedFacilityNames: Set<String>.from(_selectedRooms),
                    onFacilityNameTap: _toggleRoom,
                  ),
          ),

          // Legend + Confirm bar
          if (!_loading && _error == null) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _LegendItem(
                          color: cs.primary.withValues(alpha: 0.75),
                          label: 'Available',
                        ),
                        _LegendItem(
                          color: cs.onSurface.withValues(alpha: 0.15),
                          label: 'Unavailable',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Confirm button
                  FilledButton.icon(
                    onPressed: _selectedRooms.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onConfirm(_selectedRooms.toList());
                          },
                    icon: const Icon(Icons.send, size: 16),
                    label: Text(
                      _selectedRooms.isEmpty ? 'Select a room' : 'Send',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _selectedRooms.isEmpty
                          ? cs.surfaceContainerHigh
                          : cs.primary,
                      foregroundColor: _selectedRooms.isEmpty
                          ? cs.onSurfaceVariant
                          : cs.onPrimary,
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
