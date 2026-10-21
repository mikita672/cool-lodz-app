import 'dart:async';

import 'package:cool_lodz/features/game/data/game_repository.dart';
import 'package:cool_lodz/features/shop/data/rewards.dart';
import 'package:cool_lodz/features/shop/data/shop_repository.dart';
import 'package:cool_lodz/features/shop/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

class FakeShopRepository implements ShopRepository {
  FakeShopRepository(this.game);

  final FakeGameRepository game;
  final bought = <Redemption>[];
  final _changes = StreamController<List<Redemption>>.broadcast();

  @override
  Future<Redemption> redeem(
    String uid,
    Reward reward, {
    required DateTime now,
  }) async {
    final p = game.state;
    if (p.available < reward.cost) throw const NotEnoughPoints();
    game.state = PlayerState(
      nickname: p.nickname,
      points: p.points,
      badges: p.badges,
      spent: p.spent + reward.cost,
    );
    final r = Redemption(
      rewardId: reward.id,
      cost: reward.cost,
      code: redemptionCode(reward, uid, now),
    );
    bought.insert(0, r);
    _changes.add(List.of(bought));
    return r;
  }

  @override
  Stream<List<Redemption>> watchRedemptions(String uid) async* {
    yield List.of(bought);
    yield* _changes.stream;
  }
}

void main() {
  test('codes: partner prefix, two groups of four, different each time', () {
    final mpk = Reward.byId('mpk20')!;
    final a = redemptionCode(mpk, 'u1', DateTime(2026, 7, 15, 12));
    final b = redemptionCode(mpk, 'u1', DateTime(2026, 7, 15, 12, 1));
    expect(a, matches(RegExp(r'^MPK-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    expect(a, isNot(b));
    expect(Reward.all.map((r) => r.id).toSet(), hasLength(Reward.all.length));
  });

  group('screen', () {
    late SharedPreferences prefs;
    late FakeGameRepository game;
    late FakeShopRepository shop;

    setUp(() async {
      prefs = await testPrefs();
      game = FakeGameRepository(
        player: const PlayerState(nickname: 'Ala', points: 900, spent: 100),
      );
      shop = FakeShopRepository(game);
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(
        tester,
        const ShopScreen(),
        overrides: [
          ...appTestOverrides(prefs: prefs, game: game),
          shopRepositoryProvider.overrideWithValue(shop),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('balance is points − spent; too dear says what is missing', (
      tester,
    ) async {
      await pump(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('shop-balance'))).data,
        '800 pkt',
      );
      expect(find.byKey(const Key('shop-buy-mpk20')), findsOneWidget);
      expect(find.text('Brakuje 400 pkt'), findsWidgets); // 1200 for Jaracz
      expect(find.text('Jeszcze nic nie wymieniono.'), findsOneWidget);
    });

    testWidgets('buying shows the code and lists it in «Moje nagrody»', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('shop-buy-mpk20')));
      await tester.pumpAndSettle();
      expect(find.text('Wymienić punkty?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-code')), findsOneWidget);
      expect(game.state.spent, 400);
      await tester.tap(find.text('Gotowe'));
      await tester.pumpAndSettle();
      expect(find.text('MPK Łódź: Bilet 20-minutowy'), findsOneWidget);
      expect(shop.bought.single.code, startsWith('MPK-'));
    });
  });
}
