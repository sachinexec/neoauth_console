import 'package:flutter/material.dart';

import '../../../core/json.dart';

/// Every sign-in method the service knows (backend `login-methods.ts`).
enum LoginMethod {
  google('Google', Icons.g_mobiledata),
  apple('Apple', Icons.apple),
  phone('Phone (SMS code)', Icons.sms_outlined),
  email('Email code', Icons.alternate_email),
  passkey('Passkey', Icons.fingerprint);

  const LoginMethod(this.label, this.icon);
  final String label;
  final IconData icon;

  String get wire => name;

  static LoginMethod? tryParse(String v) {
    for (final m in LoginMethod.values) {
      if (m.name == v) return m;
    }
    return null;
  }

  /// Parses a list, dropping unknown values, in canonical order.
  static List<LoginMethod> parseList(Iterable<String> values) {
    final set = values.map(tryParse).whereType<LoginMethod>().toSet();
    return LoginMethod.values.where(set.contains).toList(growable: false);
  }

  static List<String> toWire(Iterable<LoginMethod> methods) =>
      LoginMethod.values.where(methods.contains).map((m) => m.wire).toList();
}

/// Where a method can run: the hosted (web) sign-in page and/or native apps.
class SurfaceSupport {
  const SurfaceSupport({required this.web, required this.native});
  final bool web;
  final bool native;

  bool get any => web || native;
  bool get both => web && native;

  factory SurfaceSupport.fromJson(Json j) => SurfaceSupport(web: optBool(j, 'web'), native: optBool(j, 'native'));

  @override
  bool operator ==(Object other) => other is SurfaceSupport && other.web == web && other.native == native;
  @override
  int get hashCode => Object.hash(web, native);
}

/// `GET /admin/providers`: which methods this server is configured to run.
class ProviderSupport {
  const ProviderSupport(this.byMethod);
  final Map<LoginMethod, SurfaceSupport> byMethod;

  SurfaceSupport of(LoginMethod m) => byMethod[m] ?? const SurfaceSupport(web: false, native: false);

  factory ProviderSupport.fromJson(Json j) => ProviderSupport({
    for (final m in LoginMethod.values)
      if (j[m.wire] is Map) m: SurfaceSupport.fromJson((j[m.wire] as Map).cast<String, dynamic>()),
  });
}

/// Effective methods for a client, per surface (from the server).
class EffectiveLoginMethods {
  const EffectiveLoginMethods({required this.web, required this.native});
  final List<LoginMethod> web;
  final List<LoginMethod> native;

  factory EffectiveLoginMethods.fromJson(Json j) => EffectiveLoginMethods(
    web: LoginMethod.parseList(stringList(j, 'web')),
    native: LoginMethod.parseList(stringList(j, 'native')),
  );
}
