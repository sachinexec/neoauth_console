import 'package:flutter/material.dart';

/// Edits a list of strings (redirect URIs, fingerprints) as removable chips
/// with an input to add more. [validator] checks each new entry.
class ChipListEditor extends StatefulWidget {
  const ChipListEditor({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.validator,
    this.enabled = true,
    this.errorText,
    this.keyboardType = TextInputType.url,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? Function(String value)? validator;
  final bool enabled;
  final TextInputType keyboardType;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final v = _input.text.trim();
    if (v.isEmpty) return;
    final err = widget.values.contains(v) ? 'Already added' : widget.validator?.call(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    _input.clear();
    widget.onChanged([...widget.values, v]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in widget.values)
                  InputChip(
                    label: Text(v, style: const TextStyle(fontFamily: 'monospace')),
                    onDeleted: widget.enabled ? () => widget.onChanged([...widget.values]..remove(v)) : null,
                    deleteButtonTooltipMessage: 'Remove $v',
                    isEnabled: widget.enabled,
                  ),
              ],
            ),
          ),
        if (widget.enabled)
          TextField(
            controller: _input,
            keyboardType: widget.keyboardType,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: widget.values.isEmpty ? widget.label : 'Add to ${widget.label.toLowerCase()}',
              hintText: widget.hintText,
              helperText: widget.helperText,
              helperMaxLines: 3,
              errorText: _error ?? widget.errorText,
              suffixIcon: IconButton(tooltip: 'Add', icon: const Icon(Icons.add), onPressed: _add),
            ),
            onSubmitted: (_) => _add(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          )
        else if (widget.values.isEmpty)
          Text('None', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
