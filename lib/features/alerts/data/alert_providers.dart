import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/clock.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/models.dart';

/// The strongest heat warning for Łódź from `/v1/alerts` (module D returns
/// only current ones), or null. Read for the city centre: alerts are issued
/// per county, so the user's exact position does not matter.
final activeAlertProvider = FutureProvider<Alert?>((ref) async {
  final all = await ref
      .watch(apiClientProvider)
      .getAlerts(lat: lodzCenter.latitude, lon: lodzCenter.longitude);
  // Demo scenarios are shown whatever their dates; real ones only while
  // valid (a cached or late answer may hold an expired warning).
  final demo = ref.watch(isDemoModeEffectiveProvider);
  final now = ref.read(clockProvider)();
  final alerts = demo ? all : all.where((a) => a.isActiveAt(now)).toList();
  if (alerts.isEmpty) return null;
  return alerts.reduce((a, b) => b.level > a.level ? b : a);
}, retry: noRetry);
