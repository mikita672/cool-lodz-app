import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/start_flow.dart';

/// S01 Onboarding: three slides, shown once after install. Finishing or
/// skipping stores the flag; the router then moves on to S02.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;
  static const _pageDuration = Duration(milliseconds: 300);

  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  bool get _isLast => _page == _pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(startFlowProvider.notifier).completeOnboarding();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(duration: _pageDuration, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = [
      _Slide(
        art: const _ShadeArt(),
        title: l10n.onboardingShadeTitle,
        body: l10n.onboardingShadeBody,
      ),
      _Slide(
        art: const _CoolPlaceArt(),
        title: l10n.onboardingCoolTitle,
        body: l10n.onboardingCoolBody,
      ),
      _Slide(
        art: const _LettersArt(),
        title: l10n.onboardingQuestTitle,
        body: l10n.onboardingQuestBody,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                // Keeps its height on the last slide so the layout does not jump.
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: slides,
                ),
              ),
              const SizedBox(height: AppSizes.s16),
              _PageDots(
                count: _pageCount,
                current: _page,
                label: l10n.onboardingPageIndicator(_page + 1, _pageCount),
              ),
              const SizedBox(height: AppSizes.s24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _finishing ? null : _next,
                  child: Text(
                    _isLast ? l10n.onboardingStart : l10n.onboardingNext,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(child: art),
              const SizedBox(height: AppSizes.s32),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.label,
  });

  final int count;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: AppSizes.s4),
              // The active dot is wider, not only darker.
              width: i == current ? AppSizes.s24 : AppSizes.s8,
              height: AppSizes.s8,
              decoration: BoxDecoration(
                color: i == current ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(AppSizes.s4),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Light-blue circle with a main icon and a small badge at the edge.
class _ArtCircle extends StatelessWidget {
  const _ArtCircle({required this.child, required this.badge});

  static const size = 200.0;

  final Widget child;
  final Widget badge;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size + AppSizes.s32,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: child,
        ),
        badge,
      ],
    ),
  );
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, color: AppColors.onPrimary, size: 28),
  );
}

class _ShadeArt extends StatelessWidget {
  const _ShadeArt();

  @override
  Widget build(BuildContext context) => const _ArtCircle(
    badge: Positioned(
      top: 0,
      right: 0,
      child: _RoundBadge(color: AppColors.sun, icon: Icons.wb_sunny_rounded),
    ),
    child: Icon(Icons.beach_access_rounded, size: 96, color: AppColors.primary),
  );
}

class _CoolPlaceArt extends StatelessWidget {
  const _CoolPlaceArt();

  @override
  Widget build(BuildContext context) => const _ArtCircle(
    badge: Positioned(
      bottom: 0,
      right: AppSizes.s16,
      child: _RoundBadge(
        color: AppColors.water,
        icon: Icons.water_drop_rounded,
      ),
    ),
    // "Miejsce chłodu": a snowflake in a house.
    child: Stack(
      alignment: Alignment(0, 0.35),
      children: [
        Icon(Icons.home_rounded, size: 112, color: AppColors.primary),
        Icon(Icons.ac_unit_rounded, size: 36, color: AppColors.onPrimary),
      ],
    ),
  );
}

class _LettersArt extends StatelessWidget {
  const _LettersArt();

  @override
  Widget build(BuildContext context) => const _ArtCircle(
    badge: Positioned(
      bottom: AppSizes.s8,
      right: 0,
      child: Row(
        children: [
          _LetterTile(letter: 'C', size: 36),
          SizedBox(width: AppSizes.s4),
          _LetterTile(letter: 'H', size: 36),
          SizedBox(width: AppSizes.s4),
          _LetterTile(letter: 'Ł', size: 36),
        ],
      ),
    ),
    child: _LetterTile(letter: 'L', size: 84),
  );
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(size / 6),
    ),
    child: Text(
      letter,
      // Decorative: the size is fixed so Senior mode does not overflow it.
      textScaler: TextScaler.noScaling,
      style: AppTextStyles.titleM.copyWith(
        color: AppColors.primaryContainer,
        fontSize: size * 0.55,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
