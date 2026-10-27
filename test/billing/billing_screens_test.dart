import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth_console/core/api/api_client.dart';
import 'package:neoauth_console/core/config.dart';
import 'package:neoauth_console/shared/widgets/common.dart' show ReadOnlyBanner;
import 'package:neoauth_console/features/billing/billing_models.dart';
import 'package:neoauth_console/features/billing/screens/billing_app_create_screen.dart';
import 'package:neoauth_console/features/billing/screens/billing_apps_screen.dart';
import 'package:neoauth_console/features/billing/screens/billing_audit_screen.dart';
import 'package:neoauth_console/features/billing/widgets/billing_catalog_tab.dart';
import 'package:neoauth_console/features/billing/widgets/billing_customers_tab.dart';
import 'package:neoauth_console/features/billing/widgets/billing_developers_tab.dart';
import 'package:neoauth_console/features/billing/widgets/billing_events_tab.dart';
import 'package:neoauth_console/features/billing/widgets/billing_settings_tab.dart';

import '../helpers.dart';
import 'billing_harness.dart';

const _pem = '-----BEGIN PRIVATE KEY-----\nTOP-SECRET-KEY-MATERIAL\n-----END PRIVATE KEY-----';

void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeBilling server,
    Widget child, {
    StepUpHandler? onStepUp,
    AppConfig? config,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(billingOverrides(server, onStepUp: onStepUp, config: config), Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  /// While a dialog is open, only its widgets can be tapped.
  Finder scoped(Finder f) =>
      find.byType(AlertDialog).evaluate().isEmpty ? f : find.descendant(of: find.byType(AlertDialog).last, matching: f);

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = scoped(find.text(text));
    await tester.ensureVisible(f.first);
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.enterText(find.byKey(key), text);
    await tester.pump();
  }

  group('apps list', () {
    testWidgets('without a billing URL: explains instead of failing', (tester) async {
      final server = FakeBilling();
      await tester.pumpWidget(
        host(billingOverrides(server, config: testConfig(billingUrl: '')), const BillingAppsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Billing is not set up'), findsOneWidget);
      expect(server.calls, isEmpty);
    });

    testWidgets('plain http to a remote host is refused as not set up', (tester) async {
      final server = FakeBilling();
      await tester.pumpWidget(
        host(
          billingOverrides(server, config: testConfig(billingUrl: 'http://billing.example.com')),
          const BillingAppsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Billing is not set up'), findsOneWidget);
      expect(server.calls, isEmpty);
    });

    testWidgets('owner sees apps, store state, New app and the audit log', (tester) async {
      final server = FakeBilling(role: 'owner')
        ..apps = [appJson(appleSandbox: true), appJson(slug: 'tasks', name: 'Tasks', apple: false, google: true)];
      await tester.pumpWidget(host(billingOverrides(server), const BillingAppsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Apple · sandbox on'), findsOneWidget);
      expect(find.text('Google not set up'), findsOneWidget);
      expect(find.text('New app'), findsOneWidget);
      expect(find.byTooltip('Billing audit log'), findsOneWidget);
    });

    testWidgets('viewer: no New app, no audit log', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await tester.pumpWidget(host(billingOverrides(server), const BillingAppsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('New app'), findsNothing);
      expect(find.byTooltip('Billing audit log'), findsNothing);
    });

    testWidgets('admin: audit log yes, New app no', (tester) async {
      final server = FakeBilling(role: 'admin');
      await tester.pumpWidget(host(billingOverrides(server), const BillingAppsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('New app'), findsNothing);
      expect(find.byTooltip('Billing audit log'), findsOneWidget);
    });

    testWidgets('an account with no billing role is told so, and sees no apps', (tester) async {
      final server = FakeBilling()
        ..failures['GET /me'] = const FakeReply(403, {
          'statusCode': 403,
          'error': 'Forbidden',
          'message': 'requires the viewer role',
        });
      await tester.pumpWidget(host(billingOverrides(server), const BillingAppsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No billing access'), findsOneWidget);
      expect(find.text('admin-1'), findsOneWidget);
      expect(server.calls, ['GET /me']);
    });
  });

  group('create app', () {
    testWidgets('owners only', (tester) async {
      for (final role in ['viewer', 'admin']) {
        final server = FakeBilling(role: role);
        await tester.pumpWidget(host(billingOverrides(server), const BillingAppCreateScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Owners only'), findsOneWidget, reason: role);
        expect(find.byKey(const Key('billing.app.slug')), findsNothing, reason: role);
      }
    });

    testWidgets('invalid input sends nothing; valid input is created', (tester) async {
      final server = FakeBilling(role: 'owner');
      await tester.binding.setSurfaceSize(const Size(900, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(hostRouter(billingOverrides(server), const BillingAppCreateScreen()));
      await tester.pumpAndSettle();
      await tapText(tester, 'Create app');
      expect(find.textContaining('lowercase letters'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);

      await type(tester, const Key('billing.app.slug'), 'Bad Slug');
      await type(tester, const Key('billing.app.name'), 'Notes 2');
      await type(tester, const Key('billing.app.audience'), 'https://api.notes2.test');
      await tapText(tester, 'Create app');
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);

      await type(tester, const Key('billing.app.slug'), 'notes-2');
      await tapText(tester, 'Create app');
      expect(server.bodies['POST /apps'], containsPair('slug', 'notes-2'));
      expect(server.bodies['POST /apps'], containsPair('require_account_binding', true));
      expect(find.text('detail notes-2'), findsOneWidget, reason: 'goes to the new app');
    });
  });

  group('settings and credentials', () {
    BillingApp app() => BillingApp.fromJson(appJson(google: true));

    testWidgets('viewer: identifiers visible, nothing editable, no secret text anywhere', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await pump(tester, server, BillingSettingsTab(app: app()));
      expect(find.text('com.example.notes'), findsWidgets);
      expect(find.text('ABC123DEFG'), findsOneWidget);
      expect(find.text('Stored encrypted. Not shown.'), findsNWidgets(2));
      expect(find.text('Set credentials'), findsNothing);
      expect(find.text('Replace credentials'), findsNothing);
      expect(find.byTooltip('Edit app'), findsNothing);
      expect(find.byType(ReadOnlyBanner), findsOneWidget);
      final toggles = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggles.every((t) => t.onChanged == null), isTrue);
    });

    testWidgets('admin is read-only here too: credentials are owner business', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, BillingSettingsTab(app: app()));
      expect(find.text('Replace credentials'), findsNothing);
    });

    testWidgets('owner saves Apple credentials; the key is sent, then shown nowhere', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, BillingSettingsTab(app: BillingApp.fromJson(appJson(apple: false))));
      await tapText(tester, 'Set credentials');
      // The dialog opens empty for the secret, prefilled for nothing it does not know.
      expect(find.text('Apple credentials'), findsOneWidget);
      await tapText(tester, 'Save');
      expect(find.text('Paste the .p8 file contents'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('PUT')), isEmpty);

      await type(tester, const Key('apple.bundle'), 'com.example.notes');
      await type(tester, const Key('apple.issuer'), 'issuer-issuer-1');
      await type(tester, const Key('apple.keyId'), 'ABC123DEFG');
      await type(tester, const Key('apple.appId'), '123456789');
      await type(tester, const Key('apple.privateKey'), _pem);
      await tapText(tester, 'Save');

      final sent = server.bodies['PUT /apps/notes/apple']! as Map<Object?, Object?>;
      expect(sent['private_key'], _pem);
      expect(sent['app_apple_id'], 123456789);
      expect(find.text('Apple credentials'), findsNothing, reason: 'dialog closed');
      expect(find.textContaining('TOP-SECRET'), findsNothing);
      expect(find.textContaining('BEGIN PRIVATE KEY'), findsNothing);
    });

    testWidgets('replacing credentials never pre-fills the key', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, BillingSettingsTab(app: app()));
      await tapText(tester, 'Replace credentials');
      final key = tester.widget<TextFormField>(find.byKey(const Key('apple.privateKey')));
      expect(key.controller!.text, isEmpty);
      expect(find.text('ABC123DEFG'), findsWidgets, reason: 'non-secret identifiers are prefilled');
    });

    testWidgets('a single-line secret is masked while typing', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, BillingSettingsTab(app: app()));
      await tapText(tester, 'Set secret');
      final field = tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('neoauth.secret')), matching: find.byType(EditableText)),
      );
      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      await type(tester, const Key('neoauth.secret'), 'short');
      await tapText(tester, 'Save');
      expect(find.textContaining('16 to 200'), findsOneWidget);
      await type(tester, const Key('neoauth.secret'), 'a-long-enough-signing-secret');
      await tapText(tester, 'Save');
      expect(server.bodies['PUT /apps/notes/neoauth-webhook-secret'], {'secret': 'a-long-enough-signing-secret'});
      expect(find.textContaining('a-long-enough'), findsNothing);
    });

    testWidgets('removing credentials needs the slug typed', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, BillingSettingsTab(app: app()));
      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Remove');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, 'notes');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(server.calls, contains('DELETE /apps/notes/apple'));
    });

    testWidgets('turning account binding off asks first; declining changes nothing', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, BillingSettingsTab(app: app()));
      await tester.tap(find.widgetWithText(SwitchListTile, 'Require account binding'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off account binding?'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(server.calls.where((c) => c.startsWith('PATCH')), isEmpty);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Require account binding'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Turn off');
      expect(server.bodies['PATCH /apps/notes'], {'require_account_binding': false});
    });

    testWidgets('step-up during a credential change is requested once and the change retried', (tester) async {
      final server = FakeBilling(role: 'owner');
      server.failures['PATCH /apps/notes'] = stepUpReply;
      var prompts = 0;
      await pump(
        tester,
        server,
        BillingSettingsTab(app: app()),
        onStepUp: () async {
          prompts++;
          return true;
        },
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Allow restore to transfer purchases'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Allow');
      expect(prompts, 1);
      expect(server.calls.where((c) => c == 'PATCH /apps/notes'), hasLength(2));
    });

    testWidgets('shows the URLs to enter in the stores, from the configured billing URL', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await pump(tester, server, BillingSettingsTab(app: app()));
      expect(find.text('https://billing.test/v1/webhooks/apple'), findsOneWidget);
      expect(find.text('https://billing.test/v1/webhooks/google'), findsOneWidget);
    });
  });

  group('catalog', () {
    testWidgets('viewer reads products and entitlements, changes nothing', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await pump(tester, server, const BillingCatalogTab(slug: 'notes'));
      expect(find.text('Pro monthly'), findsOneWidget);
      expect(find.text('pro · Pro'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      expect(find.byTooltip('Edit Pro monthly'), findsNothing);
    });

    testWidgets('admin adds an entitlement (validated)', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, const BillingCatalogTab(slug: 'notes'));
      await tapText(tester, 'Add');
      await type(tester, const Key('entitlement.key'), 'Not Valid');
      await type(tester, const Key('entitlement.name'), 'VIP');
      await tapText(tester, 'Add');
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
      await type(tester, const Key('entitlement.key'), 'vip');
      await tapText(tester, 'Add');
      expect(server.bodies['POST /apps/notes/entitlements'], {'key': 'vip', 'name': 'VIP'});
    });

    testWidgets('admin maps a product to entitlements', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, const BillingCatalogTab(slug: 'notes'));
      await tester.tap(find.byTooltip('Entitlements of Pro monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ads free'));
      await tester.pump();
      await tapText(tester, 'Save');
      expect(server.bodies['PUT /apps/notes/products/pro_monthly/entitlements'], {
        'entitlements': ['pro', 'ads_free'],
      });
    });

    testWidgets('admin adds a product with entitlements', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, const BillingCatalogTab(slug: 'notes'));
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await type(tester, const Key('product.slug'), 'pro_yearly');
      await type(tester, const Key('product.name'), 'Pro yearly');
      await type(tester, const Key('product.apple'), 'com.example.pro.yearly');
      await type(tester, const Key('product.period'), '365');
      await tester.tap(find.text('Pro').last);
      await tester.pump();
      await tapText(tester, 'Add');
      final body = server.bodies['POST /apps/notes/products']! as Map<Object?, Object?>;
      expect(body['slug'], 'pro_yearly');
      expect(body['kind'], 'subscription');
      expect(body['apple_product_id'], 'com.example.pro.yearly');
      expect(body['period_days'], 365);
      expect(body['entitlements'], ['pro']);
      expect(body.containsKey('google_product_id'), isFalse);
    });
  });

  group('customers', () {
    testWidgets('viewers cannot look anyone up (the server needs admin)', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await pump(tester, server, const BillingCustomersTab(slug: 'notes'));
      expect(find.text('Admins only'), findsOneWidget);
      expect(find.byKey(const Key('billing.customer.sub')), findsNothing);
    });

    testWidgets('lookup validates the id, then shows entitlements, grants and purchases', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, const BillingCustomersTab(slug: 'notes'));
      expect(find.textContaining('recorded in the audit log'), findsOneWidget);
      await type(tester, const Key('billing.customer.sub'), 'not valid!');
      await tapText(tester, 'Look up');
      expect(find.text('Enter a user ID'), findsOneWidget);
      expect(server.calls.where((c) => c.contains('/users/')), isEmpty);

      for (final bad in ['..', '.']) {
        await type(tester, const Key('billing.customer.sub'), bad);
        await tapText(tester, 'Look up');
        expect(find.text('Enter a user ID'), findsOneWidget, reason: bad);
      }
      expect(server.calls.where((c) => c.contains('/users/')), isEmpty);

      await type(tester, const Key('billing.customer.sub'), 'user-1');
      await tapText(tester, 'Look up');
      expect(find.text('Entitlements now'), findsOneWidget);
      expect(find.text('pro · granted · via grant'), findsOneWidget);
      expect(find.textContaining('support ticket 42'), findsOneWidget);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('sandbox'), findsOneWidget);
    });

    Future<void> lookup(WidgetTester tester) async {
      await type(tester, const Key('billing.customer.sub'), 'user-1');
      await tapText(tester, 'Look up');
    }

    testWidgets('grant: form, confirmation naming the user and entitlement, step-up, then the grant is sent', (
      tester,
    ) async {
      final server = FakeBilling(role: 'admin');
      server.failures['POST /apps/notes/users/user-1/grants'] = stepUpReply;
      var prompts = 0;
      await pump(
        tester,
        server,
        const BillingCustomersTab(slug: 'notes'),
        onStepUp: () async {
          prompts++;
          return true;
        },
      );
      await lookup(tester);
      await tapText(tester, 'Grant');

      // Reason is required.
      await tapText(tester, 'Review');
      expect(find.text('Choose one'), findsOneWidget);
      expect(find.text('At least 3 characters'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);

      await tester.tap(find.byKey(const Key('grant.entitlement')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ads free (ads_free)').last);
      await tester.pumpAndSettle();
      await type(tester, const Key('grant.reason'), 'goodwill after outage');
      await tapText(tester, 'Review');

      expect(find.text('Grant ads_free?'), findsOneWidget);
      expect(scoped(find.textContaining('no end date')), findsOneWidget);
      expect(
        server.calls.where((c) => c.startsWith('POST')),
        isEmpty,
        reason: 'nothing is sent before the confirmation',
      );
      await tapText(tester, 'Grant');

      expect(prompts, 1);
      expect(server.calls.where((c) => c == 'POST /apps/notes/users/user-1/grants'), hasLength(2));
      expect(server.bodies['POST /apps/notes/users/user-1/grants'], {
        'entitlement': 'ads_free',
        'reason': 'goodwill after outage',
      });
      expect(
        server.calls.where((c) => c == 'GET /apps/notes/users/user-1'),
        hasLength(2),
        reason: 'reloaded after the grant',
      );
    });

    testWidgets('a declined confirmation sends nothing', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, const BillingCustomersTab(slug: 'notes'));
      await lookup(tester);
      await tapText(tester, 'Grant');
      await tester.tap(find.byKey(const Key('grant.entitlement')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pro (pro)').last);
      await tester.pumpAndSettle();
      await type(tester, const Key('grant.reason'), 'beta tester');
      await tapText(tester, 'Review');
      await tapText(tester, 'Cancel');
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
    });

    testWidgets('a cancelled step-up leaves the grant unsent and says so', (tester) async {
      final server = FakeBilling(role: 'admin');
      server.failures['POST /apps/notes/users/user-1/grants'] = stepUpReply;
      await pump(tester, server, const BillingCustomersTab(slug: 'notes'), onStepUp: () async => false);
      await lookup(tester);
      await tapText(tester, 'Grant');
      await tester.tap(find.byKey(const Key('grant.entitlement')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pro (pro)').last);
      await tester.pumpAndSettle();
      await type(tester, const Key('grant.reason'), 'beta tester');
      await tapText(tester, 'Review');
      await tapText(tester, 'Grant');
      expect(server.calls.where((c) => c == 'POST /apps/notes/users/user-1/grants'), hasLength(1));
      expect(find.textContaining('Cancelled'), findsOneWidget);
    });

    testWidgets('revoke needs a reason and sends it in the DELETE', (tester) async {
      final server = FakeBilling(role: 'admin');
      await pump(tester, server, const BillingCustomersTab(slug: 'notes'));
      await lookup(tester);
      await tester.tap(find.byTooltip('Revoke grant'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Revoke');
      expect(find.text('Reason is required'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'ab');
      await tapText(tester, 'Revoke');
      expect(find.text('At least 3 characters'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'granted by mistake');
      await tapText(tester, 'Revoke');
      expect(server.bodies['DELETE /apps/notes/grants/g-1'], {'reason': 'granted by mistake'});
    });
  });

  group('events', () {
    testWidgets('viewer sees events but cannot replay', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await pump(tester, server, const BillingEventsTab(slug: 'notes'));
      expect(find.text('DID_RENEW'), findsOneWidget);
      await tester.tap(find.text('DID_RENEW'));
      await tester.pumpAndSettle();
      expect(find.text('Replay'), findsNothing);
      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('admin replays a stored notification after a confirmation, with step-up', (tester) async {
      final server = FakeBilling(role: 'admin');
      server.failures['POST /apps/notes/events/ev-1/replay'] = stepUpReply;
      var prompts = 0;
      await pump(
        tester,
        server,
        const BillingEventsTab(slug: 'notes'),
        onStepUp: () async {
          prompts++;
          return true;
        },
      );
      await tester.tap(find.text('DID_RENEW'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay'));
      await tester.pumpAndSettle();
      expect(find.text('Replay this event?'), findsOneWidget);
      expect(server.calls.where((c) => c.contains('replay')), isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Replay'));
      await tester.pumpAndSettle();
      expect(prompts, 1);
      expect(server.calls.where((c) => c.contains('replay')), hasLength(2));
      expect(find.text('Replayed: processed'), findsOneWidget);
    });

    testWidgets('events that are not stored notifications offer no replay; erased payloads cannot be replayed', (
      tester,
    ) async {
      final server = FakeBilling(role: 'admin')
        ..events = [eventJson(id: 'a', source: 'client'), eventJson(id: 'b', hasPayload: false)];
      await pump(tester, server, const BillingEventsTab(slug: 'notes'));
      for (final tile in find.text('DID_RENEW').evaluate().toList()) {
        await tester.tap(find.byWidget(tile.widget));
        await tester.pumpAndSettle();
      }
      expect(find.widgetWithText(OutlinedButton, 'Replay'), findsNothing);
      expect(find.text('Payload erased'), findsOneWidget);
    });

    testWidgets('subscriptions view', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await pump(tester, server, const BillingEventsTab(slug: 'notes'));
      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();
      expect(find.text('active'), findsOneWidget);
      expect(server.calls, contains('GET /apps/notes/subscriptions'));
    });
  });

  group('developers', () {
    testWidgets('only owners; others do not even trigger the owner-only calls', (tester) async {
      for (final role in ['viewer', 'admin']) {
        final server = FakeBilling(role: role);
        await pump(tester, server, const BillingDevelopersTab(slug: 'notes'));
        expect(find.text('Owners only'), findsOneWidget, reason: role);
        expect(server.calls.where((c) => c.contains('api-keys') || c.contains('webhooks')), isEmpty, reason: role);
      }
    });

    testWidgets('a new API key is shown once, with a copy field, and nowhere afterwards', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, const BillingDevelopersTab(slug: 'notes'));
      await tapText(tester, 'Create');
      await type(tester, const Key('key.name'), 'api-server');
      await tapText(tester, 'Create');
      expect(server.bodies['POST /apps/notes/api-keys'], containsPair('scopes', ['entitlements:read']));
      expect(find.text('API key created'), findsOneWidget);
      expect(find.text('Copy this now. It is shown only once and cannot be retrieved later.'), findsOneWidget);
      await tapText(tester, "I've saved it");
      expect(find.textContaining('THE-ONLY-TIME'), findsNothing);
    });

    testWidgets('a new webhook is validated and its signing secret shown once', (tester) async {
      final server = FakeBilling(role: 'owner');
      await pump(tester, server, const BillingDevelopersTab(slug: 'notes'));
      await tapText(tester, 'Add');
      await type(tester, const Key('webhook.url'), 'not a url');
      await tapText(tester, 'Add');
      expect(find.textContaining('full URL'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
      await type(tester, const Key('webhook.url'), 'https://api.example.com/hooks');
      await tapText(tester, 'Add');
      expect(server.bodies['POST /apps/notes/webhooks'], {
        'url': 'https://api.example.com/hooks',
        'events': ['entitlement.granted', 'entitlement.updated', 'entitlement.revoked'],
      });
      expect(find.text('Webhook added'), findsOneWidget);
      await tapText(tester, "I've saved it");
      expect(find.textContaining('THE-ONLY-TIME'), findsNothing);
    });

    testWidgets('lists keys by prefix only, with revoke behind a confirmation', (tester) async {
      final server = FakeBilling(role: 'owner')
        ..apiKeys = [
          {
            'id': 'k-1',
            'name': 'api-server',
            'prefix': 'nbk_0123456789ab',
            'scopes': ['entitlements:read'],
            'status': 'active',
            'expires_at': null,
            'last_used_at': null,
            'created_by': 'x',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        ];
      await pump(tester, server, const BillingDevelopersTab(slug: 'notes'));
      expect(find.textContaining('nbk_0123456789ab…'), findsOneWidget);
      await tester.tap(find.byTooltip('Revoke api-server'));
      await tester.pumpAndSettle();
      expect(server.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('DELETE /apps/notes/api-keys/k-1'));
    });
  });

  group('audit log', () {
    testWidgets('admins only', (tester) async {
      final server = FakeBilling(role: 'viewer');
      await tester.pumpWidget(host(billingOverrides(server), const BillingAuditScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Admins only'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('GET /audit')), isEmpty);
    });

    testWidgets('shows who did what, with the app name', (tester) async {
      final server = FakeBilling(role: 'admin')
        ..audit = [
          {
            'id': '9',
            'event': 'admin.grant.created',
            'actor': 'admin:admin-1',
            'user_sub': 'user-1',
            'app_id': 'app-id-notes',
            'data': {'reason': 'beta'},
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        ];
      await tester.pumpWidget(host(billingOverrides(server), const BillingAuditScreen()));
      await tester.pumpAndSettle();
      expect(find.text('admin.grant.created'), findsOneWidget);
      expect(find.textContaining('Notes'), findsOneWidget);
      await tester.tap(find.text('admin.grant.created'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"reason": "beta"'), findsOneWidget);
    });
  });
}
