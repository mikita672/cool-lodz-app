import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/models/models.dart';

/// Places of one type from `/v1/places` (whole Łódź). Cool places are kept
/// on device by the API layer for use without network.
final placesOfTypeProvider = FutureProvider.family<List<Place>, PlaceType>(
  (ref, type) => ref.watch(apiClientProvider).getPlaces(types: {type}),
  retry: noRetry,
);

/// All cool places (S05, S06 search, S07 stops, S09).
final coolPlacesProvider = placesOfTypeProvider(PlaceType.cool);

/// Places by id across the types loaded so far (for route stops).
final placeByIdProvider = Provider<Map<String, Place>>((ref) {
  return {
    for (final type in [PlaceType.cool, PlaceType.water])
      for (final p
          in ref.watch(placesOfTypeProvider(type)).value ?? const <Place>[])
        p.id: p,
  };
});
