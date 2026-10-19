import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
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
