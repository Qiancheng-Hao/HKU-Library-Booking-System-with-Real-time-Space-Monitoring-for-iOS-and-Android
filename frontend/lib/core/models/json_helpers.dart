typedef JsonMap = Map<String, Object?>;

JsonMap asJsonMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<JsonMap> asJsonMapList(Object? value) {
  if (value is! Iterable) return const [];
  return value.map(asJsonMap).where((item) => item.isNotEmpty).toList();
}

List<String> asStringList(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

String readString(JsonMap json, String key, {String fallback = ''}) {
  final value = json[key];
  if (value == null) return fallback;
  return value.toString();
}

String readFirstString(
  JsonMap json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value.toString();
  }
  return fallback;
}

int readInt(JsonMap json, String key, {int fallback = 0}) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? readNullableInt(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double readDouble(JsonMap json, String key, {double fallback = 0}) {
  final value = json[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double readFirstDouble(JsonMap json, List<String> keys, {double fallback = 0}) {
  for (final key in keys) {
    if (json.containsKey(key)) return readDouble(json, key, fallback: fallback);
  }
  return fallback;
}

double? readFirstNullableDouble(JsonMap json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
  return null;
}

bool readBool(JsonMap json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}
