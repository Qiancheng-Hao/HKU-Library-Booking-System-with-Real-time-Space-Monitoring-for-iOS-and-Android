import 'package:flutter/material.dart';
import '../../../../core/models/reservation.dart';
import '../../../../theme/app_theme.dart';

class ReservationCard extends StatelessWidget {
  final Reservation res;
  final Future<void> Function(Reservation) onViewMap;
  final Future<void> Function(String) onCancel;

  const ReservationCard({
    super.key,
    required this.res,
    required this.onViewMap,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final facility = res.facility;
    final status = res.status;
    final isUpcoming = res.isUpcoming;

    final Color statusColor;
    if (status == ReservationStatus.confirmed) {
      statusColor = AppColors.statusAvailable;
    } else if (status == ReservationStatus.pending) {
      statusColor = AppColors.statusModerate;
    } else {
      statusColor = cs.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Card(
        child: InkWell(
          onTap: isUpcoming ? () => onViewMap(res) : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.event_note,
                  color: isUpcoming ? cs.primary : cs.onSurfaceVariant,
                ),
                title: Text(
                  facility?.name ?? 'Unknown Facility',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (facility?.libraryName != null)
                      Text(
                        facility!.libraryName!,
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${res.reservationDate} | ${res.shortStartTime} - ${res.shortEndTime}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          res.statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (isUpcoming) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.map, size: 14, color: cs.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'View Map',
                            style: TextStyle(color: cs.secondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (status == ReservationStatus.confirmed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Center(
                    child: TextButton(
                      onPressed: () => onCancel(res.id),
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                      child: const Text('Cancel Reservation'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
