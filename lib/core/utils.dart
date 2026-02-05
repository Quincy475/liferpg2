import 'package:intl/intl.dart';

DateTime startOfIsoWeek(DateTime dt) {
  final mondayDiff = (dt.weekday + 6) % 7; // Monday=1 => 0, Sunday=7 => 6
  final d = DateTime(dt.year, dt.month, dt.day).subtract(Duration(days: mondayDiff));
  return DateTime(d.year, d.month, d.day);
}

String fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

T clamp<T extends num>(T value, T min, T max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int pct(int base, int percent) => ((base * percent) / 100).round();
