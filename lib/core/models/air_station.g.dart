// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'air_station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AirResponse _$AirResponseFromJson(Map<String, dynamic> json) => AirResponse(
  stations: (json['stations'] as List<dynamic>)
      .map((e) => AirStation.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AirResponseToJson(AirResponse instance) =>
    <String, dynamic>{
      'stations': instance.stations.map((e) => e.toJson()).toList(),
    };

AirStation _$AirStationFromJson(Map<String, dynamic> json) => AirStation(
  id: json['id'] as String,
  name: json['name'] as String,
  lat: (json['lat'] as num).toDouble(),
  lon: (json['lon'] as num).toDouble(),
  indexLevel: (json['indexLevel'] as num?)?.toInt(),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const OffsetDateTimeConverter().fromJson,
  ),
);

Map<String, dynamic> _$AirStationToJson(AirStation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'lat': instance.lat,
      'lon': instance.lon,
      'indexLevel': ?instance.indexLevel,
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const OffsetDateTimeConverter().toJson,
      ),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
