import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/firestore/collections.dart';
import '../../core/location/location_service.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/map/base_map.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../auth/data/auth_repository.dart';
import 'data/report_repository.dart';

/// S15 Zgłoszenie: type, position on a mini map (the pin stays in the
/// middle, the map moves), comment up to 200 characters. Saved to
/// `reports` with status `new`; +20 points after approval.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.place});

  /// The place from S08 «Zgłoś problem»; its position is the start point.
  final Place? place;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  ReportType? _type;
  LatLng? _position;
  final _comment = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _typeError;

  /// One document id per screen: a retry after a timeout writes the same
  /// report again instead of a second one.
  late final String _reportId = ref.read(reportRepositoryProvider).newId();

  @override
  void initState() {
    super.initState();
    final place = widget.place;
    if (place != null) {
      _position = place.latLng;
    } else {
      _locate();
    }
  }

  Future<void> _locate() async {
    LatLng position;
    try {
      position = await ref.read(locationServiceProvider).current();
    } on LocationUnavailable {
      position = lodzCenter;
    }
    if (mounted && _position == null) setState(() => _position = position);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final type = _type;
    if (type == null) {
      setState(() => _typeError = l10n.reportChooseType);
      return;
    }
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final position = _position;
    if (uid == null || position == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(reportRepositoryProvider)
          .create(
            id: _reportId,
            uid: uid,
            type: type,
            lat: position.latitude,
            lon: position.longitude,
            comment: _comment.text,
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      debugPrint('Sending the report failed: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      showAppToast(context, l10n.reportError, kind: ToastKind.error);
    }
  }

  void _back() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reportTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s24),
            child: Column(
              key: const Key('report-sent'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSizes.s16),
                Text(l10n.reportThanksTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSizes.s8),
                Text(
                  l10n.reportThanksBody,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.s24),
                AppButton(
                  key: const Key('report-back'),
                  label: l10n.reportBack,
                  onPressed: _back,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final types = [
      (ReportType.noBench, Icons.chair_alt_rounded, l10n.reportNoBench),
      (ReportType.noWater, Icons.water_drop_rounded, l10n.reportNoWater),
      (ReportType.noShade, Icons.wb_sunny_rounded, l10n.reportNoShade),
      (ReportType.other, Icons.more_horiz_rounded, l10n.reportOther),
    ];
    final position = _position;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  if (widget.place?.name case final name?) ...[
                    Text(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSizes.s12),
                  ],
                  Text(l10n.reportTypeTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSizes.s8),
                  Wrap(
                    spacing: AppSizes.s8,
                    runSpacing: AppSizes.s8,
                    children: [
                      for (final (type, icon, label) in types)
                        ChoiceChip(
                          key: Key('report-type-${type.id}'),
                          avatar: Icon(
                            icon,
                            size: 18,
                            color: _type == type
                                ? AppColors.onPrimary
                                : AppColors.primary,
                          ),
                          label: Text(label),
                          labelStyle: AppTextStyles.label.copyWith(
                            color: _type == type
                                ? AppColors.onPrimary
                                : AppColors.onSurface,
                          ),
                          selected: _type == type,
                          onSelected: _sending
                              ? null
                              : (_) => setState(() {
                                  _type = type;
                                  _typeError = null;
                                }),
                        ),
                    ],
                  ),
                  if (_typeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.s4),
                      child: Text(
                        _typeError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSizes.s24),
                  Text(l10n.reportWhere, style: theme.textTheme.titleSmall),
                  Text(l10n.reportWhereHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSizes.s8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    child: SizedBox(
                      height: 220,
                      child: position == null
                          ? const Center(child: CircularProgressIndicator())
                          : Semantics(
                              label: l10n.reportMapSemantics,
                              child: Stack(
                                children: [
                                  BaseMap(
                                    key: const Key('report-map'),
                                    options: MapOptions(
                                      initialCenter: position,
                                      initialZoom: 17,
                                      minZoom: MapTiles.minZoom,
                                      maxZoom: MapTiles.maxZoom,
                                      interactionOptions:
                                          const InteractionOptions(
                                            flags:
                                                InteractiveFlag.all &
                                                ~InteractiveFlag.rotate,
                                          ),
                                      onPositionChanged: (camera, gesture) {
                                        if (gesture) {
                                          _position = camera.center;
                                        }
                                      },
                                    ),
                                  ),
                                  // The pin's tip marks the map centre.
                                  const IgnorePointer(
                                    child: Align(
                                      alignment: Alignment(0, -0.18),
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        size: 40,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s24),
                  TextField(
                    key: const Key('report-comment'),
                    controller: _comment,
                    maxLength: FirestoreReports.commentMaxLength,
                    maxLines: 3,
                    enabled: !_sending,
                    decoration: InputDecoration(labelText: l10n.reportComment),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              child: AppButton(
                key: const Key('report-send'),
                label: l10n.reportSend,
                icon: Icons.send_rounded,
                loading: _sending,
                expand: true,
                onPressed: position == null ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
