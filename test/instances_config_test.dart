import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth_console/core/config.dart';

void main() {
  const base = {'APP_ENV': 'dev', 'NEOAUTH_ISSUER': 'https://auth.example.com', 'NEOAUTH_CLIENT_ID': 'console'};

  AppConfig parse(String instances, {bool android = false}) =>
      AppConfig.fromEnvironment(isAndroid: android, env: {...base, 'NEOAUTH_INSTANCES': instances});

  group('NEOAUTH_INSTANCES', () {
    test('absent or blank: only the primary instance', () {
      for (final c in [AppConfig.fromEnvironment(isAndroid: false, env: base), parse('   ')]) {
        expect(c.hasExtraInstances, isFalse);
        expect(c.instances, hasLength(1));
        final primary = c.primaryInstance;
        expect(primary.isPrimary, isTrue);
        expect(primary.label, 'Primary');
        expect(primary.issuer, 'https://auth.example.com');
        expect(primary.clientId, 'console');
        expect(primary.adminBaseUrl, c.adminBaseUrl);
        // The SDK default key, so sessions stored before instances existed survive.
        expect(primary.storageKey, isNull);
      }
    });

    test('valid entries, in order, after the primary one', () {
      final c = parse(
        ' Partner | https://auth.partner.example.com/ | console.partner ,'
        'Staging|https://auth.example.com/staging|console.staging',
      );
      expect(c.hasExtraInstances, isTrue);
      expect(c.instances.map((i) => i.label), ['Primary', 'Partner', 'Staging']);
      final partner = c.extraInstances.first;
      expect(partner.isPrimary, isFalse);
      expect(partner.issuer, 'https://auth.partner.example.com');
      expect(partner.clientId, 'console.partner');
      expect(partner.adminBaseUrl, 'https://auth.partner.example.com/admin');
      expect(c.extraInstances.last.adminBaseUrl, 'https://auth.example.com/staging/admin');
      // Every instance stores its session under its own key.
      final keys = c.extraInstances.map((i) => i.storageKey).toSet();
      expect(keys, hasLength(2));
      expect(keys, isNot(contains(null)));
    });

    test('instanceById finds an instance, or falls back to the primary one', () {
      final c = parse('Partner|https://auth.partner.example.com|console.partner');
      expect(c.instanceById('https://auth.partner.example.com').label, 'Partner');
      expect(c.instanceById(ConsoleInstance.primaryId).isPrimary, isTrue);
      expect(c.instanceById(null).isPrimary, isTrue);
      expect(c.instanceById('https://gone.example.com').isPrimary, isTrue);
    });

    test('localhost reaches the host from the Android emulator; the id stays the configured issuer', () {
      final c = parse('Local|http://localhost:3001|console.local', android: true);
      final local = c.extraInstances.single;
      expect(local.issuer, 'http://10.0.2.2:3001');
      expect(local.id, 'http://localhost:3001');
    });

    test('malformed values fail with the entry and the problem', () {
      final cases = {
        'Partner|https://auth.partner.example.com': 'entry 1',
        'Partner|https://a.example.com|c|extra': 'not 3',
        '|https://a.example.com|c': 'label is empty',
        'Partner|https://a.example.com|c,partner|https://b.example.com|d': 'used twice',
        'Primary|https://a.example.com|c': 'used twice',
        'Partner|auth.partner.example.com|c': 'not an absolute issuer URL',
        'Partner|http://auth.partner.example.com|c': 'must use https',
        'Partner|https://a.example.com?x=1|c': 'not an absolute issuer URL',
        'Partner|https://a.example.com|': 'client ID',
        'Partner|https://a.example.com|two words': 'client ID',
        'Partner|https://auth.example.com/|c': 'already configured',
        'A|https://a.example.com|c,B|https://a.example.com|d': 'entry 2',
        'Partner|https://a.example.com|c,': 'entry 2',
      };
      cases.forEach((value, problem) {
        expect(
          () => parse(value),
          throwsA(
            isA<FormatException>()
                .having((e) => e.message, 'message', contains('NEOAUTH_INSTANCES'))
                .having((e) => e.message, 'message', contains(problem)),
          ),
          reason: value,
        );
      });
    });
  });
}
