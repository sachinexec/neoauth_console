import 'package:intl/intl.dart';

/// Units offered by duration pickers, largest first.
enum DurationUnit {
  days(86400, 'days', 'd'),
  hours(3600, 'hours', 'h'),
  minutes(60, 'minutes', 'min');

  const DurationUnit(this.seconds, this.label, this.short);
  final int seconds;
  final String label;
  final String short;

  /// The largest unit that divides [seconds] exactly (minutes otherwise).
  static DurationUnit bestFor(int seconds) {
    for (final u in DurationUnit.values) {
      if (seconds >= u.seconds && seconds % u.seconds == 0) return u;
    }
    return DurationUnit.minutes;
  }
}

/// "10 min", "12 h", "30 d", "1 h 30 min".
String formatSeconds(int seconds) {
  if (seconds <= 0) return '0 s';
  if (seconds < 60) return '$seconds s';
  final parts = <String>[];
  var rest = seconds;
  for (final u in DurationUnit.values) {
    final n = rest ~/ u.seconds;
    if (n > 0) {
      parts.add('$n ${u.short}');
      rest -= n * u.seconds;
    }
    if (parts.length == 2) break;
  }
  if (parts.isEmpty) return '$seconds s';
  return parts.join(' ');
}

final _dateTime = DateFormat.yMMMd().add_Hm();
final _date = DateFormat.yMMMd();

String formatDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());
String formatDate(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());

/// "just now", "5 min ago", "3 h ago", "2 d ago", then the date.
String formatRelative(DateTime? d, {DateTime? now}) {
  if (d == null) return '—';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  return formatDate(d);
}

final _compact = NumberFormat.compact();
String formatCount(int n) => n < 10000 ? NumberFormat.decimalPattern().format(n) : _compact.format(n);
