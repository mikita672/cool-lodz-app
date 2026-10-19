import 'dart:convert';
import 'dart:io';

/// Raw text of `test/fixtures/<name>`.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixture(name)) as Map<String, dynamic>;

/// Asset loader for `DemoApiClient`: `assets/demo/x.json` → fixture `x.json`.
/// Records every path it is asked for.
class FixtureAssetLoader {
  final requested = <String>[];

  Future<String> call(String path) async {
    requested.add(path);
    const prefix = 'assets/demo/';
    if (!path.startsWith(prefix)) throw StateError('unexpected $path');
    final file = File('test/fixtures/${path.substring(prefix.length)}');
    if (!file.existsSync()) throw StateError('Unable to load asset: $path');
    return file.readAsStringSync(); // sync: works inside fakeAsync
  }
}
