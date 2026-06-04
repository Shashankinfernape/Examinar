import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/isar_provider.dart';
import '../../domain/models/course.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/topic.dart';
import '../../domain/models/question.dart';

part 'course_repository.g.dart';

class CourseRepository {
  final Isar isar;

  CourseRepository(this.isar);

  Future<void> createCourse(String name, {DateTime? examDate, String? colorTag}) async {
    await isar.writeTxn(() async {
      final course = Course()
        ..name = name
        ..examDate = examDate
        ..colorTag = colorTag;
      
      await isar.courses.put(course);
      
      await course.units.save();
    });
  }

  Future<List<Course>> getAllCourses() async {
    return isar.courses.where().findAll();
  }

  Future<void> deleteCourse(int id) async {
    await isar.writeTxn(() async {
      final course = await isar.courses.get(id);
      if (course != null) {
        // Load units first to iterate over them
        await course.units.load();
        for (final unit in course.units) {
          // Delete questions for this unit
          await isar.questions.where().filter().unitIdEqualTo(unit.id).deleteAll();
          
          // Delete topics linked to this unit
          // Since Isar 3.x filter link syntax is specific, let's use a simpler approach
          // for the cascade delete by gathering IDs if necessary, or just deleting topics
          // where the unitLink matches.
          final topicIds = await isar.topics.where()
              .filter()
              .unit((q) => q.idEqualTo(unit.id))
              .idProperty()
              .findAll();
          await isar.topics.deleteAll(topicIds);
          
          await isar.units.delete(unit.id);
        }
        await isar.courses.delete(id);
      }
    });
  }
}

@riverpod
Future<CourseRepository> courseRepository(CourseRepositoryRef ref) async {
  final isar = await ref.watch(isarProvider.future);
  return CourseRepository(isar);
}
