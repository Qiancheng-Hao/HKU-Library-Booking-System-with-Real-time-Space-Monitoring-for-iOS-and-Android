import 'facility.dart';
import 'json_helpers.dart';

class Library {
  final int id;
  final String name;
  final String campus;
  final List<Facility> facilities;

  const Library({
    required this.id,
    required this.name,
    required this.campus,
    this.facilities = const [],
  });

  factory Library.fromJson(JsonMap json) {
    return Library(
      id: readInt(json, 'id'),
      name: readString(json, 'name', fallback: 'Unknown Library'),
      campus: readString(json, 'campus', fallback: 'HKU Campus'),
      facilities: asJsonMapList(
        json['facilities'],
      ).map(Facility.fromJson).toList(),
    );
  }

  Library copyWith({List<Facility>? facilities}) {
    return Library(
      id: id,
      name: name,
      campus: campus,
      facilities: facilities ?? this.facilities,
    );
  }
}
