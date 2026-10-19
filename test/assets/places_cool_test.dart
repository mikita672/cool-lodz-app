import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks the hand-collected demo data in `assets/demo/` (APP-05) against
/// the `/v1/places` contract and the quest rules.
void main() {
  final places = (_readJson('assets/demo/places_cool.json')['places'] as List)
      .cast<Map<String, dynamic>>();
  final quest = _readJson('assets/demo/quest.json');

  const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  const categories = {
    'library',
    'museum',
    'culture',
    'mall',
    'park',
    'station',
    'church',
    'other',
  };
  const amenities = {'airConditioning', 'water', 'toilet', 'wheelchair'};
  final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  test('has 15–20 places sorted by unique cool-xxx ids', () {
    expect(places.length, inInclusiveRange(15, 20));
    final ids = places.map((p) => p['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, everyElement(matches(RegExp(r'^cool-\d{3}$'))));
    expect(ids, [...ids]..sort());
  });

  test('every place has the contract fields and a source URL', () {
    for (final p in places) {
      final id = p['id'];
      expect(p['type'], 'cool', reason: '$id type');
      expect(p['name'], isA<String>().having((s) => s, 'name', isNotEmpty));
      expect(categories, contains(p['category']), reason: '$id category');
      expect(p['address'], isA<String>().having((s) => s, 'addr', isNotEmpty));
      expect(p['accessible'], isA<bool>(), reason: '$id accessible');
      expect(p['questPlace'], isA<bool>(), reason: '$id questPlace');
      expect(
        (p['amenities'] as List).every(amenities.contains),
        isTrue,
        reason: '$id amenities',
      );
      final source = Uri.tryParse(p['source'] as String? ?? '');
      expect(source?.scheme, 'https', reason: '$id source');
      expect(source?.host, isNotEmpty, reason: '$id source');
    }
  });

  test('coordinates are inside Łódź', () {
    for (final p in places) {
      expect(
        (p['lat'] as num).toDouble(),
        inInclusiveRange(51.68, 51.86),
        reason: '${p['id']} lat',
      );
      expect(
        (p['lon'] as num).toDouble(),
        inInclusiveRange(19.32, 19.64),
        reason: '${p['id']} lon',
      );
    }
  });

  test('hours are null or mon..sun lists of HH:mm intervals', () {
    for (final p in places) {
      final hours = p['hours'];
      if (hours == null) continue; // always open
      final map = hours as Map<String, dynamic>;
      expect(map.keys.toList(), days, reason: '${p['id']} hours keys');
      for (final day in days) {
        for (final interval in map[day] as List) {
          final pair = (interval as List).cast<String>();
          final where = '${p['id']} $day $pair';
          expect(pair.length, 2, reason: where);
          expect(pair, everyElement(matches(time)), reason: where);
          expect(pair[0].compareTo(pair[1]), lessThan(0), reason: where);
        }
      }
    }
  });

  test('exactly 7 quest places and their letters spell CHŁODNO', () {
    final questIds = places
        .where((p) => p['questPlace'] == true)
        .map((p) => p['id'])
        .toSet();
    expect(questIds.length, 7);

    expect(quest['questId'], 'chlodne-haslo-2026');
    expect(quest['password'], 'CHŁODNO');
    final entries = (quest['places'] as List).cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    expect(entries.map((e) => e['order']), [1, 2, 3, 4, 5, 6, 7]);
    expect(entries.map((e) => e['letter']).join(), 'CHŁODNO');
    expect(entries.map((e) => e['placeId']).toSet(), questIds);
  });
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
