import 'package:isar/isar.dart';
import 'topic.dart';
import 'course.dart';

part 'unit.g.dart';

@collection
class Unit {
  Id id = Isar.autoIncrement;

  late String name;

  int? index; // To keep track of Unit 1, 2, 3...

  @Backlink(to: 'units')
  final course = IsarLink<Course>();

  final topics = IsarLinks<Topic>();
}
