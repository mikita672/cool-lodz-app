// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteResponse _$RouteResponseFromJson(Map<String, dynamic> json) =>
    RouteResponse(
      coverage: $enumDecode(_$RouteCoverageEnumMap, json['coverage']),
      variants: (json['variants'] as List<dynamic>)
          .map((e) => RouteVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RouteResponseToJson(RouteResponse instance) =>
    <String, dynamic>{
      'coverage': _$RouteCoverageEnumMap[instance.coverage]!,
      'variants': instance.variants.map((e) => e.toJson()).toList(),
    };

const _$RouteCoverageEnumMap = {
  RouteCoverage.full: 'full',
  RouteCoverage.approximate: 'approximate',
};

RouteSegment _$RouteSegmentFromJson(Map<String, dynamic> json) => RouteSegment(
  from: (json['from'] as num).toInt(),
  to: (json['to'] as num).toInt(),
  sunShare: (json['sunShare'] as num).toDouble(),
);

Map<String, dynamic> _$RouteSegmentToJson(RouteSegment instance) =>
    <String, dynamic>{
      'from': instance.from,
      'to': instance.to,
      'sunShare': instance.sunShare,
    };

RouteStop _$RouteStopFromJson(Map<String, dynamic> json) => RouteStop(
  placeId: json['placeId'] as String,
  type: $enumDecode(_$StopTypeEnumMap, json['type']),
);

Map<String, dynamic> _$RouteStopToJson(RouteStop instance) => <String, dynamic>{
  'placeId': instance.placeId,
  'type': _$StopTypeEnumMap[instance.type]!,
};

const _$StopTypeEnumMap = {StopType.cool: 'cool', StopType.water: 'water'};

RouteVariant _$RouteVariantFromJson(Map<String, dynamic> json) => RouteVariant(
  variant: $enumDecode(_$RouteVariantTypeEnumMap, json['variant']),
  geometry: const LineStringConverter().fromJson(
    json['geometry'] as Map<String, dynamic>,
  ),
  segments:
      (json['segments'] as List<dynamic>?)
          ?.map((e) => RouteSegment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  distanceM: (json['distance_m'] as num).toInt(),
  durationS: (json['duration_s'] as num).toInt(),
  sunShare: (json['sunShare'] as num).toDouble(),
  extraTimeVsShortestS: (json['extraTimeVsShortest_s'] as num).toInt(),
  stops:
      (json['stops'] as List<dynamic>?)
          ?.map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sunShareByHour:
      (json['sunShareByHour'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
);

Map<String, dynamic> _$RouteVariantToJson(RouteVariant instance) =>
    <String, dynamic>{
      'variant': _$RouteVariantTypeEnumMap[instance.variant]!,
      'geometry': const LineStringConverter().toJson(instance.geometry),
      'segments': instance.segments.map((e) => e.toJson()).toList(),
      'distance_m': instance.distanceM,
      'duration_s': instance.durationS,
      'sunShare': instance.sunShare,
      'extraTimeVsShortest_s': instance.extraTimeVsShortestS,
      'stops': instance.stops.map((e) => e.toJson()).toList(),
      'sunShareByHour': instance.sunShareByHour,
    };

const _$RouteVariantTypeEnumMap = {
  RouteVariantType.shortest: 'shortest',
  RouteVariantType.shaded: 'shaded',
  RouteVariantType.compromise: 'compromise',
};
