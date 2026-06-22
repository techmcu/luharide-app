/// A location chosen by the user — its display name plus optional coordinates.
///
/// Coordinates are nullable on purpose: a user may type a place that has no
/// Ola Maps match (offline / unknown), in which case the app still works in
/// text-only mode (no distance/fare/proximity for that ride). Backward
/// compatible with the old String-only flow via [name].
class PickedLocation {
  final String name;
  final double? lat;
  final double? lng;

  const PickedLocation({required this.name, this.lat, this.lng});

  /// Whether this location carries usable coordinates.
  bool get hasCoords => lat != null && lng != null;

  /// Build from the backend `places` entry: {description, lat, lng}.
  factory PickedLocation.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    return PickedLocation(
      name: (json['description'] ?? json['name'] ?? '').toString(),
      lat: toD(json['lat']),
      lng: toD(json['lng']),
    );
  }

  /// A name-only location (no coordinates) — for the legacy text path.
  factory PickedLocation.nameOnly(String name) => PickedLocation(name: name);

  @override
  String toString() => name;
}
