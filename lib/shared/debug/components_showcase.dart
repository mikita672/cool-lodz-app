import 'package:flutter/material.dart';

import '../../app/senior_mode.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_toast.dart';
import '../widgets/badge_tile.dart';
import '../widgets/badge_unlocked_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/heat_banner.dart';
import '../widgets/layer_filter_chip.dart';
import '../widgets/leaderboard_row.dart';
import '../widgets/letter_tile.dart';
import '../widgets/map_pin.dart';
import '../widgets/offline_banner.dart';
import '../widgets/place_list_item.dart';
import '../widgets/place_sheet_content.dart';
import '../widgets/route_variant_card.dart';
import '../widgets/search_field.dart';
import '../widgets/shade_bar.dart';
import '../widgets/skeleton.dart';

/// Debug-only page with every design-system component in all variants.
/// The switch previews Senior mode locally (theme + text ×1.25) without
/// changing the app setting. Sample place names and numbers are demo data.
class ComponentsShowcase extends StatefulWidget {
  const ComponentsShowcase({super.key, this.initialSenior = false});

  final bool initialSenior;

  @override
  State<ComponentsShowcase> createState() => _ComponentsShowcaseState();
}

class _ComponentsShowcaseState extends State<ComponentsShowcase> {
  late bool _senior = widget.initialSenior;
  var _route = RouteVariant.shaded;
  var _shadeLayer = true;
  var _greenLayer = false;
  var _loading = false;

  void _tap() => showAppToast(context, 'Tap');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    return Theme(
      data: AppTheme.light(senior: _senior),
      child: MediaQuery(
        data: _senior
            ? media.copyWith(textScaler: SeniorTextScaler(media.textScaler))
            : media,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.dsShowcaseTitle)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.dsShowcaseSenior),
                  value: _senior,
                  onChanged: (v) => setState(() => _senior = v),
                ),
                ..._sections(context, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, AppLocalizations l10n) => [
    _Section('Icons', [
      Wrap(
        spacing: AppSizes.s16,
        runSpacing: AppSizes.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CoolPlaceIcon(size: 32, semanticLabel: l10n.dsIconCoolPlace),
          WaterTapIcon(size: 32, semanticLabel: l10n.dsIconWaterTap),
          QuestLetterIcon(size: 32, semanticLabel: l10n.dsIconQuestLetter),
        ],
      ),
    ]),
    _Section('AppButton', [
      AppButton(label: l10n.dsNavigateThere, onPressed: _tap, expand: true),
      AppButton(
        label: l10n.dsNavigateThere,
        icon: Icons.navigation_rounded,
        onPressed: _tap,
        expand: true,
      ),
      AppButton(
        label: l10n.dsReportProblem,
        icon: Icons.flag_rounded,
        variant: AppButtonVariant.secondary,
        onPressed: _tap,
        expand: true,
      ),
      AppButton(
        label: l10n.dsRetry,
        variant: AppButtonVariant.text,
        onPressed: _tap,
      ),
      AppButton(
        label: l10n.dsNavigateThere,
        loading: _loading,
        onPressed: () => setState(() => _loading = true),
        expand: true,
      ),
      AppButton(label: l10n.dsNavigateThere, onPressed: null, expand: true),
    ]),
    _Section('LayerFilterChip', [
      Wrap(
        spacing: AppSizes.s8,
        children: [
          LayerFilterChip(
            label: 'Cień',
            icon: Icons.beach_access_rounded,
            selected: _shadeLayer,
            onSelected: (v) => setState(() => _shadeLayer = v),
          ),
          LayerFilterChip(
            label: 'Zieleń',
            icon: Icons.park_rounded,
            selected: _greenLayer,
            onSelected: (v) => setState(() => _greenLayer = v),
          ),
        ],
      ),
    ]),
    _Section('SearchField', [SearchField(onTap: _tap)]),
    const _Section('ShadeBar', [
      ShadeBar(percent: 31),
      ShadeBar(percent: 54),
      ShadeBar(percent: 72),
    ]),
    _Section('RouteVariantCard', [
      for (final (variant, min, km, shade, extra, cool, water) in const [
        (RouteVariant.shortest, 22, 1.8, 31, 0, 0, 1),
        (RouteVariant.shaded, 26, 2.1, 72, 4, 2, 1),
        (RouteVariant.compromise, 24, 1.9, 54, 2, 1, 1),
      ])
        RouteVariantCard(
          variant: variant,
          minutes: min,
          distanceKm: km,
          shadePercent: shade,
          extraMinutes: extra,
          coolStops: cool,
          waterStops: water,
          selected: _route == variant,
          onTap: () => setState(() => _route = variant),
        ),
    ]),
    _Section('HeatBanner', [
      HeatBanner(level: 1, subtitle: 'IMGW · do 20:00', onTap: _tap),
      HeatBanner(level: 2, subtitle: 'IMGW · do 20:00', onTap: _tap),
      HeatBanner(
        level: 3,
        subtitle: 'Tryb upału włączony · IMGW, do 20:00',
        onTap: _tap,
      ),
    ]),
    _Section('PlaceListItem', [
      Card(
        child: Column(
          children: [
            PlaceListItem(
              name: 'Biblioteka Miejska, Filia Śródmieście',
              subtitle: 'Biblioteka · 350 m',
              status: PlaceOpenStatus.open,
              statusText: '${l10n.dsOpenNow} · do 19:00',
              onTap: _tap,
            ),
            const Divider(),
            PlaceListItem(
              name: 'Ogród Botaniczny — Palmiarnia',
              subtitle: 'Palmiarnia · 1,2 km',
              status: PlaceOpenStatus.closed,
              statusText: l10n.dsClosedOpensAt('10:00'),
              onTap: _tap,
            ),
            const Divider(),
            PlaceListItem(
              name: 'EC1 Łódź — Miasto Kultury',
              subtitle: 'Centrum kultury · 650 m',
              status: PlaceOpenStatus.open,
              statusText: '${l10n.dsOpenNow} · do 19:00',
              inQuest: true,
              onTap: _tap,
            ),
          ],
        ),
      ),
    ]),
    _Section('PlaceSheetContent', [
      _SheetFrame(
        PlaceSheetContent(
          name: 'Manufaktura',
          subtitle: 'Centrum handlowe · ul. Drewnowska 58',
          status: PlaceOpenStatus.open,
          statusText: l10n.dsOpenNow,
          statusDetail: 'Dziś 10:00–22:00',
          amenities: PlaceAmenity.values,
          onNavigate: _tap,
          onReport: _tap,
        ),
      ),
      _SheetFrame(
        PlaceSheetContent(
          name: 'Palmiarnia',
          subtitle: 'Ogród zimowy · al. Piłsudskiego 61',
          status: PlaceOpenStatus.closed,
          statusText: l10n.dsClosedOpensAt('10:00'),
          statusDetail: 'Dziś 10:00–18:00',
          amenities: const [PlaceAmenity.airConditioning, PlaceAmenity.toilet],
          onNavigate: _tap,
          onReport: _tap,
        ),
      ),
      _SheetFrame(
        PlaceSheetContent(
          name: 'EC1 Łódź — Miasto Kultury',
          subtitle: 'Centrum kultury · ul. Targowa 1/3',
          status: PlaceOpenStatus.open,
          statusText: l10n.dsOpenNow,
          statusDetail: 'Dziś 10:00–19:00',
          amenities: PlaceAmenity.values,
          inQuest: true,
          onNavigate: _tap,
          onReport: _tap,
        ),
      ),
    ]),
    _Section('LetterTile', [
      Wrap(
        spacing: AppSizes.s8,
        runSpacing: AppSizes.s8,
        children: [
          for (final letter in ['C', 'H', 'Ł', null, 'D', null, null])
            LetterTile(letter: letter),
        ],
      ),
    ]),
    const _Section('BadgeTile', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: BadgeTile(
              icon: Icons.directions_walk_rounded,
              name: 'Pierwszy krok',
              earned: true,
              caption: 'Zdobyta 12.10',
            ),
          ),
          Expanded(
            child: BadgeTile(
              icon: Icons.park_rounded,
              name: 'Łowca parków',
              earned: true,
              color: AppColors.green,
              caption: 'Zdobyta 14.10',
            ),
          ),
          Expanded(
            child: BadgeTile(
              icon: Icons.beach_access_rounded,
              name: 'Cienista dziesiątka',
              earned: false,
              caption: '10 tras z cieniem ≥ 60%',
            ),
          ),
        ],
      ),
    ]),
    const _Section('LeaderboardRow', [
      LeaderboardRow(rank: 1, name: 'Śródmieście', points: 12480),
      LeaderboardRow(rank: 14, name: 'cienista_ania', points: 420, own: true),
    ]),
    _Section('EmptyState', [
      EmptyState(
        icon: Icons.home_rounded,
        title: 'Brak otwartych miejsc w pobliżu',
        message: 'Spróbuj później albo zobacz wszystkie miejsca chłodu.',
        actionLabel: 'Pokaż wszystkie',
        onAction: _tap,
      ),
    ]),
    _Section('ErrorState', [
      ErrorState(onRetry: _tap),
      ErrorState(
        title: 'Brak połączenia z serwerem',
        message: 'Pokazujemy ostatnie zapisane dane.',
        onRetry: _tap,
      ),
    ]),
    const _Section('Skeleton', [
      SkeletonCard(),
      SkeletonBox(height: 120, radius: AppSizes.radiusCard),
    ]),
    _Section('Toast', [
      for (final (kind, text) in const [
        (ToastKind.success, '+50 pkt · litera Ł odkryta'),
        (ToastKind.warning, 'Kod nieważny'),
        (ToastKind.info, 'Trasa zapisana'),
      ]) ...[
        Container(
          padding: const EdgeInsets.all(AppSizes.s12),
          decoration: BoxDecoration(
            color: AppColors.onSurface,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          child: AppToastContent(message: text, kind: kind),
        ),
      ],
      Builder(
        builder: (context) => AppButton(
          label: 'showAppToast',
          variant: AppButtonVariant.text,
          onPressed: () =>
              showAppToast(context, 'Trasa zapisana', kind: ToastKind.success),
        ),
      ),
    ]),
    const _Section('OfflineBanner', [OfflineBanner()]),
    _Section('BadgeUnlockedDialog', [
      Builder(
        builder: (context) => AppButton(
          label: l10n.dsBadgeNew,
          variant: AppButtonVariant.secondary,
          expand: true,
          onPressed: () => showBadgeUnlockedDialog(
            context,
            icon: Icons.home_rounded,
            name: 'Strażnik chłodu',
            description:
                'Odwiedziłeś 5 różnych miejsc chłodu. '
                'Tak trzymaj w upalne dni.',
            points: 30,
          ),
        ),
      ),
    ]),
    _Section('MapPin', [
      Wrap(
        spacing: AppSizes.s8,
        children: [
          MapPin(type: MapPinType.cool, onTap: _tap),
          MapPin(type: MapPinType.water, onTap: _tap),
          MapPin(type: MapPinType.bench, onTap: _tap),
          MapPin(type: MapPinType.questLetter, letter: 'Ł', onTap: _tap),
        ],
      ),
    ]),
  ];
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.titleM),
          const SizedBox(height: AppSizes.s8),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: AppSizes.s8),
            child,
          ],
        ],
      ),
    );
  }
}

/// Mimics the bottom sheet surface around [PlaceSheetContent].
class _SheetFrame extends StatelessWidget {
  const _SheetFrame(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: AppSizes.s24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusSheet),
        ),
      ),
      child: child,
    );
  }
}
