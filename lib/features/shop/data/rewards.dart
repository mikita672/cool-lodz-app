import 'package:flutter/foundation.dart';

/// Shop sections.
enum RewardCategory { transport, museums, culture }

/// Something points buy. Partners and codes are a demo until there are
/// agreements with MPK and the venues (spec: MPK codes are mocked).
@immutable
class Reward {
  const Reward({
    required this.id,
    required this.category,
    required this.partner,
    required this.title,
    required this.cost,
    required this.codePrefix,
  });

  /// Stored in `users/{uid}/redemptions` (≤ 40 characters).
  final String id;
  final RewardCategory category;
  final String partner;
  final String title;
  final int cost;
  final String codePrefix;

  static const all = [
    Reward(
      id: 'mpk20',
      category: RewardCategory.transport,
      partner: 'MPK Łódź',
      title: 'Bilet 20-minutowy',
      cost: 300,
      codePrefix: 'MPK',
    ),
    Reward(
      id: 'mpk60',
      category: RewardCategory.transport,
      partner: 'MPK Łódź',
      title: 'Bilet 60-minutowy',
      cost: 500,
      codePrefix: 'MPK',
    ),
    Reward(
      id: 'mpk24h',
      category: RewardCategory.transport,
      partner: 'MPK Łódź',
      title: 'Bilet 24-godzinny',
      cost: 1000,
      codePrefix: 'MPK',
    ),
    Reward(
      id: 'palmiarnia',
      category: RewardCategory.museums,
      partner: 'Palmiarnia Łódzka',
      title: 'Bilet wstępu',
      cost: 400,
      codePrefix: 'PAL',
    ),
    Reward(
      id: 'cmw',
      category: RewardCategory.museums,
      partner: 'Centralne Muzeum Włókiennictwa',
      title: 'Bilet wstępu',
      cost: 600,
      codePrefix: 'CMW',
    ),
    Reward(
      id: 'msl',
      category: RewardCategory.museums,
      partner: 'Muzeum Sztuki w Łodzi',
      title: 'Bilet wstępu',
      cost: 800,
      codePrefix: 'MSL',
    ),
    Reward(
      id: 'ec1',
      category: RewardCategory.culture,
      partner: 'EC1 Łódź – Planetarium',
      title: 'Seans 50% taniej',
      cost: 700,
      codePrefix: 'EC1',
    ),
    Reward(
      id: 'filharmonia',
      category: RewardCategory.culture,
      partner: 'Filharmonia Łódzka',
      title: 'Koncert 20% taniej',
      cost: 1000,
      codePrefix: 'FIL',
    ),
    Reward(
      id: 'jaracz',
      category: RewardCategory.culture,
      partner: 'Teatr im. Stefana Jaracza',
      title: 'Spektakl 30% taniej',
      cost: 1200,
      codePrefix: 'TJ',
    ),
  ];

  static Reward? byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// A demo code for [reward]: «MPK-7KX2-Q9MD», from the user, the reward
/// and the time (each purchase gets its own).
String redemptionCode(Reward reward, String uid, DateTime at) {
  var h = 0x811c9dc5;
  for (final unit
      in '$uid|${reward.id}|${at.microsecondsSinceEpoch}'.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final buf = StringBuffer('${reward.codePrefix}-');
  for (var i = 0; i < 8; i++) {
    if (i == 4) buf.write('-');
    buf.write(alphabet[h % alphabet.length]);
    h = (h ~/ alphabet.length) ^ (h * 31 + i) & 0xffffffff;
  }
  return buf.toString();
}

/// A bought reward.
@immutable
class Redemption {
  const Redemption({
    required this.rewardId,
    required this.cost,
    required this.code,
    this.at,
  });

  final String rewardId;
  final int cost;
  final String code;

  /// Server time; null while pending.
  final DateTime? at;

  Reward? get reward => Reward.byId(rewardId);
}
