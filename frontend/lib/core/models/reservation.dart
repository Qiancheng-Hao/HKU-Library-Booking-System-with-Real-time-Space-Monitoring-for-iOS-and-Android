import 'facility.dart';
import 'json_helpers.dart';

enum ReservationStatus {
  confirmed('confirmed'),
  pending('pending'),
  finished('finished'),
  claimed('claimed'),
  unclaimed('unclaimed'),
  cancelled('cancelled'),
  unknown('unknown');

  const ReservationStatus(this.value);

  final String value;

  static ReservationStatus parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'confirmed' => ReservationStatus.confirmed,
      'pending' => ReservationStatus.pending,
      'finished' => ReservationStatus.finished,
      'claimed' => ReservationStatus.claimed,
      'unclaimed' => ReservationStatus.unclaimed,
      'cancelled' || 'canceled' => ReservationStatus.cancelled,
      _ => ReservationStatus.unknown,
    };
  }
}

class Reservation {
  final String id;
  final String reservationDate;
  final String startTime;
  final String endTime;
  final ReservationStatus status;
  final Facility? facility;

  const Reservation({
    required this.id,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.facility,
  });

  factory Reservation.fromJson(JsonMap json) {
    final facilityJson = asJsonMap(json['facility']);
    return Reservation(
      id: readString(json, 'id'),
      reservationDate: readFirstString(json, const [
        'reservation_date',
        'reservationDate',
        'date',
      ]),
      startTime: readFirstString(json, const ['start_time', 'startTime']),
      endTime: readFirstString(json, const ['end_time', 'endTime']),
      status: ReservationStatus.parse(json['status']),
      facility: facilityJson.isEmpty ? null : Facility.fromJson(facilityJson),
    );
  }

  bool get isUpcoming =>
      status == ReservationStatus.confirmed ||
      status == ReservationStatus.pending;

  String get statusText => status.value;

  DateTime? get maybeStartDateTime {
    if (reservationDate.isEmpty) return null;
    final time = startTime.isEmpty ? '00:00:00' : startTime;
    return DateTime.tryParse('${reservationDate}T$time');
  }

  String get shortStartTime => _shortTime(startTime);
  String get shortEndTime => _shortTime(endTime);

  static String _shortTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }
}
