import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'opening_hours.dart';

part 'place.g.dart';

enum PlaceType { cool, water, bench }

/// Category of a cool place.
enum PlaceCategory {
  library,
  museum,
  culture,
  mall,
  park,
  station,
  church,
  other,
}

enum Amenity { airConditioning, water, toilet, wheelchair }

@JsonSerializable()
class PlacesResponse {
  const PlacesResponse({required this.places});

  factory PlacesResponse.fromJson(Map<String, dynamic> json) =>
      _$PlacesResponseFromJson(json);

  final List<Place> places;

  Map<String, dynamic> toJson() => _$PlacesResponseToJson(this);
}

/// A cool place, water point or bench. Water points and benches only carry
/// `id`, `type`, `lat`, `lon`.
@JsonSerializable()
class Place {
  const Place({
    required this.id,
    required this.type,
    this.name,
    this.category,
    this.address,
    required this.lat,
    required this.lon,
    this.hours,
    this.amenities = const [],
    this.accessible,
    this.questPlace = false,
    this.source,
  });

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);

  final String id;
  final PlaceType type;
  final String? name;

  @JsonKey(unknownEnumValue: PlaceCategory.other)
  final PlaceCategory? category;

  final String? address;
  final double lat;
  final double lon;

  /// Null = always open.
  final OpeningHours? hours;

  /// Unknown values from the server are skipped.
  @JsonKey(fromJson: _amenitiesFromJson)
  final List<Amenity> amenities;

  final bool? accessible;

  @JsonKey(defaultValue: false)
  final bool questPlace;

  /// Where the opening hours come from (URL).
  final String? source;

  LatLng get latLng => LatLng(lat, lon);

  bool get isAlwaysOpen => hours == null;

  bool isOpenAt(DateTime local) => hours?.isOpenAt(local) ?? true;

  /// Null when open at [local], always open, or never opens.
  DateTime? nextOpening(DateTime local) => hours?.nextOpening(local);

  bool has(Amenity amenity) => amenities.contains(amenity);

  Map<String, dynamic> toJson() => _$PlaceToJson(this);
}

List<Amenity> _amenitiesFromJson(List<dynamic>? json) => [
  for (final value in json ?? const [])
    ...Amenity.values.where((a) => a.name == value),
];
