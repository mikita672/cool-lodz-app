import 'package:cool_lodz/shared/map/base_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CARTO key goes into the tile URL as ?key=', () {
    expect(
      MapTiles.urlFor('abc123'),
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'
      '?key=abc123',
    );
    expect(MapTiles.urlFor(' a b&c '), endsWith('?key=a+b%26c'));
  });

  test('no key → the plain URL (tests build without MAP_TILES_KEY)', () {
    expect(MapTiles.urlFor(''), isNot(contains('key=')));
    expect(MapTiles.urlTemplate, MapTiles.urlFor(''));
  });
}
