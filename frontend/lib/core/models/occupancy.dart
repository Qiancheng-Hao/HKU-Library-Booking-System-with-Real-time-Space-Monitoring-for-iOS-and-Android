import 'json_helpers.dart';

class LibraryOccupancy {
  final int? libraryId;
  final String libraryName;
  final String area;
  final double occupancyRate;
  final double? distanceFromUser;

  const LibraryOccupancy({
    this.libraryId,
    required this.libraryName,
    required this.area,
    required this.occupancyRate,
    this.distanceFromUser,
  });

  factory LibraryOccupancy.fromJson(JsonMap json) {
    final distance = json['distanceFromUser'] ?? json['distance_from_user'];
    return LibraryOccupancy(
      libraryId:
          readNullableInt(json, 'libraryId') ??
          readNullableInt(json, 'library_id'),
      libraryName: readFirstString(json, const [
        'libraryName',
        'library_name',
        'name',
      ], fallback: 'Unknown'),
      area: readString(json, 'area'),
      occupancyRate: readFirstDouble(json, const [
        'occupancyRate',
        'occupancy_rate',
      ]),
      distanceFromUser: distance == null
          ? null
          : double.tryParse(distance.toString()),
    );
  }

  String get displayLibraryName {
    if (libraryName == 'Chi Wah Learning Commons') {
      return 'Chi Wah Learning\nCommons';
    }
    return libraryName;
  }

  double get clampedOccupancyRate => occupancyRate.clamp(0.0, 100.0);
}

class OccupancySnapshot {
  final List<LibraryOccupancy> libraries;

  const OccupancySnapshot({required this.libraries});

  factory OccupancySnapshot.fromJson(JsonMap json) {
    return OccupancySnapshot(
      libraries: asJsonMapList(
        json['libraries'],
      ).map(LibraryOccupancy.fromJson).toList(),
    );
  }
}
