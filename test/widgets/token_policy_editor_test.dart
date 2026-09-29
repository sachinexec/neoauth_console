import 'package:neoauth_console/features/apps/models/app_models.dart';
import 'package:neoauth_console/features/apps/widgets/token_policy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<TokenPolicyInput>> pump(
    WidgetTester tester, {
    TokenPolicyInput initial = TokenPolicyInput.empty,
    TokenPolicy inherited = TokenPolicy.defaults,
    bool allowInherit = false,
  }) async {
    final saved = <TokenPolicyInput>[];
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TokenPolicyEditor(
              initial: initial,
              inherited: inherited,
              allowInherit: allowInherit,
              onSave: (p) async {
                saved.add(p);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    return saved;
  }

  String summary(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('policy.summary'))).data!;

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(of: find.byKey(const Key('policy.save')), matching: find.byType(FilledButton)),
  );

  testWidgets('presets fill every field and can be saved', (tester) async {
    final saved = await pump(tester);
    expect(summary(tester), 'Result: Access 10 min · idle 30 d, max 90 d');
    expect(saveButton(tester).onPressed, isNull, reason: 'nothing changed yet');

    await tester.tap(find.byKey(const Key('preset.Sensitive')));
    await tester.pump();
    expect(summary(tester), 'Result: Access 5 min · idle 1 h, max 12 h · re-sign-in after 12 h');

    await tester.tap(find.byKey(const Key('preset.Stay signed in')));
    await tester.pump();
    expect(summary(tester), 'Result: Access 1 h · idle 90 d, max 400 d');

    await tester.tap(find.byKey(const Key('policy.save')));
    await tester.pumpAndSettle();
    expect(saved.single.toJson(), {
      'access_token_ttl': 3600,
      'refresh_token_mode': 'rotating',
      'refresh_idle_ttl': 90 * 86400,
      'refresh_absolute_ttl': 400 * 86400,
      'session_max_age': null,
    });
  });

  testWidgets('out-of-bounds values show an inline error and block saving', (tester) async {
    await pump(tester);
    final amount = find.descendant(of: find.byKey(const Key('policy.access')), matching: find.byType(TextField));
    await tester.enterText(amount, '2'); // 2 minutes
    await tester.pump();
    expect(find.text('Must be between 5 min and 1 h (public clients).'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(amount, '15');
    await tester.pump();
    expect(find.text('Must be between 5 min and 1 h (public clients).'), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('client overrides save only the overridden fields', (tester) async {
    const appPolicy = TokenPolicy(
      accessTokenTtl: 1800,
      refreshTokenMode: RefreshTokenMode.rotating,
      refreshIdleTtl: 90 * 86400,
      refreshAbsoluteTtl: 400 * 86400,
    );
    final saved = await pump(tester, inherited: appPolicy, allowInherit: true);
    expect(find.text('Inherits the app: 30 min'), findsOneWidget);

    await tester.tap(find.text('Access token lifetime').first);
    await tester.pump();
    final amount = find.descendant(of: find.byKey(const Key('policy.access')), matching: find.byType(TextField));
    await tester.enterText(amount, '5');
    await tester.pump();
    await tester.tap(find.byKey(const Key('policy.save')));
    await tester.pumpAndSettle();
    expect(saved.single.toJson(), {'access_token_ttl': 300});
  });
}
