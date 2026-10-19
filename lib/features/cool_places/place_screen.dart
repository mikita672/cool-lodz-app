import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import 'data/places_providers.dart';
import 'place_sheet.dart';

/// S08 as a full screen, for links to one place (`/place/:placeId`). Inside
/// the app S08 is a bottom sheet ([showPlaceSheet]).
class PlaceScreen extends ConsumerWidget {
  const PlaceScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(coolPlacesProvider);
    final Widget body;
    if (places.value case final list?) {
      final place = list.where((p) => p.id == placeId).firstOrNull;
      body = place == null
          ? Center(
              child: EmptyState(
                icon: Icons.wrong_location_rounded,
                title: l10n.placeNotFound,
              ),
            )
          : PlaceSheet(place: place);
    } else if (places.hasError) {
      body = Center(
        child: ErrorState(onRetry: () => ref.invalidate(coolPlacesProvider)),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(appBar: AppBar(), body: body);
  }
}
