import 'package:json_annotation/json_annotation.dart';

import 'date_time_converter.dart';
import 'geo.dart';

part 'route_request.g.dart';

/// Comfort profile ids from S04.
enum ProfileId {
  senior,
  tourist,
  @JsonValue('default')
  standard,
}

/// Route preference weights, each 0..100.
@JsonSerializable()
class ProfileWeights {
  const ProfileWeights({
    required this.shade,
    required this.time,
    required this.quiet,
    required this.air,
  });

  factory ProfileWeights.fromJson(Map<String, dynamic> json) =>
      _$ProfileWeightsFromJson(json);

  final int shade;
  final int time;
  final int quiet;
  final int air;

  Map<String, dynamic> toJson() => _$ProfileWeightsToJson(this);
}

@JsonSerializable()
class RouteProfile {
  const RouteProfile({required this.id, required this.weights});

  factory RouteProfile.fromJson(Map<String, dynamic> json) =>
      _$RouteProfileFromJson(json);

  final ProfileId id;
  final ProfileWeights weights;

  Map<String, dynamic> toJson() => _$RouteProfileToJson(this);
}

/// Body of `POST /v1/routes`.
@JsonSerializable()
class RouteRequest {
  const RouteRequest({
    required this.from,
    required this.to,
    required this.datetime,
    required this.profile,
    this.filters = const {},
  });

  factory RouteRequest.fromJson(Map<String, dynamic> json) =>
      _$RouteRequestFromJson(json);

  final RoutePoint from;
  final RoutePoint to;

  /// Departure in local (Europe/Warsaw) time; sent with its UTC offset.
  @OffsetDateTimeConverter()
  final DateTime datetime;

  final RouteProfile profile;

  /// Reserved by module D, may be empty.
  final Map<String, dynamic> filters;

  Map<String, dynamic> toJson() => _$RouteRequestToJson(this);
}
