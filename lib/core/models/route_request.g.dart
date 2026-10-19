// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileWeights _$ProfileWeightsFromJson(Map<String, dynamic> json) =>
    ProfileWeights(
      shade: (json['shade'] as num).toInt(),
      time: (json['time'] as num).toInt(),
      quiet: (json['quiet'] as num).toInt(),
      air: (json['air'] as num).toInt(),
    );

Map<String, dynamic> _$ProfileWeightsToJson(ProfileWeights instance) =>
    <String, dynamic>{
      'shade': instance.shade,
      'time': instance.time,
      'quiet': instance.quiet,
      'air': instance.air,
    };

RouteProfile _$RouteProfileFromJson(Map<String, dynamic> json) => RouteProfile(
  id: $enumDecode(_$ProfileIdEnumMap, json['id']),
  weights: ProfileWeights.fromJson(json['weights'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RouteProfileToJson(RouteProfile instance) =>
    <String, dynamic>{
      'id': _$ProfileIdEnumMap[instance.id]!,
      'weights': instance.weights.toJson(),
    };

const _$ProfileIdEnumMap = {
  ProfileId.senior: 'senior',
  ProfileId.tourist: 'tourist',
  ProfileId.standard: 'default',
};

RouteRequest _$RouteRequestFromJson(Map<String, dynamic> json) => RouteRequest(
  from: RoutePoint.fromJson(json['from'] as Map<String, dynamic>),
  to: RoutePoint.fromJson(json['to'] as Map<String, dynamic>),
  datetime: const OffsetDateTimeConverter().fromJson(
    json['datetime'] as String,
  ),
  profile: RouteProfile.fromJson(json['profile'] as Map<String, dynamic>),
  filters: json['filters'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$RouteRequestToJson(RouteRequest instance) =>
    <String, dynamic>{
      'from': instance.from.toJson(),
      'to': instance.to.toJson(),
      'datetime': const OffsetDateTimeConverter().toJson(instance.datetime),
      'profile': instance.profile.toJson(),
      'filters': instance.filters,
    };
