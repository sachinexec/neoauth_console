import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';

/// A human-friendly duration input: an amount and a unit (minutes, hours,
/// days). The value is in seconds. [onChanged] gets null while the amount is
/// empty or not a number.
class DurationField extends StatefulWidget {
  const DurationField({
    super.key,
    required this.label,
    required this.seconds,
    required this.onChanged,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.units = DurationUnit.values,
  });

  final String label;
  final int? seconds;
  final ValueChanged<int?> onChanged;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final List<DurationUnit> units;

  @override
  State<DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<DurationField> {
  late DurationUnit _unit;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _sync(widget.seconds);
  }

  void _sync(int? seconds) {
    if (seconds == null) {
      _unit = widget.units.last;
      _amount.text = '';
      return;
    }
    _unit = DurationUnit.bestFor(seconds);
    if (!widget.units.contains(_unit)) _unit = widget.units.last;
    final n = seconds / _unit.seconds;
    _amount.text = n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(DurationField old) {
    super.didUpdateWidget(old);
    // External change (a preset, a reset): show it. Our own edits round-trip unchanged.
    if (widget.seconds != _current) setState(() => _sync(widget.seconds));
  }

  int? get _current {
    final n = int.tryParse(_amount.text.trim());
    return n == null ? null : n * _unit.seconds;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _amount,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: widget.helperText,
              helperMaxLines: 3,
              errorText: widget.errorText,
              errorMaxLines: 3,
            ),
            onChanged: (_) => widget.onChanged(_current),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<DurationUnit>(
            key: ValueKey(_unit),
            initialValue: _unit,
            decoration: InputDecoration(labelText: 'Unit', enabled: widget.enabled),
            items: [for (final u in widget.units) DropdownMenuItem(value: u, child: Text(u.label))],
            onChanged: widget.enabled
                ? (u) {
                    if (u == null) return;
                    setState(() => _unit = u);
                    widget.onChanged(_current);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
