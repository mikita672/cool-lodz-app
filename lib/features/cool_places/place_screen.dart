import 'package:flutter/material.dart';

import '../../shared/widgets/placeholder_screen.dart';

/// S08 Szczegóły miejsca. Placeholder from APP-01; the feature ticket replaces it.
class PlaceScreen extends StatelessWidget {
  const PlaceScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(code: 'S08', title: 'Szczegóły miejsca');
}
