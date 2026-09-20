import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/firestore_provider.dart';

import 'package:exam_command_center/features/course/domain/models/course.dart';
import 'package:exam_command_center/features/course/domain/models/unit.dart';
import 'package:exam_command_center/features/course/domain/models/topic.dart';
import 'package:exam_command_center/features/course/domain/models/question.dart';

part 'import_repository.g.dart';

class ImportRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  ImportRepository(this.firestore, this.auth);

  String get uid {
    final currentUser = auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    return currentUser.uid;
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString);
    final batch = firestore.batch();

    final courseData = data['course'];
    final courseRef = firestore.collection('users').doc(uid).collection('courses').doc();
    
    final course = Course(
      id: courseRef.id,
      name: courseData['name'],
      examDate: courseData['examDate'] != null ? DateTime.parse(courseData['examDate']) : null,
      colorTag: courseData['colorTag'],
    );
    batch.set(courseRef, course.toMap());

    if (courseData['units'] != null) {
      for (var unitData in courseData['units']) {
        final unitRef = firestore.collection('users').doc(uid).collection('units').doc();
        final unit = Unit(
          id: unitRef.id,
          courseId: course.id,
          name: unitData['name'],
          index: unitData['index'],
        );
        batch.set(unitRef, unit.toMap());

        if (unitData['topics'] != null) {
          for (var topicData in unitData['topics']) {
            final topicRef = firestore.collection('users').doc(uid).collection('topics').doc();
            final topic = Topic(
              id: topicRef.id,
              unitId: unit.id,
              name: topicData['name'] ?? '',
            );
            batch.set(topicRef, topic.toMap());

            if (topicData['questions'] != null) {
              for (var qData in topicData['questions']) {
                final qRef = firestore.collection('users').doc(uid).collection('questions').doc();
                final question = Question(
                  id: qRef.id,
                  unitId: unit.id,
                  courseId: course.id,
                  title: qData['title'] ?? '',
                  notes: qData['notes'],
                  difficulty: qData['confidenceScore'] ?? 3,
                  createdAt: DateTime.now(),
                );
                batch.set(qRef, question.toMap());
              }
            }
          }
        }
      }
    }
    await batch.commit();
  }
}

@riverpod
ImportRepository importRepository(ImportRepositoryRef ref) {
  final fs = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return ImportRepository(fs, auth);
}
