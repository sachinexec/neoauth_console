import 'package:neoauth_console/features/apps/models/app_models.dart';
import 'package:neoauth_console/features/apps/widgets/login_methods_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _support = ProviderSupport({
  LoginMethod.google: SurfaceSupport(web: false, native: false),
  LoginMethod.apple: SurfaceSupport(web: false, native: false),
  LoginMethod.phone: SurfaceSupport(web: true, native: true),
  LoginMethod.email: SurfaceSupport(web: true, native: true),
  LoginMethod.passkey: SurfaceSupport(web: true, native: false),
});

/// Hosts the editor with its own state, like the providers tab does.
class _Host extends StatefulWidget {
  const _Host(this.initial, {this.allowed});
  final Set<LoginMethod> initial;
  final Set<LoginMethod>? allowed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Set<LoginMethod> selected = widget.initial;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LoginMethodsEditor(
          selected: selected,
          support: _support,
          allowed: widget.allowed,
          onChanged: (s) => setState(() => selected = s),
        ),
      ),
    ),
  );
}

SwitchListTile _tile(WidgetTester tester, LoginMethod m) =>
    tester.widget<SwitchListTile>(find.byKey(Key('method.${m.wire}')));

Set<LoginMethod> _selected(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).selected;

void main() {
  testWidgets('the last enabled method cannot be turned off', (tester) async {
    await tester.pumpWidget(const _Host({LoginMethod.phone, LoginMethod.email}));

    await tester.tap(find.byKey(const Key('method.email')));
    await tester.pump();
    expect(_selected(tester), {LoginMethod.phone});

    // Phone is now the only one: locked, with a hint.
    expect(_tile(tester, LoginMethod.phone).onChanged, isNull);
    expect(find.byKey(const Key('method.phone.last')), findsOneWidget);
    await tester.tap(find.byKey(const Key('method.phone')));
    await tester.pump();
    expect(_selected(tester), {LoginMethod.phone});

    // Turning another on unlocks it again.
    await tester.tap(find.byKey(const Key('method.passkey')));
    await tester.pump();
    expect(_selected(tester), {LoginMethod.phone, LoginMethod.passkey});
    expect(_tile(tester, LoginMethod.phone).onChanged, isNotNull);
    expect(find.byKey(const Key('method.phone.last')), findsNothing);
  });

  testWidgets('shows server support per method', (tester) async {
    await tester.pumpWidget(const _Host({LoginMethod.phone}));
    expect(find.textContaining('Not configured on this server'), findsNWidgets(2)); // google, apple
    expect(find.text('Web sign-in only (not configured for native apps)'), findsOneWidget); // passkey
    expect(find.text('Web and native apps'), findsNWidgets(2)); // phone, email
  });

  testWidgets('a client cannot enable methods its app has turned off', (tester) async {
    await tester.pumpWidget(const _Host({LoginMethod.phone}, allowed: {LoginMethod.phone, LoginMethod.email}));
    expect(_tile(tester, LoginMethod.google).onChanged, isNull);
    expect(_tile(tester, LoginMethod.email).onChanged, isNotNull);
    expect(find.text('Turned off for the app'), findsNWidgets(3));
  });

  testWidgets('warns when no selected method is configured on the server', (tester) async {
    await tester.pumpWidget(const _Host({LoginMethod.google}));
    expect(find.textContaining('nobody could sign in'), findsOneWidget);
  });
}
