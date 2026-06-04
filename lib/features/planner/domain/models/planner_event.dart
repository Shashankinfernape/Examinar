import 'package:isar/isar.dart';

part 'planner_event.g.dart';

enum SessionType {
  study,
  revision,
  mock,
}

@collection
class PlannerEvent {
  Id id = Isar.autoIncrement;

  late String title;
  
  late DateTime startTime;
  
  late DateTime endTime;

  List<int>? questionIds;

  @enumerated
  SessionType sessionType = SessionType.study;

  String? colorHex;

  bool isCompleted = false;
}
