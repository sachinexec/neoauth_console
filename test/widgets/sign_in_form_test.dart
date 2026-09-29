import 'package:neoauth_console/core/auth/auth_providers.dart';
import 'package:neoauth_console/features/auth/sign_in_form.dart';
import 'package:neoauth/neoauth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keychain / Keystore writes go to an in-memory stub.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  Future<(FakeAdapter, List<NeoAuthUser>)> pump(WidgetTester tester) async {
    final adapter = FakeAdapter();
    final http = Dio(BaseOptions(baseUrl: 'http://auth.test'))..httpClientAdapter = adapter;
    final auth = NeoAuthClient(
      const NeoAuthConfig(issuer: 'http://auth.test', clientId: 'console'),
      http: http,
    );
    final signedIn = <NeoAuthUser>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [neoAuthClientProvider.overrideWithValue(auth)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SignInForm(onSignedIn: signedIn.add)),
          ),
        ),
      ),
    );
    return (adapter, signedIn);
  }

  testWidgets('phone: empty and non-E.164 numbers are rejected without a request', (tester) async {
    final (adapter, _) = await pump(tester);

    await tester.tap(find.byKey(const Key('signin.send')));
    await tester.pump();
    expect(find.text('Enter your phone number'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signin.phone')), '9876543210');
    await tester.tap(find.byKey(const Key('signin.send')));
    await tester.pump();
    expect(find.textContaining('Start with + and your country code'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signin.phone')), '+0123');
    await tester.tap(find.byKey(const Key('signin.send')));
    await tester.pump();
    expect(find.textContaining('international format'), findsOneWidget);

    expect(adapter.requests, isEmpty);
  });

  testWidgets('email: invalid addresses are rejected', (tester) async {
    final (adapter, _) = await pump(tester);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('signin.email')), 'not-an-email');
    await tester.tap(find.byKey(const Key('signin.send')));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('phone OTP: sends, counts down resend, maps a wrong code, then signs in', (tester) async {
    final (adapter, signedIn) = await pump(tester);
    adapter.replies.addAll([
      const FakeReply(400, {
        'error': 'insufficient_authorization',
        'error_description': 'Enter the code sent to +919999900001',
        'auth_session': 'as1',
        'next': 'otp',
        'retry_after': 30,
      }),
      const FakeReply(400, {
        'error': 'access_denied',
        'error_description': 'That code is not correct',
        'auth_session': 'as1',
      }),
      const FakeReply(200, {'authorization_code': 'code1'}),
      FakeReply(200, {
        'access_token': 'at',
        'expires_in': 600,
        'refresh_token': 'rt',
        'id_token': fakeJwt({'sub': 'user-1', 'phone_number': '+919999900001'}),
        'token_type': 'Bearer',
      }),
    ]);

    // Spaces are allowed while typing and stripped before sending.
    await tester.enterText(find.byKey(const Key('signin.phone')), '+91 99999 00001');
    await tester.tap(find.byKey(const Key('signin.send')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(adapter.requests.first.data, containsPair('phone_number', '+919999900001'));
    expect(find.text('Enter the code sent to +919999900001'), findsOneWidget);
    expect(find.text('Resend code in 30s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend code in 29s'), findsOneWidget);

    // Code validation, then a wrong code.
    await tester.tap(find.byKey(const Key('signin.verify')));
    await tester.pump();
    expect(find.text('Enter the code we sent you'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signin.code')), '000000');
    await tester.tap(find.byKey(const Key('signin.verify')));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.textContaining("That code isn't right"), findsOneWidget);
    expect(signedIn, isEmpty);

    await tester.enterText(find.byKey(const Key('signin.code')), '123456');
    await tester.tap(find.byKey(const Key('signin.verify')));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(signedIn.single.id, 'user-1');
    expect(adapter.requests.last.path, '/oauth/token');
  });

  testWidgets('rate limits show the wait time', (tester) async {
    final (adapter, _) = await pump(tester);
    adapter.replies.add(
      const FakeReply(429, {'error': 'slow_down', 'error_description': 'Too many attempts.', 'retry_after': 42}),
    );
    await tester.enterText(find.byKey(const Key('signin.phone')), '+919999900001');
    await tester.tap(find.byKey(const Key('signin.send')));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Too many attempts. Try again in 42 seconds.'), findsOneWidget);
  });

  test('validators', () {
    expect(validatePhone('+919876543210'), isNull);
    expect(validatePhone('+1 (415) 555-0100'), isNull);
    expect(validatePhone('+91'), isNotNull);
    expect(validateEmail('a@b.co'), isNull);
    expect(validateOtp('123456'), isNull);
    expect(validateOtp('12'), isNotNull);
  });
}
