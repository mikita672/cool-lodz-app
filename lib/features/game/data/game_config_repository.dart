import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../../core/models/models.dart';
import '../../alerts/data/alert_providers.dart';

/// `config/game`: set by hand in the Firebase console for the demo.
@immutable
class GameSettings {
  const GameSettings({this.heatOverride = 0, this.activeQuestId});

  factory GameSettings.fromDoc(Map<String, dynamic>? d) => GameSettings(
    heatOverride: ((d?[GameConfigFields.heatOverride] as num?)?.toInt() ?? 0)
        .clamp(0, 3),
    activeQuestId: d?[GameConfigFields.activeQuestId] as String?,
  );

  /// 0–3: forces at least this heat level (demo: «heatOverride = 2»).
  final int heatOverride;
  final String? activeQuestId;
}

/// Live `config/game`; defaults when it cannot be read (signed out,
/// offline without cache).
final gameSettingsProvider = StreamProvider<GameSettings>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.config)
      .doc(FirestoreCollections.gameConfigDoc)
      .snapshots()
      .map((s) => GameSettings.fromDoc(s.data()))
      .handleError((Object e) => debugPrint('config/game: $e'));
});

/// Current heat level 0–3: the strongest of the IMGW alert and
/// `config/game.heatOverride`. Level 3 is heat mode.
final heatLevelProvider = Provider<int>((ref) {
  final alert = ref.watch(activeAlertProvider).value?.level ?? 0;
  final override = ref.watch(gameSettingsProvider).value?.heatOverride ?? 0;
  return alert > override ? alert : override;
});

/// The alert S05, S10 and S14 show: the IMGW alert, or — when
/// `config/game.heatOverride` is higher (demo) — an alert of that level for
/// today in Łódź with an empty [Alert.title] and [Alert.source] (the UI
/// then uses its own texts).
final currentAlertProvider = Provider<Alert?>((ref) {
  final alert = ref.watch(activeAlertProvider).value;
  final override = ref.watch(gameSettingsProvider).value?.heatOverride ?? 0;
  if (override <= (alert?.level ?? 0)) return alert;
  final now = ref.read(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  return Alert(
    id: 'heatOverride-$override',
    level: override,
    title: '',
    area: 'Łódź',
    validFrom: today,
    validTo: today.add(const Duration(hours: 22)),
    source: '',
  );
});

/// True for an alert made from `heatOverride` (no IMGW data behind it).
bool isOverrideAlert(Alert alert) => alert.id.startsWith('heatOverride-');
