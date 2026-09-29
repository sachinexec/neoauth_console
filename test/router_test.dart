import 'package:neoauth_console/core/config.dart';
import 'package:neoauth_console/core/router.dart';
import 'package:neoauth_console/features/auth/admin_me.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-out users are sent to sign-in', () {
    expect(authRedirect(signedIn: false, location: '/apps'), Routes.signIn);
    expect(authRedirect(signedIn: false, location: Routes.signIn), isNull);
  });

  test('signed-in users skip sign-in', () {
    expect(authRedirect(signedIn: true, location: Routes.signIn), Routes.overview);
    expect(authRedirect(signedIn: true, location: '/users/abc'), isNull);
  });

  test('routes', () {
    expect(Routes.client('app', 'app.web.X_y'), '/apps/app/clients/app.web.X_y');
    expect(Routes.auditFor(userId: 'u1'), '/audit?user_id=u1');
    expect(Routes.auditFor(), '/audit');
  });

  test('config comes from the env file, localhost reaching the host from the emulator', () {
    const dev = {'APP_ENV': 'dev', 'NEOAUTH_ISSUER': 'http://localhost:3000/', 'NEOAUTH_CLIENT_ID': 'neoauth-console.native.dev'};
    expect(AppConfig.fromEnvironment(isAndroid: true, env: dev).issuer, 'http://10.0.2.2:3000');
    final ios = AppConfig.fromEnvironment(isAndroid: false, env: dev);
    expect(ios.adminBaseUrl, 'http://localhost:3000/admin');
    expect(ios.clientId, 'neoauth-console.native.dev');
    expect(ios.isProd, isFalse);

    const prod = {'APP_ENV': 'prod', 'NEOAUTH_ISSUER': 'https://auth.example.com'};
    final p = AppConfig.fromEnvironment(isAndroid: true, env: prod, flavor: 'prod');
    expect(p.issuer, 'https://auth.example.com');
    expect(p.isProd, isTrue);
    expect(AppConfig.stripTrailingSlash('https://a.test/'), 'https://a.test');
  });

  test('roles', () {
    expect(AdminRole.viewer.canEdit, isFalse);
    expect(AdminRole.admin.canEdit, isTrue);
    expect(AdminRole.admin.isOwner, isFalse);
    expect(AdminRole.owner.atLeast(AdminRole.admin), isTrue);
    expect(AdminRole.parse('bogus'), AdminRole.viewer);
  });
}
