import 'package:hive/hive.dart';

part 'client_message_status.g.dart';

@HiveType(typeId: 3)
enum ClientMessageStatus {
  @HiveField(0)
  sending,
  @HiveField(1)
  sent,
  @HiveField(2)
  failed,
}
