import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/facility.dart';
import '../../../../core/models/library.dart';
import '../../../../core/ui/widgets/library_map_viewer.dart';
import '../../../../theme/app_theme.dart';
import '../../data/library_repository.dart';
import '../controllers/library_details_controller.dart';
import '../screens/facility_booking_screen.dart';

class LibraryListItem extends StatefulWidget {
  final Library library;
  const LibraryListItem({super.key, required this.library});

  @override
  State<LibraryListItem> createState() => _LibraryListItemState();
}

class _LibraryListItemState extends State<LibraryListItem> {
  bool _isExpanded = false;
  late final LibraryDetailsController _detailsController;

  @override
  void initState() {
    super.initState();
    _detailsController = LibraryDetailsController(
      libraryRepository: context.read<LibraryRepository>(),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _detailsController.load(widget.library.id);
      }
    });
  }

  IconData _getFacilityIcon(String? type) {
    return switch (type?.toLowerCase()) {
      'discussion room' || 'study room' => Icons.groups,
      'study table' => Icons.table_restaurant,
      'computer' => Icons.computer,
      _ => Icons.chair,
    };
  }

  void _showFacilitySelectionDialog(
    BuildContext context,
    String type,
    List<Facility> items,
  ) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      type,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            SizedBox(
              height: 400,
              child: LibraryMapViewer(
                facilities: items,
                onFacilityTap: (item) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FacilityBookingScreen(
                        facilityId: item.id,
                        facilityName: item.name,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Tap a facility to book.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: _isExpanded
              ? BorderSide(color: cs.primary, width: 1.5)
              : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.local_library, color: cs.primary, size: 32),
              title: Text(
                widget.library.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(widget.library.campus),
              trailing: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: _isExpanded ? cs.primary : cs.onSurfaceVariant,
              ),
              onTap: _toggleExpand,
            ),
            if (_isExpanded)
              ChangeNotifierProvider<LibraryDetailsController>.value(
                value: _detailsController,
                child: Consumer<LibraryDetailsController>(
                  builder: (context, controller, _) {
                    if (controller.isLoading && controller.library == null) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (controller.hasError &&
                        controller.library == null) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: cs.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Failed to load: ${controller.errorMessage}',
                                style: TextStyle(color: cs.error),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  controller.retry(widget.library.id),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    } else if (controller.library == null) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('No details available.'),
                      );
                    }

                    final library = controller.library!;
                    final facilities = library.facilities;

                    final Map<String, List<Facility>> grouped = {};
                    for (var f in facilities) {
                      final type = f.type.isEmpty ? 'Other' : f.type;
                      grouped.putIfAbsent(type, () => []).add(f);
                    }
                    final groupKeys = grouped.keys.toList()..sort();

                    if (groupKeys.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('No facilities available.'),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupKeys.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final type = groupKeys[index];
                        final items = grouped[type]!;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xs,
                          ),
                          leading: Icon(
                            _getFacilityIcon(type),
                            color: cs.secondary,
                            size: 24,
                          ),
                          title: Text(type),
                          trailing: Chip(
                            label: Text(
                              '${items.length}',
                              style: TextStyle(
                                color: cs.onSecondaryContainer,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: cs.secondaryContainer,
                            side: BorderSide.none,
                          ),
                          onTap: () => _showFacilitySelectionDialog(
                            context,
                            type,
                            items,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
