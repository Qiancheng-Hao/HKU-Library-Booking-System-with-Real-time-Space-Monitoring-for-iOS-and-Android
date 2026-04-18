import 'package:flutter/material.dart';
import '../../../../core/models/ai_models.dart';
import '../../../../theme/app_theme.dart';

class ConfirmationCard extends StatelessWidget {
  final AiBookingPreview preview;
  final VoidCallback onChangeRoom;
  final VoidCallback onChangeTime;
  final VoidCallback onCancel;
  final void Function(List<String>) onConfirm;

  const ConfirmationCard({
    super.key,
    required this.preview,
    required this.onChangeRoom,
    required this.onChangeTime,
    required this.onCancel,
    required this.onConfirm,
  });

  Widget _previewRow(BuildContext context, IconData icon, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: tt.bodySmall)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final library = preview.library;
    final date = preview.date;
    final timeRanges = preview.timeRanges;
    final candidateRooms = preview.candidateRooms;
    final libraryFacilityLabel = candidateRooms.isNotEmpty
        ? '$library - ${candidateRooms.join(', ')}'
        : library;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Booking Preview',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _previewRow(context, Icons.local_library, libraryFacilityLabel),
          _previewRow(context, Icons.calendar_today, date),
          if (timeRanges.isNotEmpty)
            _previewRow(context, Icons.access_time, timeRanges.join(', ')),
          if (candidateRooms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Booking facility:',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: candidateRooms
                  .map(
                    (room) => Chip(
                      label: Text(
                        room,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onChangeRoom,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Change Room'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: onChangeTime,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Change Time'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onConfirm(candidateRooms),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Confirm'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
