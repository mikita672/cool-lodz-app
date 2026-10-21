import 'package:flutter/foundation.dart';

import '../firestore/collections.dart';
import 'game_rules.dart';

/// What a weekly challenge counts.
enum ChallengeKind {
  /// Routes with ≥ 60 % shade.
  shadedRoutes,

  /// Distinct quest places scanned.
  coolScans,

  /// Kilometres walked.
  distance,

  /// Walks leaving before 10:00 or from 19:00 (the cool hours).
  coolHours,

  /// Routes with a drinking water point on the way.
  waterRoutes,
}

/// «Wyzwanie tygodnia»: one goal per ISO week, +[bonus] points once.
@immutable
class Challenge {
  const Challenge(this.kind, this.target);

  final ChallengeKind kind;
  final int target;

  static const bonus = 50;

  /// In demo mode one is enough, so the demo can finish it.
  static const demoTarget = 1;

  /// The rotation, one per week.
  static const all = [
    Challenge(ChallengeKind.shadedRoutes, 3),
    Challenge(ChallengeKind.coolScans, 2),
    Challenge(ChallengeKind.distance, 5),
    Challenge(ChallengeKind.coolHours, 2),
    Challenge(ChallengeKind.waterRoutes, 2),
  ];

  /// The challenge of [week] (`2026-W43`); `config/game.challenge` (a
  /// [ChallengeKind] name) can pick one for a demo.
  static Challenge forWeek(String week, {String? override}) {
    for (final c in all) {
      if (c.kind.name == override) return c;
    }
    final number = int.tryParse(week.split('-W').last) ?? 0;
    return all[number % all.length];
  }

  /// Progress in [week] from [history] (pending entries count as now).
  int progress(GameHistory history, String week) {
    final routes = history.routes.where((r) => weekId(r.departAt) == week);
    return switch (kind) {
      ChallengeKind.shadedRoutes => routes.where((r) => r.isShaded).length,
      ChallengeKind.coolScans => {
        for (final e in history.log)
          if (e.type == PointsType.scan &&
              e.refId != null &&
              (e.at == null || weekId(e.at!.toLocal()) == week))
            e.refId!,
      }.length,
      ChallengeKind.distance =>
        routes.fold(0, (a, r) => a + r.distanceM) ~/ 1000,
      ChallengeKind.coolHours =>
        routes
            .where((r) => r.departAt.hour < 10 || r.departAt.hour >= 19)
            .length,
      ChallengeKind.waterRoutes => routes.where((r) => r.waterStops > 0).length,
    };
  }
}

/// The current week's challenge and how far the user is.
@immutable
class ChallengeState {
  const ChallengeState({
    required this.challenge,
    required this.week,
    required this.progress,
    required this.target,
    required this.awarded,
    required this.daysLeft,
  });

  /// [now] is local time; [demo] lowers the target to
  /// [Challenge.demoTarget].
  factory ChallengeState.of(
    GameHistory history,
    DateTime now, {
    String? override,
    bool demo = false,
  }) {
    final week = weekId(now);
    final challenge = Challenge.forWeek(week, override: override);
    return ChallengeState(
      challenge: challenge,
      week: week,
      progress: challenge.progress(history, week),
      target: demo ? Challenge.demoTarget : challenge.target,
      awarded: history.has(PointsType.challenge, refId: week),
      daysLeft: DateTime.sunday - now.weekday,
    );
  }

  final Challenge challenge;
  final String week;
  final int progress;
  final int target;

  /// The bonus for this week is already in the points log.
  final bool awarded;

  /// Days after today until Sunday (0 on Sunday).
  final int daysLeft;

  bool get complete => progress >= target;

  /// Complete, and the bonus is still to be paid.
  bool get due => complete && !awarded;
}
