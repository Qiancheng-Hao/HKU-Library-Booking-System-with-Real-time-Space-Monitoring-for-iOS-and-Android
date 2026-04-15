import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'library_map_viewer.dart';

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
  List<dynamic>? _facilities;
  bool _loading = true;
  String? _error;
  final Set<String> _selectedRooms = {};

  String _markerLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).last;
  }

  bool _matchesRoom(dynamic facility, Iterable<String> targetRooms) {
    final facilityName = (facility['name'] as String? ?? '').trim();
    final facilityNameLower = facilityName.toLowerCase();
    final facilityRoomNo = (facility['room_no'] as String? ?? '').trim();
    final facilityRoomNoLower = facilityRoomNo.toLowerCase();
    final facilityLastToken = _markerLabel(facilityName).toLowerCase();

    for (final room in targetRooms) {
      final normalizedRoom = room.trim().toLowerCase();
      if (normalizedRoom.isEmpty) continue;
      if (normalizedRoom == facilityNameLower ||
          normalizedRoom == facilityRoomNoLower ||
          normalizedRoom == facilityLastToken) {
        return true;
      }
    }
    return false;
  }

  bool _matchesFacilityType(dynamic facility) {
    final facilityTypeCode = (facility['facility_type_code'] as String? ?? '')
        .trim()
        .toLowerCase();
    final facilityType = (facility['type'] as String? ?? '')
        .trim()
        .toLowerCase();
    final targetTypeCode = (widget.roomTypeCode ?? '').trim().toLowerCase();
    final targetTypeLabel = (widget.roomTypeLabel ?? '').trim().toLowerCase();

    if (targetTypeCode.isEmpty && targetTypeLabel.isEmpty) return true;
    if (targetTypeCode.isNotEmpty && facilityTypeCode == targetTypeCode) {
      return true;
    }
    if (targetTypeLabel.isNotEmpty &&
        (facilityType == targetTypeLabel ||
            facilityType.contains(targetTypeLabel) ||
            targetTypeLabel.contains(facilityType))) {
      return true;
    }
    return false;
  }

  List<dynamic> _filterFacilitiesByType(List<dynamic> facilities) {
    final typedFacilities = facilities.where(_matchesFacilityType).toList();
    return typedFacilities.isNotEmpty ? typedFacilities : facilities;
  }

  List<dynamic> _findMatchedFacilities(List<dynamic> facilities) {
    final sourceFacilities = _filterFacilitiesByType(facilities);

    return sourceFacilities
        .where((facility) => _matchesRoom(facility, widget.availableRoomNames))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final libs = await ApiService.getLibraries();
      Map<String, dynamic>? details;
      List<dynamic> matchedFacilities = const [];

      if (widget.locationHint != null && widget.locationHint!.isNotEmpty) {
        final hint = widget.locationHint!.toLowerCase();
        final match = libs.firstWhere(
          (l) =>
              (l['name'] as String? ?? '').toLowerCase().contains(hint) ||
              hint.contains((l['name'] as String? ?? '').toLowerCase()),
          orElse: () => null,
        );
        if (match != null) {
          details = await ApiService.getLibraryDetails(match['id'] as int);
          matchedFacilities = _findMatchedFacilities(
            details['facilities'] as List<dynamic>? ?? const [],
          );
        }
      }

      if ((details == null || matchedFacilities.isEmpty) &&
          widget.availableRoomNames.isNotEmpty) {
        for (final lib in libs) {
          final d = await ApiService.getLibraryDetails(lib['id'] as int);
          final facilities = d['facilities'] as List<dynamic>? ?? [];
          final matched = _findMatchedFacilities(facilities);
          if (matched.isNotEmpty) {
            details = d;
            matchedFacilities = matched;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          final facilities = _filterFacilitiesByType(
            details?['facilities'] as List<dynamic>? ?? const [],
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
