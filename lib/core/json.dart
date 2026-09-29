/// Small helpers for hand-written `fromJson` constructors. They fail loudly
/// (a [FormatException] naming the field) instead of with a bare cast error.
library;

typedef Json = Map<String, dynamic>;

T _req<T>(Json j, String key) {
  final v = j[key];
  if (v is T) return v;
  throw FormatException('Expected "$key" to be $T, got ${v.runtimeType}');
}

String reqString(Json j, String key) => _req<String>(j, key);

String? optString(Json j, String key) => j[key]?.toString();

int reqInt(Json j, String key) => _req<num>(j, key).toInt();

int? optInt(Json j, String key) {
  final v = j[key];
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  throw FormatException('Expected "$key" to be a number, got ${v.runtimeType}');
}

bool reqBool(Json j, String key) => _req<bool>(j, key);

bool optBool(Json j, String key, {bool fallback = false}) {
  final v = j[key];
  return v is bool ? v : fallback;
}

DateTime? optDate(Json j, String key) {
  final v = j[key];
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
  return null;
}

DateTime reqDate(Json j, String key) {
  final d = optDate(j, key);
  if (d == null) throw FormatException('Expected "$key" to be a date');
  return d;
}

Json optMap(Json j, String key) {
  final v = j[key];
  return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
}

List<String> stringList(Json j, String key) {
  final v = j[key];
  if (v is List) return List.unmodifiable(v.map((e) => e.toString()));
  return const [];
}

List<T> objList<T>(Json j, String key, T Function(Json) parse) {
  final v = j[key];
  if (v is! List) return const [];
  return List.unmodifiable(v.whereType<Map<dynamic, dynamic>>().map((e) => parse(e.cast<String, dynamic>())));
}

/// Deep equality for the simple lists used in models.
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
