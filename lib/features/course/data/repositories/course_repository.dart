import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/firestore_provider.dart';
import '../../domain/models/course.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/topic.dart';
import '../../domain/models/question.dart';

part 'course_repository.g.dart';

class CourseRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  CourseRepository(this.firestore, this.auth);

  String get uid {
    final currentUser = auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    return currentUser.uid;
  }

  CollectionReference<Map<String, dynamic>> get _coursesRef => firestore.collection('users').doc(uid).collection('courses');
  CollectionReference<Map<String, dynamic>> get _unitsRef => firestore.collection('users').doc(uid).collection('units');
  CollectionReference<Map<String, dynamic>> get _topicsRef => firestore.collection('users').doc(uid).collection('topics');
  CollectionReference<Map<String, dynamic>> get _questionsRef => firestore.collection('users').doc(uid).collection('questions');

  
  Future<Course?> getCourse(String id) async {
    final doc = await _coursesRef.doc(id).get();
    if (doc.exists) {
      return Course.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  
  Future<Unit?> getUnit(String id) async {
    final doc = await _unitsRef.doc(id).get();
    if (doc.exists) {
      return Unit.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> createCourse(String name, {DateTime? examDate, String? colorTag}) async {
    final docRef = _coursesRef.doc();
    final course = Course(
      id: docRef.id,
      name: name,
      examDate: examDate,
      colorTag: colorTag,
    );
    await docRef.set(course.toMap());
  }

  Future<List<Course>> getAllCourses() async {
    final snapshot = await _coursesRef.get();
    return snapshot.docs.map((doc) => Course.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateCourse(Course course) async {
    await _coursesRef.doc(course.id).update(course.toMap());
  }
  
  Stream<List<Course>> watchAllCourses() {
    return _coursesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Course.fromMap(doc.data(), doc.id)).toList();
    });
  }

  
  Stream<Unit?> watchUnit(String unitId) {
    return _unitsRef.doc(unitId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return Unit.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  Future<void> deleteCourse(String id) async {
    final batch = firestore.batch();
    
    // delete course
    batch.delete(_coursesRef.doc(id));
    
    // get units
    final unitsSnapshot = await _unitsRef.where('courseId', isEqualTo: id).get();
    for (var doc in unitsSnapshot.docs) {
      batch.delete(doc.reference);
      
      // delete questions of unit
      final questionsSnapshot = await _questionsRef.where('unitId', isEqualTo: doc.id).get();
      for (var qDoc in questionsSnapshot.docs) {
         batch.delete(qDoc.reference);
      }
      
      // delete topics of unit
      final topicsSnapshot = await _topicsRef.where('unitId', isEqualTo: doc.id).get();
      for (var tDoc in topicsSnapshot.docs) {
         batch.delete(tDoc.reference);
      }
    }
    
    await batch.commit();
  }

  Stream<Course?> watchCourse(String id) {
    return _coursesRef.doc(id).snapshots().map((doc) => doc.exists ? Course.fromMap(doc.data()!, doc.id) : null);
  }

  Stream<List<Unit>> watchCourseUnits(String courseId) {
    return _unitsRef.where('courseId', isEqualTo: courseId).snapshots().map((snapshot) {
      final units = snapshot.docs.map((doc) => Unit.fromMap(doc.data(), doc.id)).toList();
      units.sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      return units;
    });
  }

  Future<void> updateUnit(Unit unit) async {
    await _unitsRef.doc(unit.id).update(unit.toMap());
  }

  Future<void> deleteUnit(String id) async {
    final batch = firestore.batch();
    
    // delete unit
    batch.delete(_unitsRef.doc(id));
    
    // delete questions of unit
    final questionsSnapshot = await _questionsRef.where('unitId', isEqualTo: id).get();
    for (var qDoc in questionsSnapshot.docs) {
      batch.delete(qDoc.reference);
    }
    
    // delete topics of unit
    final topicsSnapshot = await _topicsRef.where('unitId', isEqualTo: id).get();
    for (var tDoc in topicsSnapshot.docs) {
      batch.delete(tDoc.reference);
    }
    
    await batch.commit();
  }
}

@riverpod
CourseRepository courseRepository(CourseRepositoryRef ref) {
  final fs = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return CourseRepository(fs, auth);
}
