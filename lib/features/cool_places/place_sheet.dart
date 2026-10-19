import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/place_sheet_content.dart';
import '../route/data/route_plan.dart';
import 'place_format.dart';

/// S08 Szczegóły miejsca as a bottom sheet (from the map, the list and the
/// quest). «Prowadź tam» opens S07 with this place as B; «Zgłoś problem»
/// opens S15.
Future<void> showPlaceSheet(BuildContext context, Place place) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaceSheet(place: place),
    );

class PlaceSheet extends ConsumerWidget {
  const PlaceSheet({super.key, required this.place, this.clock = DateTime.now});

  final Place place;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = clock();
    return SingleChildScrollView(
      child: PlaceSheetContent(
        name: place.title(l10n),
        subtitle: place.subtitle(l10n),
        status: place.statusAt(now),
        statusText: place.statusText(l10n, now),
        statusDetail: place.todayHours(l10n, now),
        amenities: place.uiAmenities,
        inQuest: place.questPlace,
        onNavigate: () => navigateToPlace(context, ref, place),
        onReport: () {
          final router = GoRouter.of(context);
          Navigator.of(context).maybePop();
          router.push(Routes.report, extra: place);
        },
      ),
    );
  }
}

/// «Prowadź tam»: S07 from my location to [place], leaving now.
void navigateToPlace(BuildContext context, WidgetRef ref, Place place) {
  final router = GoRouter.of(context);
  ref.read(routePlanProvider.notifier).navigateTo(place);
  ref.invalidate(routeRequestProvider);
  // Close the sheet if this is one.
  if (ModalRoute.of(context) is ModalBottomSheetRoute) {
    Navigator.of(context).pop();
  }
  router.push(Routes.routeResult);
}
