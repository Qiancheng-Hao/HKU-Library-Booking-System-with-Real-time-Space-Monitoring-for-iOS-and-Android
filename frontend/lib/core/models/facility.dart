import 'json_helpers.dart';

class Facility {
  final int id;
  final String name;
  final String type;
  final int? libraryId;
  final String? libraryName;
  final int floor;
  final String? roomNo;
  final String? facilityTypeCode;
  final double xCoordinate;
  final double yCoordinate;
  final double width;
  final double height;

  const Facility({
    required this.id,
    required this.name,
    required this.type,
    this.libraryId,
    this.libraryName,
    required this.floor,
    this.roomNo,
    this.facilityTypeCode,
    required this.xCoordinate,
    required this.yCoordinate,
    required this.width,
    required this.height,
  });

  factory Facility.fromJson(JsonMap json) {
    return Facility(
      id: readInt(json, 'id'),
      name: readString(json, 'name', fallback: 'Unknown facility'),
      type: readString(json, 'type', fallback: 'Other'),
      libraryId: readNullableInt(json, 'library_id'),
      libraryName: json['library_name']?.toString(),
      floor: readInt(json, 'floor', fallback: 1),
      roomNo: json['room_no']?.toString(),
      facilityTypeCode: json['facility_type_code']?.toString(),
      xCoordinate: readFirstDouble(json, const ['x_coordinate', 'xCoordinate']),
      yCoordinate: readFirstDouble(json, const ['y_coordinate', 'yCoordinate']),
      width: readDouble(json, 'width'),
      height: readDouble(json, 'height'),
    );
  }

  String get markerLabel {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).last;
  }

  bool matchesRoom(Iterable<String> targetRooms) {
    final facilityNameLower = name.trim().toLowerCase();
    final roomNoLower = (roomNo ?? '').trim().toLowerCase();
    final lastToken = markerLabel.toLowerCase();

    for (final room in targetRooms) {
      final normalizedRoom = room.trim().toLowerCase();
      if (normalizedRoom.isEmpty) continue;
      if (normalizedRoom == facilityNameLower ||
          normalizedRoom == roomNoLower ||
          normalizedRoom == lastToken) {
        return true;
      }
    }
    return false;
  }

  bool matchesType({String? code, String? label}) {
    final facilityCode = (facilityTypeCode ?? '').trim().toLowerCase();
    final facilityType = type.trim().toLowerCase();
    final targetCode = (code ?? '').trim().toLowerCase();
    final targetLabel = (label ?? '').trim().toLowerCase();

    if (targetCode.isEmpty && targetLabel.isEmpty) return true;
    if (targetCode.isNotEmpty && facilityCode == targetCode) return true;
    return targetLabel.isNotEmpty &&
        (facilityType == targetLabel ||
            facilityType.contains(targetLabel) ||
            targetLabel.contains(facilityType));
  }
}
