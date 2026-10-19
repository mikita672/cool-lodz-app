import 'package:cool_lodz/features/alerts/data/push_token_sync.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../auth/fakes.dart';

void main() {
  late FakeUserProfileRepository profiles;
  late FakePushService push;
  late PushTokenSync sync;

  setUp(() {
    profiles = FakeUserProfileRepository();
    push = FakePushService();
    sync = PushTokenSync(profiles, push);
  });

  test('saves the token only with the push consent', () async {
    await sync.sync('u1');
    expect(profiles.tokens, isEmpty);

    profiles.consents['u1'] = const Consents(
      location: false,
      push: true,
      ranking: false,
    );
    await sync.sync('u1');
    expect(profiles.tokens['u1'], 'fcm-token-1');
  });

  test('sign-out removes the field and invalidates the token', () async {
    profiles.tokens['u1'] = 'fcm-token-1';
    await sync.clear('u1');
    expect(profiles.tokens['u1'], isNull);
    expect(push.deletedTokens, 1);
  });
}
