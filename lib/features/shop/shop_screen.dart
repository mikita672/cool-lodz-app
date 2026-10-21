import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../auth/data/auth_repository.dart';
import '../game/game_service.dart';
import 'data/rewards.dart';
import 'data/shop_repository.dart';

/// The user's bought rewards, newest first.
final redemptionsProvider = StreamProvider.autoDispose<List<Redemption>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(shopRepositoryProvider).watchRedemptions(uid);
});

IconData rewardIcon(RewardCategory c) => switch (c) {
  RewardCategory.transport => Icons.tram_rounded,
  RewardCategory.museums => Icons.museum_rounded,
  RewardCategory.culture => Icons.theater_comedy_rounded,
};

String rewardCategoryName(RewardCategory c, AppLocalizations l10n) =>
    switch (c) {
      RewardCategory.transport => l10n.shopTransport,
      RewardCategory.museums => l10n.shopMuseums,
      RewardCategory.culture => l10n.shopCulture,
    };

/// «Sklep z nagrodami»: points for MPK tickets, museums and culture.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _busy = false;

  Future<void> _buy(Reward reward) async {
    final l10n = AppLocalizations.of(context);
    final uid = ref.read(currentUidProvider);
    if (uid == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shopConfirmTitle),
        content: Text(
          l10n.shopConfirmBody(reward.partner, reward.title, reward.cost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.shopCancel),
          ),
          FilledButton(
            key: const Key('shop-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.shopBuy),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final redemption = await ref
          .read(shopRepositoryProvider)
          .redeem(uid, reward, now: ref.read(clockProvider)());
      if (mounted) await _showCode(redemption, reward);
    } catch (e) {
      debugPrint('Shop: $e');
      if (mounted) {
        showAppToast(context, l10n.shopError, kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCode(Redemption r, Reward reward) => showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        icon: Icon(rewardIcon(reward.category), color: AppColors.primary),
        title: Text(l10n.shopCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${reward.partner}: ${reward.title}'),
            const SizedBox(height: AppSizes.s12),
            SelectableText(
              r.code,
              key: const Key('shop-code'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(l10n.shopCodeBody, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: r.code)),
            child: Text(l10n.shopCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.shopClose),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final signedIn = ref.watch(currentUidProvider) != null;
    final player = ref.watch(playerProvider).value;
    final available = player?.available ?? 0;
    final mine = ref.watch(redemptionsProvider).value ?? const <Redemption>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shopTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [
          Card(
            color: AppColors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shopBalance, style: theme.textTheme.bodyMedium),
                  Text(
                    l10n.dsPoints(available),
                    key: const Key('shop-balance'),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSizes.s4),
                  Text(
                    signedIn ? l10n.shopEarnHint : l10n.shopSignIn,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          for (final category in RewardCategory.values) ...[
            const SizedBox(height: AppSizes.s16),
            Semantics(
              header: true,
              child: Text(
                rewardCategoryName(category, l10n),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            for (final reward in Reward.all.where(
              (r) => r.category == category,
            ))
              _RewardTile(
                reward: reward,
                available: available,
                enabled: signedIn && !_busy,
                onBuy: () => _buy(reward),
              ),
          ],
          const SizedBox(height: AppSizes.s16),
          Semantics(
            header: true,
            child: Text(l10n.shopMine, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSizes.s8),
          if (mine.isEmpty)
            Text(l10n.shopMineEmpty, style: theme.textTheme.bodySmall)
          else
            for (final r in mine)
              Card(
                child: ListTile(
                  leading: Icon(
                    rewardIcon(r.reward?.category ?? RewardCategory.transport),
                    color: AppColors.primary,
                  ),
                  title: Text(
                    r.reward == null
                        ? r.rewardId
                        : '${r.reward!.partner}: ${r.reward!.title}',
                  ),
                  subtitle: SelectableText(
                    r.code,
                    style: theme.textTheme.titleSmall?.copyWith(
                      letterSpacing: 1.2,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: l10n.shopCopy,
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: r.code));
                      showAppToast(context, l10n.shopCopied);
                    },
                  ),
                ),
              ),
          const SizedBox(height: AppSizes.s16),
          Text(
            l10n.shopDemoNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.available,
    required this.enabled,
    required this.onBuy,
  });

  final Reward reward;
  final int available;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final affordable = available >= reward.cost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Icon(
                rewardIcon(reward.category),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.partner, style: theme.textTheme.bodySmall),
                  Text(reward.title, style: theme.textTheme.titleSmall),
                  Text(
                    l10n.shopCost(reward.cost),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.s8),
            if (affordable)
              FilledButton(
                key: Key('shop-buy-${reward.id}'),
                onPressed: enabled ? onBuy : null,
                child: Text(l10n.shopBuy),
              )
            else
              Flexible(
                child: Text(
                  l10n.shopNotEnough(reward.cost - available),
                  key: Key('shop-missing-${reward.id}'),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
