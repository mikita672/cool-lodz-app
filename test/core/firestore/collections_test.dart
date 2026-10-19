import 'package:cool_lodz/core/firestore/collections.dart';
import 'package:cool_lodz/core/game/game_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekId', () {
    test('2026-01-01 (Thursday) is in week 1 of 2026', () {
      expect(weekId(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('2026-12-31 (Thursday) is in week 53 of 2026', () {
      expect(weekId(DateTime(2026, 12, 31)), '2026-W53');
    });

    test('2027-01-03 (Sunday) still belongs to 2026-W53', () {
      expect(weekId(DateTime(2027, 1, 3)), '2026-W53');
    });

    test('2027-01-04 (Monday) starts 2027-W01', () {
      expect(weekId(DateTime(2027, 1, 4)), '2027-W01');
    });

    test('late December can belong to the next ISO year', () {
      // 2025-12-29 is a Monday; the week's Thursday is 2026-01-01.
      expect(weekId(DateTime(2025, 12, 29)), '2026-W01');
    });

    test('a whole week maps to the same id, Monday to Sunday', () {
      for (var d = 19; d <= 25; d++) {
        expect(weekId(DateTime(2026, 10, d, 23, 59)), '2026-W43');
      }
      expect(weekId(DateTime(2026, 10, 26)), '2026-W44');
    });

    test('DST change days are not shifted', () {
      expect(weekId(DateTime(2026, 3, 29, 3)), '2026-W13'); // Sunday, DST on
      expect(weekId(DateTime(2026, 10, 25, 2, 30)), '2026-W43'); // DST off
    });

    test('matches the pattern the rules check', () {
      expect(
        RegExp(r'^[0-9]{4}-W[0-9]{2}$').hasMatch(weekId(DateTime(2026, 6, 1))),
        isTrue,
      );
    });
  });

  group('visitId', () {
    test('is uid_placeId_yyyyMMdd with zero padding', () {
      expect(
        visitId('abc123', 'cool-002', DateTime(2026, 7, 5, 23, 59)),
        'abc123_cool-002_20260705',
      );
    });

    test('differs per day and per place', () {
      final day = DateTime(2026, 10, 19);
      expect(
        visitId('u', 'cool-001', day),
        isNot(visitId('u', 'cool-001', day.add(const Duration(days: 1)))),
      );
      expect(
        visitId('u', 'cool-001', day),
        isNot(visitId('u', 'cool-002', day)),
      );
    });
  });

  test('district ids line up with GameConfig.districts', () {
    String slug(String name) => name
        .toLowerCase()
        .replaceAll('ł', 'l')
        .replaceAll('ó', 'o')
        .replaceAll('ś', 's')
        .replaceAll('ą', 'a')
        .replaceAll('ę', 'e')
        .replaceAll('ć', 'c')
        .replaceAll('ń', 'n')
        .replaceAll('ź', 'z')
        .replaceAll('ż', 'z');
    expect(FirestoreDistricts.ids, GameConfig.districts.map(slug).toList());
  });

  test('ranking fields mirror the user fields', () {
    expect(
      [
        RankingFields.nickname,
        RankingFields.district,
        RankingFields.points,
        RankingFields.weekId,
        RankingFields.weekPoints,
      ],
      [
        UserFields.nickname,
        UserFields.district,
        UserFields.points,
        UserFields.weekId,
        UserFields.weekPoints,
      ],
    );
  });
}
