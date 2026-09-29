import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admins/admins_screen.dart';
import '../features/admins/audience_screen.dart';
import '../features/apps/screens/app_create_screen.dart';
import '../features/apps/screens/app_detail_screen.dart';
import '../features/apps/screens/apps_screen.dart';
import '../features/apps/screens/client_create_screen.dart';
import '../features/apps/screens/client_detail_screen.dart';
import '../features/audit/audit_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/overview/overview_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/users/user_detail_screen.dart';
import '../features/users/users_screen.dart';
import 'auth/auth_providers.dart';

/// For dialogs and sheets opened outside a widget (the step-up prompt).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

abstract final class Routes {
  static const signIn = '/sign-in';
  static const overview = '/overview';
  static const apps = '/apps';
  static const newApp = '/apps/new';
  static String app(String slug, {String? tab}) => '/apps/$slug${tab != null ? '?tab=$tab' : ''}';
  static String newClient(String slug) => '/apps/$slug/clients/new';
  static String client(String slug, String clientId) => '/apps/$slug/clients/${Uri.encodeComponent(clientId)}';
  static const users = '/users';
  static String user(String id) => '/users/$id';
  static const audit = '/audit';
  static String auditFor({String? userId}) =>
      userId == null ? audit : Uri(path: audit, queryParameters: {'user_id': userId}).toString();
  static const settings = '/settings';
  static const admins = '/settings/admins';
  static const audience = '/settings/audience';
}

/// Signed-out users go to sign-in; signed-in users never see it.
String? authRedirect({required bool signedIn, required String location}) {
  final atSignIn = location == Routes.signIn;
  if (!signedIn) return atSignIn ? null : Routes.signIn;
  if (atSignIn || location == '/') return Routes.overview;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(neoAuthClientProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.overview,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(signedIn: auth.isSignedIn, location: state.matchedLocation),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.overview),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.overview, builder: (_, _) => const OverviewScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.apps,
                builder: (_, _) => const AppsScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (_, _) => const AppCreateScreen()),
                  GoRoute(
                    path: ':slug',
                    builder: (_, s) =>
                        AppDetailScreen(slug: s.pathParameters['slug']!, initialTab: s.uri.queryParameters['tab']),
                    routes: [
                      GoRoute(
                        path: 'clients/new',
                        builder: (_, s) => ClientCreateScreen(slug: s.pathParameters['slug']!),
                      ),
                      GoRoute(
                        path: 'clients/:clientId',
                        builder: (_, s) => ClientDetailScreen(
                          slug: s.pathParameters['slug']!,
                          clientId: s.pathParameters['clientId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.users,
                builder: (_, _) => const UsersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => UserDetailScreen(userId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.audit,
                builder: (_, s) => AuditScreen(
                  key: ValueKey(s.uri.query),
                  initialUserId: s.uri.queryParameters['user_id'],
                  initialEvent: s.uri.queryParameters['event'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(path: 'admins', builder: (_, _) => const AdminsScreen()),
                  GoRoute(path: 'audience', builder: (_, _) => const AudienceScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
