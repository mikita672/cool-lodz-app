import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/route_request.dart';

part 'comfort_profile.g.dart';

/// The comfort profile from S04, stored as `users/{uid}.profile`
/// ({id, weights, seniorMode}). It is a route preference, not health data.
@immutable
@JsonSerializable()
class ComfortProfile {
  const ComfortProfile({
    required this.id,
    required this.weights,
    required this.seniorMode,
  });

  factory ComfortProfile.fromJson(Map<String, dynamic> json) =>
      _$ComfortProfileFromJson(json);

  /// The preset for [id] with its starting weights. Choosing Senior turns
  /// on Senior mode; the user can change it afterwards.
  factory ComfortProfile.preset(ProfileId id) => ComfortProfile(
    id: id,
    weights: presetWeights[id]!,
    seniorMode: id == ProfileId.senior,
  );

  /// Used until the user picks a profile.
  static final fallback = ComfortProfile.preset(ProfileId.standard);

  /// Starting weights (0..100) for the three working profiles. The spec has
  /// none; the decision is recorded in docs/dev.md («Comfort profiles»).
  static const presetWeights = {
    ProfileId.senior: ProfileWeights(shade: 90, time: 20, quiet: 60, air: 60),
    ProfileId.tourist: ProfileWeights(shade: 70, time: 40, quiet: 30, air: 40),
    ProfileId.standard: ProfileWeights(shade: 60, time: 60, quiet: 30, air: 30),
  };

  final ProfileId id;
  final ProfileWeights weights;
  final bool seniorMode;

  /// What goes into `POST /v1/routes`.
  RouteProfile get routeProfile => RouteProfile(id: id, weights: weights);

  ComfortProfile copyWith({
    ProfileId? id,
    ProfileWeights? weights,
    bool? seniorMode,
  }) => ComfortProfile(
    id: id ?? this.id,
    weights: weights ?? this.weights,
    seniorMode: seniorMode ?? this.seniorMode,
  );

  Map<String, dynamic> toJson() => _$ComfortProfileToJson(this);

  @override
  bool operator ==(Object other) =>
      other is ComfortProfile &&
      other.id == id &&
      other.seniorMode == seniorMode &&
      other.weights.shade == weights.shade &&
      other.weights.time == weights.time &&
      other.weights.quiet == weights.quiet &&
      other.weights.air == weights.air;

  @override
  int get hashCode => Object.hash(
    id,
    seniorMode,
    weights.shade,
    weights.time,
    weights.quiet,
    weights.air,
  );

  @override
  String toString() =>
      'ComfortProfile(${id.name}, shade ${weights.shade}, time ${weights.time}, '
      'quiet ${weights.quiet}, air ${weights.air}, senior $seniorMode)';
}

/// One weight of [ProfileWeights], for the four «Dostosuj» sliders.
enum WeightKind { shade, time, quiet, air }

extension ProfileWeightsEdit on ProfileWeights {
  int valueOf(WeightKind kind) => switch (kind) {
    WeightKind.shade => shade,
    WeightKind.time => time,
    WeightKind.quiet => quiet,
    WeightKind.air => air,
  };

  ProfileWeights withValue(WeightKind kind, int value) {
    final v = value.clamp(0, 100);
    return ProfileWeights(
      shade: kind == WeightKind.shade ? v : shade,
      time: kind == WeightKind.time ? v : time,
      quiet: kind == WeightKind.quiet ? v : quiet,
      air: kind == WeightKind.air ? v : air,
    );
  }
}
