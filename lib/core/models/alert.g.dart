// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlertsResponse _$AlertsResponseFromJson(Map<String, dynamic> json) =>
    AlertsResponse(
      alerts: (json['alerts'] as List<dynamic>)
          .map((e) => Alert.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AlertsResponseToJson(AlertsResponse instance) =>
    <String, dynamic>{
      'alerts': instance.alerts.map((e) => e.toJson()).toList(),
    };

Alert _$AlertFromJson(Map<String, dynamic> json) => Alert(
  id: json['id'] as String,
  level: (json['level'] as num).toInt(),
  title: json['title'] as String,
  area: json['area'] as String,
  validFrom: const OffsetDateTimeConverter().fromJson(
    json['validFrom'] as String,
  ),
  validTo: const OffsetDateTimeConverter().fromJson(json['validTo'] as String),
  source: json['source'] as String,
  recommendations:
      (json['recommendations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  officialUrl: json['officialUrl'] as String?,
);

Map<String, dynamic> _$AlertToJson(Alert instance) => <String, dynamic>{
  'id': instance.id,
  'level': instance.level,
  'title': instance.title,
  'area': instance.area,
  'validFrom': const OffsetDateTimeConverter().toJson(instance.validFrom),
  'validTo': const OffsetDateTimeConverter().toJson(instance.validTo),
  'source': instance.source,
  'recommendations': instance.recommendations,
  'officialUrl': ?instance.officialUrl,
};
