import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/leaderboard_row.dart';
import '../../shared/widgets/skeleton.dart';
import '../game/game_service.dart';
import 'data/ranking_repository.dart';

/// S13 Ranking: «Dzielnice / Użytkownicy» and «Ten tydzień / Całe lato».
/// The user's row is highlighted and pinned at the bottom when it is not
/// on screen.
class RankingView extends ConsumerStatefulWidget {
  const RankingView({super.key});

  @override
  ConsumerState<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends ConsumerState<RankingView> {
  RankingScope _scope = RankingScope.districts;
  RankingPeriod _period = RankingPeriod.week;
  final _scroll = ScrollController();
  final _ownKey = GlobalKey();
  bool _ownVisible = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Whether the highlighted row is inside the list viewport.
  void _checkOwnVisible() {
    final ctx = _ownKey.currentContext;
    var visible = false;
    if (ctx != null && _scroll.hasClients) {
      final box = ctx.findRenderObject() as RenderBox?;
      final viewport =
          _scroll.position.context.storageContext.findRenderObject()
              as RenderBox?;
      if (box != null && viewport != null && box.attached) {
        final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        visible = top >= 0 && top + box.size.height <= viewport.size.height + 1;
      }
    }
    if (visible != _ownVisible) setState(() => _ownVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(rankingProvider((_scope, _period)));
    final player = ref.watch(playerProvider).value;
    final own = _scope == RankingScope.users
        ? ref.watch(ownRankingProvider(_period)).value
        : null;
    final ownId = _scope == RankingScope.users ? own?.$2.id : player?.district;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOwnVisible();
    });

    final Widget list;
    if (rows.value case final entries?) {
      final ownIndex = entries.indexWhere((e) => e.id == ownId);
      list = NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _checkOwnVisible();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rankingProvider((_scope, _period)));
            ref.invalidate(ownRankingProvider(_period));
          },
          child: entries.isEmpty || entries.every((e) => e.points == 0)
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSizes.s24),
                      child: Text(
                        l10n.rankingEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  key: const Key('ranking-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    0,
                    AppSizes.screenPadding,
                    AppSizes.s16,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.s4),
                  itemBuilder: (context, i) => LeaderboardRow(
                    key: i == ownIndex ? _ownKey : null,
                    rank: i + 1,
                    name: entries[i].name,
                    points: entries[i].points,
                    own: i == ownIndex,
                  ),
                ),
        ),
      );
    } else if (rows.hasError) {
      list = Center(
        child: ErrorState(
          title: l10n.rankingLoadError,
          onRetry: () => ref.invalidate(rankingProvider((_scope, _period))),
        ),
      );
    } else {
      list = ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          for (var i = 0; i < 6; i++) ...const [
            SkeletonBox(height: 48),
            SizedBox(height: AppSizes.s8),
          ],
        ],
      );
    }

    final entries = rows.value ?? const <RankingEntry>[];
    final RankingEntry? pinned;
    final int pinnedRank;
    if (_scope == RankingScope.users) {
      pinned = own?.$2;
      pinnedRank = own?.$1 ?? 0;
    } else {
      final i = entries.indexWhere((e) => e.id == player?.district);
      pinned = i < 0 ? null : entries[i];
      pinnedRank = i + 1;
    }

    String? note;
    if (_scope == RankingScope.users &&
        player != null &&
        !player.rankingConsent) {
      note = l10n.rankingNoConsent;
    } else if (_scope == RankingScope.districts &&
        player != null &&
        player.district == null) {
      note = l10n.rankingNoDistrict;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenPadding,
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<RankingScope>(
                  key: const Key('ranking-scope'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: RankingScope.districts,
                      label: Text(l10n.rankingDistricts),
                    ),
                    ButtonSegment(
                      value: RankingScope.users,
                      label: Text(l10n.rankingUsers),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) => setState(() {
                    _scope = s.single;
                    _ownVisible = false;
                  }),
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Wrap(
                spacing: AppSizes.s8,
                children: [
                  for (final p in RankingPeriod.values)
                    ChoiceChip(
                      key: Key('ranking-period-${p.name}'),
                      label: Text(
                        p == RankingPeriod.week
                            ? l10n.rankingWeek
                            : l10n.rankingSummer,
                      ),
                      selected: _period == p,
                      onSelected: (_) => setState(() {
                        _period = p;
                        _ownVisible = false;
                      }),
                    ),
                ],
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSizes.s8),
                  child: Text(
                    note,
                    key: const Key('ranking-note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSizes.s8),
            ],
          ),
        ),
        Expanded(child: list),
        if (pinned != null && !_ownVisible)
          Material(
            elevation: 8,
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.s8),
                child: LeaderboardRow(
                  key: const Key('ranking-own-pinned'),
                  rank: pinnedRank,
                  name: pinned.name,
                  points: pinned.points,
                  own: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
