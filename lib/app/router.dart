import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/models.dart';
import '../features/alerts/alert_screen.dart';
import '../features/auth/consents_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/start_screen.dart';
import '../features/cool_places/cool_places_screen.dart';
import '../features/cool_places/place_screen.dart';
import '../features/cool_walk/cool_walk_screen.dart';
import '../features/day_plan/day_plan_screen.dart';
import '../features/heat_guard/heat_check_screen.dart';
import '../features/heat_guard/heat_guard_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_select_screen.dart';
import '../features/quest/quest_scan_screen.dart';
import '../features/quest/quest_tab_screen.dart';
import '../features/reports/report_screen.dart';
import '../features/route/route_plan_screen.dart';
import '../features/route/route_result_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/consents_settings_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/profile_tab_screen.dart';
import '../features/shop/shop_screen.dart';
import '../features/symptoms/symptom_check_screen.dart';
import '../shared/debug/components_showcase.dart';
import 'app_shell.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Redirect rules for the start flow (onboarding → login → consents → map).
/// main.dart overrides it with `startFlowRouterOverrides`
/// (features/auth/start_flow.dart); without overrides (widget tests) every
/// route is let through.
/// The router is built once: re-checks must come from [routerRefreshProvider],
/// never from rebuilding the router (that would drop the navigation stack).
final routerRedirectProvider = Provider<GoRouterRedirect?>((ref) => null);

/// Something the router listens to, so redirects run again when the
/// start-flow state changes (also overridden by `startFlowRouterOverrides`).
final routerRefreshProvider = Provider<Listenable?>((ref) => null);

/// Whether app screens (beyond the start flow) are reachable now. A push
/// tapped at cold start waits for this (overridden by
/// `startFlowRouterOverrides`; open by default).
final routerReadyProvider = Provider<bool Function()>(
  (ref) =>
      () => true,
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.map,
    redirect: ref.read(routerRedirectProvider),
    refreshListenable: ref.read(routerRefreshProvider),
    routes: [
      GoRoute(path: Routes.start, builder: (_, _) => const StartScreen()),
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
              GoRoute(
                path: Routes.map,
                builder: (_, _) => const MapScreen(),
                routes: [
                  GoRoute(
                    path: 'alert',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AlertScreen(),
                  ),
                ],
              ),
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
                routes: [
                  GoRoute(
                    path: 'scan',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const QuestScanScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileTabScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'consents',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const ConsentsSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'heat-guard',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const HeatGuardScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes above the bottom bar. Inside the app open them with
      // context.push so system back returns to where the user came from.
      GoRoute(
        path: Routes.routePlan,
        builder: (_, _) => const RoutePlanScreen(),
        routes: [
          GoRoute(path: 'result', builder: (_, _) => const RouteResultScreen()),
        ],
      ),
      GoRoute(path: Routes.shop, builder: (_, _) => const ShopScreen()),
      GoRoute(path: Routes.coolWalk, builder: (_, _) => const CoolWalkScreen()),
      GoRoute(path: Routes.dayPlan, builder: (_, _) => const DayPlanScreen()),
      GoRoute(
        path: Routes.guide,
        builder: (_, _) => const OnboardingScreen(replay: true),
      ),
      GoRoute(
        path: Routes.symptoms,
        builder: (_, _) => const SymptomCheckScreen(),
      ),
      GoRoute(
        path: Routes.heatCheck,
        builder: (_, state) => HeatCheckScreen(test: state.extra == true),
      ),
      GoRoute(
        path: Routes.placePattern,
        builder: (_, state) =>
            PlaceScreen(placeId: state.pathParameters['placeId']!),
      ),
      GoRoute(
        path: Routes.report,
        builder: (_, state) => ReportScreen(
          place: state.extra is Place ? state.extra! as Place : null,
        ),
      ),
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
