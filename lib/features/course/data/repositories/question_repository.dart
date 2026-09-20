import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/firestore_provider.dart';
import '../../domain/models/question.dart';
import '../../domain/models/unit.dart';
import 'package:exam_command_center/features/planner/domain/models/planner_event.dart';

part 'question_repository.g.dart';

class QuestionRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  QuestionRepository(this.firestore, this.auth);

  String get uid {
    final currentUser = auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    return currentUser.uid;
  }

  CollectionReference<Map<String, dynamic>> get _questionsRef => firestore.collection('users').doc(uid).collection('questions');
  CollectionReference<Map<String, dynamic>> get _eventsRef => firestore.collection('users').doc(uid).collection('plannerEvents');
  CollectionReference<Map<String, dynamic>> get _unitsRef => firestore.collection('users').doc(uid).collection('units');

  int _parseDifficulty(String title) {
    int stars = RegExp(r'[★☆]').allMatches(title).length;
    if (stars == 0) return 3;
    return stars > 5 ? 5 : stars;
  }

  String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'[★☆]'), '').split('\n').first.trim();
  }

  Future<void> addQuestion(String title, String unitId, {String? courseId}) async {
    final unitDoc = await _unitsRef.doc(unitId).get();
    if (!unitDoc.exists) return;

    final docRef = _questionsRef.doc();
    final question = Question(
      id: docRef.id,
      title: _cleanTitle(title),
      courseId: courseId ?? '',
      unitId: unitId,
      difficulty: _parseDifficulty(title),
      createdAt: DateTime.now(),
    );
    
    await docRef.set(question.toMap());
  }

  Question createQuestionObject(String title, String unitId) {
    return Question(
      id: '',
      title: _cleanTitle(title),
      courseId: '',
      unitId: unitId,
      difficulty: _parseDifficulty(title),
      createdAt: DateTime.now(),
    );
  }

  Future<void> updateStatus(String questionId, QuestionStatus newStatus) async {
    final batch = firestore.batch();
    final qRef = _questionsRef.doc(questionId);
    
    batch.update(qRef, {
      'status': newStatus.name,
      'lastViewedAt': DateTime.now().toIso8601String(),
    });

    final isCompleted = newStatus == QuestionStatus.completed;
    
    final eventsSnapshot = await _eventsRef.where('questionIds', arrayContains: questionId).get();
    for (var doc in eventsSnapshot.docs) {
      if (doc.data()['isCompleted'] != isCompleted) {
        batch.update(doc.reference, {'isCompleted': isCompleted});
      }
    }
    
    await batch.commit();
  }

  Future<void> updateDifficulty(String questionId, int stars) async {
    await _questionsRef.doc(questionId).update({'difficulty': stars});
  }

  
  Future<Question?> getQuestion(String questionId) async {
    final doc = await _questionsRef.doc(questionId).get();
    if (doc.exists) {
      return Question.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<Question?> watchQuestion(String questionId) {
    return _questionsRef.doc(questionId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return Question.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  Future<void> updateQuestion(Question question) async {
    await _questionsRef.doc(question.id).update(question.toMap());
  }

  Future<void> deleteQuestion(String questionId) async {
    await _questionsRef.doc(questionId).delete();
  }

  Future<List<Question>> getQuestionsForUnit(String unitId) async {
    final snapshot = await _questionsRef.where('unitId', isEqualTo: unitId).get();
    return snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<Question>> getQuestionsForCourse(String courseId) async {
    final snapshot = await _questionsRef.where('courseId', isEqualTo: courseId).get();
    return snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
  }
  
  Stream<List<Question>> watchQuestionsForCourse(String courseId) {
    return _questionsRef.where('courseId', isEqualTo: courseId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Question>> watchQuestionsForUnit(String unitId) {
    return _questionsRef.where('unitId', isEqualTo: unitId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Question>> watchAllQuestions() {
    return _questionsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<List<Question>> getRevisionQueue() async {
    final snapshot = await _questionsRef
        .where('status', isEqualTo: QuestionStatus.revisionNeeded.name)
        .orderBy('lastViewedAt')
        .get();
    return snapshot.docs.map((doc) => Question.fromMap(doc.data(), doc.id)).toList();
  }


}

@riverpod
QuestionRepository questionRepository(QuestionRepositoryRef ref) {
  final fs = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return QuestionRepository(fs, auth);
}
