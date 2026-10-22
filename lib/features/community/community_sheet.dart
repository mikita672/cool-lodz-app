import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/share.dart';
import '../../shared/widgets/app_toast.dart';
import '../auth/data/auth_repository.dart';
import 'data/crowd_points.dart';

Color crowdColor(CrowdKind kind) => switch (kind) {
  CrowdKind.tree => const Color(0xFF2E7D32),
  CrowdKind.tap => const Color(0xFF0277BD),
};

IconData crowdIcon(CrowdKind kind) => switch (kind) {
  CrowdKind.tree => Icons.park_rounded,
  CrowdKind.tap => Icons.water_drop_rounded,
};

String crowdTitle(CrowdKind kind, AppLocalizations l10n) => switch (kind) {
  CrowdKind.tree => l10n.crowdTree,
  CrowdKind.tap => l10n.crowdTap,
};

/// A community point on the «Społeczność» layer, with its vote count.
class CrowdPin extends StatelessWidget {
  const CrowdPin({super.key, required this.point, required this.onTap});

  final CrowdPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${crowdTitle(point.kind, l10n)}, ${l10n.crowdVotes(point.votes)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: crowdColor(point.kind),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(crowdIcon(point.kind), size: 18, color: Colors.white),
            ),
            if (point.votes > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: crowdColor(point.kind)),
                  ),
                  child: Text('${point.votes}', style: AppTextStyles.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks what to add at [at] (the map centre) and saves it.
Future<void> addCrowdPoint(
  BuildContext context,
  WidgetRef ref,
  LatLng at,
) async {
  final l10n = AppLocalizations.of(context);
  final uid = ref.read(currentUidProvider);
  if (uid == null) {
    showAppToast(context, l10n.crowdSignIn, kind: ToastKind.warning);
    return;
  }
  if (!inLodz(at)) {
    showAppToast(context, l10n.crowdOutside, kind: ToastKind.warning);
    return;
  }
  final result = await showDialog<(CrowdKind, String)>(
    context: context,
    builder: (_) => const _AddDialog(),
  );
  if (result == null || !context.mounted) return;
  try {
    await ref
        .read(crowdRepositoryProvider)
        .add(uid, result.$1, at, note: result.$2);
    if (context.mounted) {
      showAppToast(context, l10n.crowdAdded, kind: ToastKind.success);
    }
  } catch (e) {
    debugPrint('Crowd add: $e');
    if (context.mounted) {
      showAppToast(context, l10n.crowdError, kind: ToastKind.error);
    }
  }
}

/// Shares every point as GeoJSON (for the city's greenery and water
/// services).
Future<void> exportCrowdPoints(
  BuildContext context,
  WidgetRef ref,
  List<CrowdPoint> points,
) async {
  final l10n = AppLocalizations.of(context);
  if (points.isEmpty) {
    showAppToast(context, l10n.crowdExportEmpty);
    return;
  }
  final shared = await ref.read(shareTextProvider)(
    crowdGeoJson(points),
    title: l10n.crowdExportTitle,
  );
  if (!shared && context.mounted) showAppToast(context, l10n.crowdCopied);
}

Future<void> showCrowdPointSheet(BuildContext context, CrowdPoint point) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PointSheet(point: point),
    );

class _PointSheet extends ConsumerStatefulWidget {
  const _PointSheet({required this.point});

  final CrowdPoint point;

  @override
  ConsumerState<_PointSheet> createState() => _PointSheetState();
}

class _PointSheetState extends ConsumerState<_PointSheet> {
  bool _busy = false;

  Future<void> _vote() async {
    final l10n = AppLocalizations.of(context);
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(crowdRepositoryProvider).vote(uid, widget.point);
      if (mounted) {
        Navigator.of(context).pop();
        showAppToast(context, l10n.crowdVoted, kind: ToastKind.success);
      }
    } on AlreadyVoted {
      if (mounted) showAppToast(context, l10n.crowdAlreadyVoted);
    } catch (e) {
      debugPrint('Crowd vote: $e');
      if (mounted) {
        showAppToast(context, l10n.crowdError, kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    try {
      await ref.read(crowdRepositoryProvider).remove(widget.point);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Crowd remove: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.point;
    final mine = p.uid == ref.watch(currentUidProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.screenPadding,
        ),
        child: Column(
          key: const Key('crowd-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(crowdIcon(p.kind), color: crowdColor(p.kind), size: 32),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Text(
                    crowdTitle(p.kind, l10n),
                    style: AppTextStyles.titleM,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            if (p.note.isNotEmpty)
              Text(p.note, style: theme.textTheme.bodyLarge),
            Text(
              p.kind == CrowdKind.tree
                  ? l10n.crowdTreeVotes(p.votes)
                  : l10n.crowdTapVotes(p.votes),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.s16),
            FilledButton.icon(
              key: const Key('crowd-vote'),
              onPressed: _busy ? null : _vote,
              icon: Icon(
                p.kind == CrowdKind.tree
                    ? Icons.thumb_up_alt_rounded
                    : Icons.check_circle_rounded,
              ),
              label: Text(
                p.kind == CrowdKind.tree
                    ? l10n.crowdSupport
                    : l10n.crowdConfirm,
              ),
            ),
            if (mine) ...[
              const SizedBox(height: AppSizes.s8),
              TextButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.crowdRemove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  CrowdKind _kind = CrowdKind.tree;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.crowdAddTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.crowdAddHint),
            const SizedBox(height: AppSizes.s8),
            RadioGroup<CrowdKind>(
              groupValue: _kind,
              onChanged: (k) => setState(() => _kind = k ?? _kind),
              child: Column(
                children: [
                  for (final k in CrowdKind.values)
                    RadioListTile<CrowdKind>(
                      key: Key('crowd-kind-${k.name}'),
                      value: k,
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(crowdIcon(k), color: crowdColor(k)),
                      title: Text(crowdTitle(k, l10n)),
                      subtitle: Text(
                        k == CrowdKind.tree
                            ? l10n.crowdTreeHint
                            : l10n.crowdTapHint,
                      ),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('crowd-note'),
              controller: _note,
              maxLength: crowdNoteMax,
              decoration: InputDecoration(labelText: l10n.crowdNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.heatGuardCancel),
        ),
        FilledButton(
          key: const Key('crowd-save'),
          onPressed: () => Navigator.of(context).pop((_kind, _note.text)),
          child: Text(l10n.crowdSave),
        ),
      ],
    );
  }
}
