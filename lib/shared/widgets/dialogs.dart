import 'package:flutter/material.dart';

import 'copy_field.dart';

/// Asks for confirmation. With [typedConfirmation], the confirm button stays
/// disabled until the user types that exact text (for irreversible actions).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  String? typedConfirmation,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      typedConfirmation: typedConfirmation,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    this.typedConfirmation,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final String? typedConfirmation;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _ok => widget.typedConfirmation == null || _typed.text.trim() == widget.typedConfirmation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            if (widget.typedConfirmation != null) ...[
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Type '),
                    TextSpan(
                      text: widget.typedConfirmation,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                    const TextSpan(text: ' to confirm.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _typed,
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Confirmation'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
              : null,
          onPressed: _ok ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Asks for a required line of text (e.g. a suspension reason). Null when cancelled.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String? message,
  String confirmLabel = 'Save',
  String? initial,
  int maxLength = 500,
  bool destructive = false,
  String? Function(String value)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      label: label,
      message: message,
      confirmLabel: confirmLabel,
      initial: initial,
      maxLength: maxLength,
      destructive: destructive,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.maxLength,
    required this.destructive,
    this.message,
    this.initial,
    this.validator,
  });

  final String title;
  final String label;
  final String? message;
  final String confirmLabel;
  final String? initial;
  final int maxLength;
  final bool destructive;
  final String? Function(String value)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: 16)],
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: widget.maxLength,
              decoration: InputDecoration(labelText: widget.label),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return '${widget.label} is required';
                return widget.validator?.call(value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
              : null,
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Shows a secret that the server returns exactly once (client secret,
/// webhook signing secret). Can't be dismissed by tapping outside.
Future<void> showSecretDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String secret,
  String? explanation,
  List<(String, String)> extra = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.key_outlined, color: scheme.primary),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Copy this now. It is shown only once and cannot be retrieved later.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              if (explanation != null) ...[const SizedBox(height: 12), Text(explanation)],
              for (final (l, v) in extra) ...[const SizedBox(height: 12), CopyField(label: l, value: v)],
              const SizedBox(height: 12),
              CopyField(label: label, value: secret, secret: true),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text("I've saved it"))],
      );
    },
  );
}
