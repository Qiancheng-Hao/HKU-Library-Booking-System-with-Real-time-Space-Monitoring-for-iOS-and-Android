import 'json_helpers.dart';

enum TimeSlotStatus {
  available('available'),
  unavailable('unavailable'),
  booked('booked'),
  unknown('unknown');

  const TimeSlotStatus(this.value);

  final String value;

  static TimeSlotStatus parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'available' => TimeSlotStatus.available,
      'unavailable' => TimeSlotStatus.unavailable,
      'booked' || 'reserved' => TimeSlotStatus.booked,
      _ => TimeSlotStatus.unknown,
    };
  }
}

class TimeSlot {
  final String startTime;
  final String endTime;
  final TimeSlotStatus status;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory TimeSlot.fromJson(JsonMap json) {
    return TimeSlot(
      startTime: readFirstString(json, const [
        'start_time',
        'startTime',
        'start',
      ]),
      endTime: readFirstString(json, const ['end_time', 'endTime', 'end']),
      status: TimeSlotStatus.parse(json['status']),
    );
  }

  bool get isAvailable => status == TimeSlotStatus.available;

  String get statusText => status.value;

  String get shortStartTime => _shortTime(startTime);
  String get shortEndTime => _shortTime(endTime);

  static String _shortTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }
}
