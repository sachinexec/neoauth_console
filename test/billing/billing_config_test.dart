import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth_console/core/config.dart';
import 'package:neoauth_console/core/router.dart';

void main() {
  const base = {'APP_ENV': 'dev', 'NEOAUTH_ISSUER': 'https://auth.test', 'NEOAUTH_CLIENT_ID': 'console'};

  group('billing config', () {
    test('comes from BILLING_URL in the env file, without a trailing slash', () {
      final c = AppConfig.fromEnvironment(
        isAndroid: false,
        env: {...base, 'BILLING_URL': 'https://billing.example.com/'},
      );
      expect(c.billingUrl, 'https://billing.example.com');
      expect(c.billingAdminBaseUrl, 'https://billing.example.com/admin/v1');
      expect(c.billingConfigured, isTrue);
      expect(c.billingResource, isEmpty);
    });

    test('absent means no billing section', () {
      final c = AppConfig.fromEnvironment(isAndroid: false, env: base);
      expect(c.billingConfigured, isFalse);
      expect(c.billingAdminBaseUrl, isNull);
    });

    test('localhost reaches the host from the Android emulator, like the issuer', () {
      final env = {...base, 'BILLING_URL': 'http://localhost:3100'};
      expect(AppConfig.fromEnvironment(isAndroid: true, env: env).billingUrl, 'http://10.0.2.2:3100');
      expect(AppConfig.fromEnvironment(isAndroid: false, env: env).billingUrl, 'http://localhost:3100');
      expect(AppConfig.fromEnvironment(isAndroid: true, env: env).billingConfigured, isTrue);
    });

    test('admin tokens are never sent over plain http to a remote host', () {
      for (final url in [
        'http://billing.example.com',
        'ftp://billing.example.com',
        'billing.example.com',
        'http://192.168.1.5:3100',
      ]) {
        final c = AppConfig.fromEnvironment(isAndroid: false, env: {...base, 'BILLING_URL': url});
        expect(c.billingAdminBaseUrl, isNull, reason: url);
        expect(c.billingConfigured, isFalse, reason: url);
      }
    });

    test('an optional token resource', () {
      final c = AppConfig.fromEnvironment(
        isAndroid: false,
        env: {...base, 'BILLING_URL': 'https://b.test', 'BILLING_RESOURCE': ' https://billing-admin.test '},
      );
      expect(c.billingResource, 'https://billing-admin.test');
    });

    test('the existing settings are unchanged', () {
      final c = AppConfig.fromEnvironment(isAndroid: false, env: base);
      expect(c.adminBaseUrl, 'https://auth.test/admin');
      expect(c.clientId, 'console');
    });
  });

  test('billing routes', () {
    expect(Routes.billing, '/billing');
    expect(Routes.billingApp('notes'), '/billing/notes');
    expect(Routes.billingApp('notes', tab: 'catalog'), '/billing/notes?tab=catalog');
    expect(Routes.newBillingApp, '/billing/new');
    expect(Routes.billingAudit, '/billing/audit');
  });
}
