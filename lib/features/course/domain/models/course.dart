import 'package:isar/isar.dart';
import 'unit.dart';

part 'course.g.dart';

@collection
class Course {
  Id id = Isar.autoIncrement;

  late String name;
  
  DateTime? examDate;
  
  String? colorTag;

  String? examStrategy; // New field for AI-generated strategy

  final units = IsarLinks<Unit>();
}
