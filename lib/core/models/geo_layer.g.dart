// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_layer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeoLayer _$GeoLayerFromJson(Map<String, dynamic> json) => GeoLayer(
  type: json['type'] as String? ?? 'FeatureCollection',
  features: (json['features'] as List<dynamic>)
      .map((e) => GeoFeature.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$GeoLayerToJson(GeoLayer instance) => <String, dynamic>{
  'type': instance.type,
  'features': instance.features.map((e) => e.toJson()).toList(),
};

GeoFeature _$GeoFeatureFromJson(Map<String, dynamic> json) => GeoFeature(
  type: json['type'] as String? ?? 'Feature',
  id: json['id'],
  geometry: GeoPolygons.fromJson(json['geometry'] as Map<String, dynamic>),
  properties: json['properties'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$GeoFeatureToJson(GeoFeature instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': ?instance.id,
      'geometry': instance.geometry.toJson(),
      'properties': instance.properties,
    };
