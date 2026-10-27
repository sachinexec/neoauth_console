import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/async_value_view.dart' show EmptyView;
import '../../../shared/widgets/common.dart';
import '../billing_models.dart';

/// Shown instead of a tab or screen the caller's billing role cannot use.
class NeedsRole extends StatelessWidget {
  const NeedsRole({super.key, required this.role, required this.what});

  /// `owners` or `admins`.
  final String role;
  final String what;

  @override
  Widget build(BuildContext context) => EmptyView(
    title: '${role[0].toUpperCase()}${role.substring(1)} only',
    message: 'Only billing $role can $what.',
    icon: Icons.lock_outline,
  );
}

/// A write-only field for a secret (a key, a service account, a signing
/// secret). It is never filled from the server. The text is not remembered by
/// the keyboard and not offered for autofill.
class SecretFormField extends StatelessWidget {
  const SecretFormField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.multiline = false,
    this.validator,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;

  /// For a PEM key or a JSON file: several lines, shown while pasting.
  final bool multiline;
  final String? Function(String?)? validator;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    // A single line can be masked; a multi-line paste cannot (it would lose its line breaks).
    obscureText: !multiline,
    keyboardType: multiline ? TextInputType.multiline : TextInputType.visiblePassword,
    minLines: multiline ? 4 : 1,
    maxLines: multiline ? 8 : 1,
    inputFormatters: [LengthLimitingTextInputFormatter(20000)],
    decoration: InputDecoration(
      labelText: label,
      helperText: helper ?? 'Write-only: it is never shown again.',
      helperMaxLines: 3,
      alignLabelWithHint: multiline,
    ),
    validator: validator,
  );
}

/// Subscription state to a colour.
StatusChip subscriptionStateChip(String state) => StatusChip(
  label: state.replaceAll('_', ' '),
  tone: switch (state) {
    'active' || 'trial' => ChipTone.success,
    'grace' || 'pending' || 'paused' => ChipTone.warning,
    'billing_retry' || 'revoked' => ChipTone.danger,
    _ => ChipTone.neutral,
  },
);

StatusChip eventStatusChip(String status) => StatusChip(
  label: status,
  tone: switch (status) {
    'processed' => ChipTone.success,
    'failed' => ChipTone.danger,
    'received' => ChipTone.warning,
    _ => ChipTone.neutral,
  },
);

/// How a store credential is set up.
StatusChip credentialChip(String store, bool configured, {bool sandbox = false}) => StatusChip(
  label: configured ? '$store${sandbox ? ' · sandbox on' : ''}' : '$store not set up',
  tone: !configured
      ? ChipTone.neutral
      : sandbox
      ? ChipTone.warning
      : ChipTone.success,
  icon: configured ? Icons.check : Icons.remove,
);

/// A short identifier for a long store key or id.
String shortId(String s, {int keep = 8}) =>
    s.length <= keep * 2 + 1 ? s : '${s.substring(0, keep)}…${s.substring(s.length - 4)}';

String entitlementLabel(ActiveEntitlement e) =>
    [e.key, if (e.state != null) e.state!, if (e.source != null) 'via ${e.source}'].join(' · ');
