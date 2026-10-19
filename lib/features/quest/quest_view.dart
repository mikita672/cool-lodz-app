import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_rules.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/letter_tile.dart';
import '../achievements/badge_info.dart';
import '../auth/data/auth_repository.dart';
import '../cool_places/place_sheet.dart';
import '../game/data/game_config_repository.dart';
import '../game/data/game_repository.dart';
import '../game/game_service.dart';
import 'data/quest_repository.dart';

/// Pays today's visits that have no scan points yet (the award failed, or
/// the visit was queued offline). Runs while S10 is open.
final scanSyncProvider = FutureProvider.autoDispose<GameAward>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return GameAward.none;
  final visits = ref.watch(visitedTodayProvider).value ?? const <String>{};
  if (visits.isEmpty) return GameAward.none;
  return ref.read(gameServiceProvider).syncScans(visits);
}, retry: (_, _) => null);

/// Whether the signed-in user solved [Quest.id] (a `password` points entry).
final questSolvedProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  final quest = await ref.watch(questProvider.future);
  final history = await ref.watch(gameRepositoryProvider).history(uid);
  return history.has(PointsType.password, refId: quest.id);
});

/// Demo discount code for the reward screen (real MPK codes are a next
/// step): stable per user, easy to read aloud.
String rewardCode(String uid) {
  var h = 0x811c9dc5;
  for (final unit in uid.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final buf = StringBuffer('CHLODNO-');
  for (var i = 0; i < 4; i++) {
    buf.write(alphabet[h % alphabet.length]);
    h ~/= alphabet.length;
  }
  return buf.toString();
}

/// S10 Quest «Chłodne hasło»: letters, progress, places, «Skanuj kod QR»,
/// the password after 7 letters and the reward.
class QuestView extends ConsumerWidget {
  const QuestView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final questAsync = ref.watch(questProvider);
    final visited = ref.watch(visitedPlacesProvider).value ?? const {};
    final heat = ref.watch(heatLevelProvider) >= GameConfig.heatModeLevel;
    final solved = ref.watch(questSolvedProvider).value ?? false;
    ref.listen(scanSyncProvider, (_, next) {
      final award = next.value;
      if (award != null && award.points > 0) showAwardFeedback(context, award);
    });

    final quest = questAsync.value;
    if (quest == null) {
      if (questAsync.hasError) {
        return Center(
          child: ErrorState(
            title: l10n.questLoadError,
            onRetry: () => ref.invalidate(questProvider),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final found = quest.places.where((s) => visited.contains(s.placeId));
    final allFound = found.length == quest.places.length;
    // Heat mode: places in the sun (parks) are hidden from the list.
    final shown = [
      for (final s in quest.places)
        if (!heat || s.place?.category != PlaceCategory.park) s,
    ];
    final hidden = quest.places.length - shown.length;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.s8,
        AppSizes.screenPadding,
        AppSizes.s24,
      ),
      children: [
        if (heat) ...[
          _HeatHint(text: l10n.questHeatHint),
          const SizedBox(height: AppSizes.s12),
        ],
        Semantics(
          header: true,
          child: Text(l10n.questTitle, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSizes.s4),
        Text(l10n.questIntro, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSizes.s16),
        _Letters(quest: quest, visited: visited),
        const SizedBox(height: AppSizes.s12),
        Text(
          l10n.questProgress(found.length, quest.places.length),
          key: const Key('quest-progress'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSizes.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: found.length / quest.places.length,
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
          ),
        ),
        const SizedBox(height: AppSizes.s16),
        if (solved)
          _Reward(uid: ref.read(authRepositoryProvider).currentUser?.uid ?? '')
        else if (allFound)
          _PasswordForm(quest: quest)
        else
          AppButton(
            key: const Key('quest-scan'),
            label: l10n.questScan,
            icon: Icons.qr_code_scanner_rounded,
            expand: true,
            onPressed: () => context.push(Routes.questScan),
          ),
        const SizedBox(height: AppSizes.s24),
        Semantics(
          header: true,
          child: Text(
            l10n.questPlacesTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.s4),
            child: Text(
              l10n.questHeatHidden(hidden),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: AppSizes.s8),
        for (final s in shown)
          _PlaceRow(stop: s, visited: visited.contains(s.placeId)),
      ],
    );
  }
}

class _Letters extends StatelessWidget {
  const _Letters({required this.quest, required this.visited});

  final Quest quest;
  final Set<String> visited;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final n = quest.places.length;
      const gap = AppSizes.s4;
      final size = ((constraints.maxWidth - gap * (n - 1)) / n).clamp(
        32.0,
        52.0,
      );
      return Row(
        key: const Key('quest-letters'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox(
              width: size,
              child: FittedBox(
                child: LetterTile(
                  letter: visited.contains(quest.places[i].placeId)
                      ? quest.places[i].letter
                      : null,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({required this.stop, required this.visited});

  final QuestStop stop;
  final bool visited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final place = stop.place;
    return Card(
      key: Key('quest-place-${stop.placeId}'),
      margin: const EdgeInsets.only(bottom: AppSizes.s8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.s12,
          AppSizes.s8,
          AppSizes.s8,
          AppSizes.s8,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visited ? AppColors.primary : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: visited
                  ? Text(
                      stop.letter,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text('${stop.order}', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place?.name ?? stop.placeId,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    visited ? l10n.questVisited : l10n.questToVisit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: visited
                          ? AppColors.successText
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (place != null)
              TextButton(
                onPressed: () => navigateToPlace(context, ref, place),
                child: Text(l10n.dsNavigateThere),
              ),
          ],
        ),
      ),
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm({required this.quest});

  final Quest quest;

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    final l10n = AppLocalizations.of(context);
    if (!widget.quest.checkPassword(_controller.text)) {
      setState(() => _error = l10n.questPasswordWrong);
      return;
    }
    setState(() {
      _error = null;
      _checking = true;
    });
    try {
      final award = await ref
          .read(gameServiceProvider)
          .passwordSolved(widget.quest.id);
      ref.invalidate(questSolvedProvider);
      if (mounted) await showAwardFeedback(context, award);
    } catch (e) {
      debugPrint('Saving the password failed: $e');
      if (mounted) setState(() => _error = l10n.scanFailed);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: AppColors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.questPasswordTitle, style: AppTextStyles.titleM),
            const SizedBox(height: AppSizes.s12),
            TextField(
              key: const Key('quest-password'),
              controller: _controller,
              enabled: !_checking,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _check(),
              decoration: InputDecoration(
                labelText: l10n.questPasswordHint,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            AppButton(
              key: const Key('quest-password-check'),
              label: l10n.questPasswordCheck,
              loading: _checking,
              onPressed: _check,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('quest-reward'),
      color: AppColors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSizes.s8),
            Text(l10n.questRewardTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSizes.s8),
            Text(
              l10n.questRewardBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.s8),
            SelectableText(
              rewardCode(uid),
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: AppSizes.s8),
            Text(
              l10n.questRewardNote,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatHint extends StatelessWidget {
  const _HeatHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(Routes.alert),
    child: Container(
      key: const Key('quest-heat-hint'),
      padding: const EdgeInsets.all(AppSizes.s12),
      decoration: BoxDecoration(
        color: AppColors.heat3,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_rounded, color: AppColors.onPrimary),
          const SizedBox(width: AppSizes.s8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyS.copyWith(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    ),
  );
}
