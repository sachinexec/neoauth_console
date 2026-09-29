import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> copyToClipboard(BuildContext context, String value, {String what = 'Value'}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what copied')));
}

/// A read-only value with a copy button. With [secret], the value starts
/// hidden behind a reveal toggle.
class CopyField extends StatefulWidget {
  const CopyField({super.key, required this.label, required this.value, this.secret = false, this.dense = false});

  final String label;
  final String value;
  final bool secret;
  final bool dense;

  @override
  State<CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<CopyField> {
  late bool _hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _hidden ? '•' * 24 : widget.value;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: widget.dense,
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              shown,
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              maxLines: widget.dense ? 1 : null,
            ),
          ),
          if (widget.secret)
            IconButton(
              tooltip: _hidden ? 'Reveal ${widget.label}' : 'Hide ${widget.label}',
              icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          IconButton(
            tooltip: 'Copy ${widget.label}',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => copyToClipboard(context, widget.value, what: widget.label),
          ),
        ],
      ),
    );
  }
}
