import 'json_helpers.dart';

abstract interface class AiMessageData {
  bool get readyForConfirmation;
  AiSuggestedOptions? get suggestedOptions;
  AiBookingPreview? get bookingPreview;
}

class AiChatResponse implements AiMessageData {
  final String reply;
  @override
  final bool readyForConfirmation;
  @override
  final AiBookingPreview? bookingPreview;
  @override
  final AiSuggestedOptions? suggestedOptions;
  final AiCollectedInfo? collectedInfo;
  final List<String> warnings;

  const AiChatResponse({
    required this.reply,
    required this.readyForConfirmation,
    this.bookingPreview,
    this.suggestedOptions,
    this.collectedInfo,
    this.warnings = const [],
  });

  factory AiChatResponse.fromJson(JsonMap json) {
    final previewJson = asJsonMap(json['bookingPreview']);
    final optionsJson = asJsonMap(json['suggestedOptions']);
    final collectedJson = asJsonMap(json['collectedInfo']);
    return AiChatResponse(
      reply: readString(json, 'reply'),
      readyForConfirmation: readBool(json, 'readyForConfirmation'),
      bookingPreview: previewJson.isEmpty
          ? null
          : AiBookingPreview.fromJson(previewJson),
      suggestedOptions: optionsJson.isEmpty
          ? null
          : AiSuggestedOptions.fromJson(optionsJson),
      collectedInfo: collectedJson.isEmpty
          ? null
          : AiCollectedInfo.fromJson(collectedJson),
      warnings: asStringList(json['warnings']),
    );
  }
}

class AiBookingResult implements AiMessageData {
  final String summary;
  final bool success;
  final List<AiFailedReservation> failedReservations;

  const AiBookingResult({
    required this.summary,
    required this.success,
    this.failedReservations = const [],
  });

  factory AiBookingResult.fromJson(JsonMap json) {
    return AiBookingResult(
      summary: readString(json, 'summary', fallback: 'Booking processed.'),
      success: readBool(json, 'success'),
      failedReservations: asJsonMapList(
        json['failedReservations'],
      ).map(AiFailedReservation.fromJson).toList(),
    );
  }

  @override
  bool get readyForConfirmation => false;

  @override
  AiSuggestedOptions? get suggestedOptions => null;

  @override
  AiBookingPreview? get bookingPreview => null;
}

class AiSuggestedOptions {
  final List<String> locations;
  final List<String> roomTypes;
  final List<String> rooms;

  const AiSuggestedOptions({
    this.locations = const [],
    this.roomTypes = const [],
    this.rooms = const [],
  });

  factory AiSuggestedOptions.fromJson(JsonMap json) {
    return AiSuggestedOptions(
      locations: asStringList(json['locations']),
      roomTypes: asStringList(json['room_types']),
      rooms: asStringList(json['rooms']),
    );
  }
}

class AiCollectedInfo {
  final String? roomTypeCode;
  final String? roomType;

  const AiCollectedInfo({this.roomTypeCode, this.roomType});

  factory AiCollectedInfo.fromJson(JsonMap json) {
    return AiCollectedInfo(
      roomTypeCode: json['room_type_code']?.toString(),
      roomType: json['room_type']?.toString(),
    );
  }
}

class AiBookingPreview {
  final String library;
  final String date;
  final List<String> timeRanges;
  final List<String> candidateRooms;

  const AiBookingPreview({
    required this.library,
    required this.date,
    this.timeRanges = const [],
    this.candidateRooms = const [],
  });

  factory AiBookingPreview.fromJson(JsonMap json) {
    return AiBookingPreview(
      library: readString(json, 'library', fallback: 'N/A'),
      date: readString(json, 'date', fallback: 'N/A'),
      timeRanges: asStringList(json['time_ranges']),
      candidateRooms: asStringList(json['candidate_rooms']),
    );
  }
}

class AiFailedReservation {
  final String session;
  final String room;
  final String reason;

  const AiFailedReservation({
    required this.session,
    required this.room,
    required this.reason,
  });

  factory AiFailedReservation.fromJson(JsonMap json) {
    return AiFailedReservation(
      session: readString(json, 'session'),
      room: readString(json, 'room'),
      reason: readString(json, 'reason'),
    );
  }
}
