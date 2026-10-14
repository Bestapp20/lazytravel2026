import 'package:intl/intl.dart';

import '../theme/app_assets.dart';

String heDateRange(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final df = DateFormat('d MMMM', 'he');
  if (end == null || _sameDay(start, end)) return df.format(start);
  if (start.month == end.month && start.year == end.year) {
    return '${start.day}–${end.day} ${DateFormat('MMMM y', 'he').format(start)}';
  }
  return '${df.format(start)} – ${df.format(end)}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int nightsBetween(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 0;
  return end.difference(start).inDays;
}

int daysUntil(DateTime? start) {
  if (start == null) return 0;
  return start.difference(DateTime.now()).inDays;
}

String ils(num? amount) {
  if (amount == null) return '₪0';
  final n = NumberFormat.decimalPattern('he');
  return '₪${n.format(amount.round())}';
}

String categoryLabel(String? category) {
  switch (category) {
    case 'food':
      return 'מסעדה';
    case 'hotel':
      return 'מלון';
    case 'museum':
      return 'מוזיאון';
    case 'nature':
      return 'טבע';
    case 'shopping':
      return 'קניות';
    case 'nightlife':
      return 'חיי לילה';
    case 'attraction':
    default:
      return 'אטרקציה';
  }
}

String categoryEmoji(String? category) {
  switch (category) {
    case 'food':
      return '🍽️';
    case 'hotel':
      return '🏨';
    case 'museum':
      return '🖼️';
    case 'nature':
      return '🌿';
    case 'shopping':
      return '🛍️';
    case 'nightlife':
      return '🎉';
    default:
      return '📍';
  }
}

String interestLabel(String id) {
  for (final i in kInterests) {
    if (i.id == id) return i.label;
  }
  return id;
}

String timeLabel(DateTime? t) {
  if (t == null) return '';
  return DateFormat('HH:mm').format(t);
}

String hhmm(String? sqlTime) {
  if (sqlTime == null || sqlTime.isEmpty) return '';
  return sqlTime.length >= 5 ? sqlTime.substring(0, 5) : sqlTime;
}
