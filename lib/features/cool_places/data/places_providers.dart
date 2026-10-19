import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/models/models.dart';

/// All cool places (S05, S06 search, S09). Kept on device by the API layer
/// for use without network.
final coolPlacesProvider = FutureProvider<List<Place>>(
  (ref) => ref.watch(apiClientProvider).getPlaces(types: {PlaceType.cool}),
);
