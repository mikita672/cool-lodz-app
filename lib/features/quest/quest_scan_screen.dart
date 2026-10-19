import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/game/game_rules.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/letter_tile.dart';
import '../achievements/badge_info.dart';
import '../game/game_service.dart';
import 'data/quest_repository.dart';
import 'data/quest_scan.dart';

/// The camera part of S11. [onCode] gets every QR text; [noPermission]
/// builds the «Otwórz ustawienia» state. Replaced in widget tests.
typedef QrScannerBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<String> onCode,
      WidgetBuilder noPermission,
    );

final qrScannerBuilderProvider = Provider<QrScannerBuilder>(
  (ref) =>
      (context, onCode, noPermission) =>
          _CameraScanner(onCode: onCode, noPermission: noPermission),
);

/// Opens the app's page in Android settings (camera permission).
final openAppSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await Geolocator.openAppSettings();
  },
);

/// S11 Skaner QR: full-screen camera with a frame. A code is checked by
/// [QuestScanService]; success shows the letter and «+50 pkt».
class QuestScanScreen extends ConsumerStatefulWidget {
  const QuestScanScreen({super.key});

  @override
  ConsumerState<QuestScanScreen> createState() => _QuestScanScreenState();
}

class _QuestScanScreenState extends ConsumerState<QuestScanScreen> {
  bool _checking = false;
  ScanResult? _result;

  Future<void> _onCode(String raw) async {
    if (_checking || _result != null) return;
    setState(() => _checking = true);
    final result = await ref.read(questScanServiceProvider).scan(raw);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
    if (result is ScanSuccess) {
      ref.invalidate(visitedPlacesProvider);
      // Badges (e.g. Strażnik chłodu) after the letter is on screen.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        await showAwardFeedback(
          context,
          GameAward(badges: result.award.badges),
        );
      }
    }
  }

  void _back() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.quest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scanner = ref.watch(qrScannerBuilderProvider);
    final result = _result;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.scanTitle),
        backgroundColor: Colors.black,
        foregroundColor: AppColors.onPrimary,
        titleTextStyle: AppTextStyles.titleL.copyWith(
          color: AppColors.onPrimary,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (result is! ScanSuccess)
            scanner(context, _onCode, (context) => const _NoCamera()),
          if (result == null) ...[
            const IgnorePointer(child: _Frame()),
            Positioned(
              left: AppSizes.s16,
              right: AppSizes.s16,
              bottom: AppSizes.s32,
              child: _Hint(text: _checking ? l10n.scanChecking : l10n.scanHint),
            ),
            if (_checking) const Center(child: CircularProgressIndicator()),
          ],
          if (result is ScanFailure)
            Positioned(
              left: AppSizes.s16,
              right: AppSizes.s16,
              bottom: AppSizes.s24,
              child: _FailureCard(
                failure: result,
                onRetry: () => setState(() => _result = null),
              ),
            ),
          if (result is ScanSuccess)
            _SuccessView(result: result, onDone: _back),
        ],
      ),
    );
  }
}

class _CameraScanner extends StatefulWidget {
  const _CameraScanner({required this.onCode, required this.noPermission});

  final ValueChanged<String> onCode;
  final WidgetBuilder noPermission;

  @override
  State<_CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<_CameraScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: (capture) {
      for (final b in capture.barcodes) {
        final raw = b.rawValue;
        if (raw != null) {
          widget.onCode(raw);
          return;
        }
      }
    },
    errorBuilder: (context, error) =>
        error.errorCode == MobileScannerErrorCode.permissionDenied
        ? widget.noPermission(context)
        : Center(
            child: Text(
              AppLocalizations.of(context).scanCameraError,
              style: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
            ),
          ),
  );
}

class _Frame extends StatelessWidget {
  const _Frame();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.onPrimary, width: 4),
        borderRadius: BorderRadius.circular(AppSizes.radiusSheet),
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(AppSizes.s12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
      ),
    ),
  );
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure, required this.onRetry});

  final ScanFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, detail) = switch (failure.problem) {
      ScanProblem.tooFar => (
        l10n.scanTooFar,
        failure.distanceMeters == null
            ? null
            : l10n.scanTooFarDetail(failure.distanceMeters!.round()),
      ),
      ScanProblem.alreadyToday => (l10n.scanAlreadyToday, null),
      ScanProblem.invalidCode => (l10n.scanInvalid, null),
      ScanProblem.noLocation => (l10n.scanNoLocation, null),
      ScanProblem.failed => (l10n.scanFailed, null),
    };
    return Card(
      key: const Key('scan-failure'),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_rounded, color: AppColors.error),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(title, style: AppTextStyles.titleM),
                  ),
                ),
              ],
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSizes.s8),
              Text(detail, style: AppTextStyles.bodyS),
            ],
            const SizedBox(height: AppSizes.s12),
            AppButton(
              key: const Key('scan-again'),
              label: l10n.scanAgain,
              icon: Icons.qr_code_scanner_rounded,
              onPressed: onRetry,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result, required this.onDone});

  final ScanSuccess result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final points = result.award.pointsFor(PointsType.scan);
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s24),
          child: Column(
            key: const Key('scan-success'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1),
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: SizedBox(
                  width: 96,
                  child: FittedBox(
                    child: LetterTile(letter: result.stop.letter),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.s24),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.scanSuccess(result.stop.letter),
                  style: AppTextStyles.titleL,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                result.stop.place?.name ?? '',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              if (points > 0) ...[
                const SizedBox(height: AppSizes.s16),
                Text(
                  l10n.dsPointsGained(points),
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.successText,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.s32),
              AppButton(
                key: const Key('scan-done'),
                label: l10n.scanBackToQuest,
                onPressed: onDone,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCamera extends ConsumerWidget {
  const _NoCamera();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s24),
          child: Column(
            key: const Key('scan-no-camera'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSizes.s16),
              Text(
                l10n.scanNoCameraTitle,
                style: AppTextStyles.titleM,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.s8),
              Text(
                l10n.scanNoCameraBody,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.s24),
              AppButton(
                label: l10n.scanOpenSettings,
                icon: Icons.settings_rounded,
                onPressed: () => ref.read(openAppSettingsProvider)(),
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
