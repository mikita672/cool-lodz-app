import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/alert_screen.dart';
import '../features/auth/consents_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/cool_places/cool_places_screen.dart';
import '../features/cool_places/place_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_select_screen.dart';
import '../features/quest/quest_scan_screen.dart';
import '../features/quest/quest_tab_screen.dart';
import '../features/reports/report_screen.dart';
import '../features/route/route_plan_screen.dart';
import '../features/route/route_result_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/profile_tab_screen.dart';
import '../shared/debug/components_showcase.dart';
import 'app_shell.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Redirect rules for the start flow (onboarding → login → consents → map).
/// APP-07 overrides this provider; the scaffold lets every route through.
final routerRedirectProvider = Provider<GoRouterRedirect?>((ref) => null);

/// Something the router listens to, so redirects run again when the
/// start-flow state changes (set by APP-07).
final routerRefreshProvider = Provider<Listenable?>((ref) => null);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.map,
    redirect: ref.watch(routerRedirectProvider),
    refreshListenable: ref.watch(routerRefreshProvider),
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.consents, builder: (_, _) => const ConsentsScreen()),
      GoRoute(
        path: Routes.profileSelect,
        builder: (_, _) => const ProfileSelectScreen(),
      ),
      GoRoute(path: Routes.privacy, builder: (_, _) => const PrivacyScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.map, builder: (_, _) => const MapScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.coolPlaces,
                builder: (_, _) => const CoolPlacesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.quest,
                builder: (_, state) => QuestTabScreen(
                  initial: QuestSection.values.firstWhere(
                    (s) => s.name == state.uri.queryParameters['section'],
                    orElse: () => QuestSection.quest,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileTabScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes above the bottom bar.
      GoRoute(
        path: Routes.routePlan,
        builder: (_, _) => const RoutePlanScreen(),
      ),
      GoRoute(
        path: Routes.routeResult,
        builder: (_, _) => const RouteResultScreen(),
      ),
      GoRoute(
        path: Routes.placePattern,
        builder: (_, state) =>
            PlaceScreen(placeId: state.pathParameters['placeId']!),
      ),
      GoRoute(
        path: Routes.questScan,
        builder: (_, _) => const QuestScanScreen(),
      ),
      GoRoute(path: Routes.alert, builder: (_, _) => const AlertScreen()),
      GoRoute(path: Routes.report, builder: (_, _) => const ReportScreen()),
      GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
      if (kDebugMode)
        GoRoute(
          path: Routes.debugComponents,
          builder: (_, _) => const ComponentsShowcase(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
