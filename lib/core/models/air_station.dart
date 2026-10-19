import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'date_time_converter.dart';

part 'air_station.g.dart';

@JsonSerializable()
class AirResponse {
  const AirResponse({required this.stations});

  factory AirResponse.fromJson(Map<String, dynamic> json) =>
      _$AirResponseFromJson(json);

  final List<AirStation> stations;

  Map<String, dynamic> toJson() => _$AirResponseToJson(this);
}

/// GIOŚ air quality station.
@JsonSerializable()
class AirStation {
  const AirStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.indexLevel,
    this.updatedAt,
  });

  factory AirStation.fromJson(Map<String, dynamic> json) =>
      _$AirStationFromJson(json);

  static const bestIndex = 0; // bardzo dobry
  static const worstIndex = 5; // bardzo zły

  final String id;
  final String name;
  final double lat;
  final double lon;

  /// GIOŚ index 0 (bardzo dobry) … 5 (bardzo zły); null = no data.
  final int? indexLevel;

  @OffsetDateTimeConverter()
  final DateTime? updatedAt;

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => _$AirStationToJson(this);
}
