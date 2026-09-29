/// Form validators shared by the create/edit screens.
library;

/// An absolute http(s) URL. [required] false allows empty.
String? validateHttpUrl(String? v, {bool required = true, bool httpsOnly = false}) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return required ? 'Required' : null;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'Enter a full URL, e.g. https://example.com';
  if (httpsOnly && uri.scheme != 'https') return 'Must use https';
  if (uri.scheme != 'https' && uri.scheme != 'http') return 'Must start with https:// or http://';
  return null;
}

/// A redirect URI: web clients use http(s); native apps may use a custom
/// scheme (`com.example.app:/callback`). The server does the full check.
String? validateRedirectUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return 'Enter an absolute URI, e.g. https://example.com/callback';
  if (uri.hasFragment) return 'Redirect URIs cannot contain a #fragment';
  if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) return 'Missing host';
  return null;
}

String? trimmedOrNull(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}
