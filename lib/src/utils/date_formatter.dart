import 'package:solvix/src/core/utils/date_helper.dart'; // این import را اضافه کنید
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

String formatLastSeen(DateTime lastSeenUtc) {
  final lastSeenLocal = toTehran(lastSeenUtc);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  final aDate = DateTime(
    lastSeenLocal.year,
    lastSeenLocal.month,
    lastSeenLocal.day,
  );

  if (aDate == today) {
    return 'آخرین بازدید امروز ${DateFormat('HH:mm').format(lastSeenLocal)}';
  } else if (aDate == yesterday) {
    return 'آخرین بازدید دیروز${DateFormat('HH:mm').format(lastSeenLocal)}';
  } else {
    final jalaliDate = Jalali.fromDateTime(lastSeenLocal);
    final formatter = jalaliDate.formatter;
    return 'آخرین بازدید در ${formatter.d} ${formatter.mN} ${formatter.y}';
  }
}
