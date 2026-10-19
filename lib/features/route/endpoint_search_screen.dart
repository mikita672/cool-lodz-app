import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_icons.dart';
import '../cool_places/data/places_providers.dart';
import 'data/address_search.dart';
import 'data/route_plan.dart';

/// Search for a route endpoint (S06 «Skąd» / «Dokąd»): «Moja lokalizacja»,
/// cool places (searched on the device) and addresses in Łódź (Nominatim).
/// Pops with the chosen [RouteEndpoint].
class EndpointSearchScreen extends ConsumerStatefulWidget {
  const EndpointSearchScreen({
    super.key,
    required this.title,
    this.allowMyLocation = false,
  });

  final String title;
  final bool allowMyLocation;

  /// Waits this long after the last key press before asking Nominatim.
  static const debounce = Duration(milliseconds: 1000);

  static Future<RouteEndpoint?> open(
    BuildContext context, {
    required String title,
    bool allowMyLocation = false,
  }) => Navigator.of(context).push<RouteEndpoint>(
    MaterialPageRoute(
      builder: (_) =>
          EndpointSearchScreen(title: title, allowMyLocation: allowMyLocation),
    ),
  );

  @override
  ConsumerState<EndpointSearchScreen> createState() =>
      _EndpointSearchScreenState();
}

enum _AddressState { idle, tooShort, loading, done, error }

class _EndpointSearchScreenState extends ConsumerState<EndpointSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  var _addressState = _AddressState.idle;
  List<RoutePoint> _addresses = const [];
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() => _query = text.trim());
    _debounce?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      setState(() => _addressState = _AddressState.idle);
      return;
    }
    if (q.length < 3) {
      setState(() => _addressState = _AddressState.tooShort);
      return;
    }
    _debounce = Timer(EndpointSearchScreen.debounce, () => _searchAddresses(q));
  }

  Future<void> _searchAddresses(String q) async {
    final request = ++_request;
    setState(() => _addressState = _AddressState.loading);
    try {
      final results = await ref.read(addressSearchProvider).search(q);
      if (!mounted || request != _request) return;
      setState(() {
        _addresses = results;
        _addressState = _AddressState.done;
      });
    } catch (e) {
      debugPrint('Address search failed: $e');
      if (!mounted || request != _request) return;
      setState(() => _addressState = _AddressState.error);
    }
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final places = ref.watch(coolPlacesProvider).value ?? const <Place>[];
    final matches = matchPlaces(places, _query);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              0,
              AppSizes.screenPadding,
              AppSizes.s8,
            ),
            child: TextField(
              key: const Key('endpoint-search-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: l10n.routeSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.routeSearchClear,
                        onPressed: _clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (widget.allowMyLocation)
                  ListTile(
                    key: const Key('endpoint-my-location'),
                    leading: const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(l10n.routeMyLocation),
                    onTap: () => Navigator.of(context).pop(const MyLocation()),
                  ),
                if (matches.isNotEmpty) ...[
                  _Header(l10n.routeSearchPlaces),
                  for (final place in matches)
                    ListTile(
                      leading: const CoolPlaceIcon(color: AppColors.primary),
                      title: Text(place.name ?? place.id),
                      subtitle: place.address == null
                          ? null
                          : Text(
                              place.address!,
                              style: theme.textTheme.bodySmall,
                            ),
                      onTap: () => Navigator.of(context).pop(
                        PointEndpoint(
                          RoutePoint(
                            lat: place.lat,
                            lon: place.lon,
                            label: place.name,
                          ),
                          place: place,
                        ),
                      ),
                    ),
                ],
                if (_addressState != _AddressState.idle) ...[
                  _Header(l10n.routeSearchAddresses),
                  ..._addressItems(l10n, theme),
                ],
                if (_query.isNotEmpty &&
                    matches.isEmpty &&
                    _addressState == _AddressState.done &&
                    _addresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.screenPadding),
                    child: Text(
                      l10n.routeSearchNoResults,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.s8),
            child: Text(
              l10n.routeSearchAttribution,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _addressItems(AppLocalizations l10n, ThemeData theme) {
    Widget note(String text) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.screenPadding,
        vertical: AppSizes.s8,
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
    return switch (_addressState) {
      _AddressState.idle => const [],
      _AddressState.tooShort => [note(l10n.routeSearchTypeMore)],
      _AddressState.loading => const [
        Padding(
          padding: EdgeInsets.all(AppSizes.s16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      _AddressState.error => [note(l10n.routeSearchError)],
      _AddressState.done =>
        _addresses.isEmpty
            ? [note(l10n.routeSearchNoResults)]
            : [
                for (final point in _addresses)
                  ListTile(
                    leading: const Icon(
                      Icons.place_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                    title: Text(point.label ?? ''),
                    onTap: () =>
                        Navigator.of(context).pop(PointEndpoint(point)),
                  ),
              ],
    };
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      AppSizes.s16,
      AppSizes.screenPadding,
      AppSizes.s4,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    ),
  );
}

/// Cool places whose name or address contains [query], ignoring case and
/// Polish diacritics. An empty query lists all, by name.
List<Place> matchPlaces(List<Place> places, String query) {
  final q = foldPolish(query.trim());
  final result = [
    for (final p in places)
      if (q.isEmpty ||
          foldPolish(p.name ?? '').contains(q) ||
          foldPolish(p.address ?? '').contains(q))
        p,
  ];
  result.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
  return result;
}

const _fold = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
};

/// Lower case without Polish diacritics: «Łódź» → «lodz».
String foldPolish(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    out.write(_fold[ch] ?? ch);
  }
  return out.toString();
}
