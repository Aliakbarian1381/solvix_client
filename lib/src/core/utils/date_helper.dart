import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime toTehran(DateTime utcTime) {
  final utcDateTime = tz.TZDateTime.utc(
    utcTime.year,
    utcTime.month,
    utcTime.day,
    utcTime.hour,
    utcTime.minute,
    utcTime.second,
  );

  final tehranLocation = tz.getLocation('Asia/Tehran');
  return tz.TZDateTime.from(utcDateTime, tehranLocation);
}
