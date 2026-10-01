  /// Returns all tasks for a given course as a list of TaskModel.
  Future<List<TaskModel>> getTasksForCourse(String courseId) async {
    try {
      final snapshot = await _courseTasksCol(courseId).get();
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get tasks: e');
    }
  }

  /// Renames a course by updating its name field.
  Future<void> renameCourse(String courseId, String newName) async {
    try {
      await _userCoursesCol.doc(courseId).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to rename course: e');
    }
  }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_model.dart';
import '../models/task_model.dart';


/// Service for managing user-scoped Firestore data operations.
///
/// All data is stored under: `users/{userId}/courses/{courseId}/tasks/{taskId}`
/// This ensures complete data isolation between users.
///
/// Special course IDs:
/// - 'planner-global': Used for general planner tasks not tied to a specific course
class FirestoreService {
      /// Adds a new task to a course and updates the course's task count and progress.
      Future<void> addTask(String courseId, Map<String, dynamic> data) async {
        try {
          data['createdAt'] = FieldValue.serverTimestamp();
          final taskRef = await _courseTasksCol(courseId).add(data);
          // Update the course's task count and progress
          final tasksSnapshot = await _courseTasksCol(courseId).get();
          final totalTasks = tasksSnapshot.docs.length;
          final completedTasks = tasksSnapshot.docs.where((doc) => doc.data()['isCompleted'] == true).length;
          final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
          await _userCoursesCol.doc(courseId).update({
            'tasks': totalTasks,
            'progressPercent': progress,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          throw Exception('Failed to add task: ${e.toString()}');
        }
      }
    /// Updates an existing task's fields in Firestore.
    Future<void> updateTask(String courseId, String taskId, Map<String, dynamic> updates) async {
      try {
        await _courseTasksCol(courseId).doc(taskId).update(updates);
      } catch (e) {
        throw Exception('Failed to update task: ${e.toString()}');
      }
    }
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _db = FirebaseFirestore.instance;

  /// Gets the current authenticated user's ID.
  /// Throws if no user is authenticated (prevents data loss after sign-in/out).
  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user. Please sign in.');
    }
    return user.uid;
  }

  /// Returns the courses collection reference for the current user.
  CollectionReference<Map<String, dynamic>> get _userCoursesCol =>
    _db.collection('users').doc(_userId).collection('courses');

  /// Returns the tasks subcollection reference for a specific course.
  CollectionReference<Map<String, dynamic>> _courseTasksCol(String courseId) =>
    _userCoursesCol.doc(courseId).collection('tasks');

  /// Creates or updates a course in Firestore.
  /// Uses merge: true to update existing fields without overwriting the entire document.
  Future<void> upsertCourse(CourseModel course) async {
    try {
      await _userCoursesCol.doc(course.id).set(
        course.toJson(), 
        SetOptions(merge: true)
      );
    } catch (e) {
      throw Exception('Failed to save course: ${e.toString()}');
    }
  }

  /// Watches all courses for the current user.
  /// Returns a stream that updates whenever courses are added, modified, or deleted.
  Stream<List<CourseModel>> watchCourses() {
    return _userCoursesCol.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include document ID in the model
        return CourseModel.fromJson(data);
      }).toList();
    });
  }

  /// Watches all tasks for a specific course.
  /// Tasks are ordered by creation date (oldest first).
  Stream<List<TaskModel>> watchTasksForCourse(String courseId) {
    return _courseTasksCol(courseId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Include document ID in the model
          return TaskModel.fromJson(data);
        }).toList());
  }

  /// Watches tasks in the 'planner-global' course.
  /// This is used for general planner tasks not associated with a specific course.
  Stream<List<TaskModel>> watchPlannerGlobalTasks() {
    return _courseTasksCol('planner-global')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TaskModel.fromJson(data);
        }).toList());
  }

  /// Watches all tasks from all courses for the current user.
  /// This is used for the calendar view to show tasks from all courses.
  Stream<List<TaskModel>> watchAllTasks() {
    return _userCoursesCol.snapshots().asyncMap((coursesSnapshot) async {
      List<TaskModel> allTasks = [];
      
      for (var courseDoc in coursesSnapshot.docs) {
        final tasksSnapshot = await _courseTasksCol(courseDoc.id).get();
        final tasks = tasksSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TaskModel.fromJson(data);
        }).toList();
        allTasks.addAll(tasks);
      }
      
      return allTasks;
    });
  }

  /// Updates the completion status of a specific task.
  /// Also recalculates and updates the course progress percentage.
  /// Throws an exception if the update fails.
  Future<void> updateTaskCompletion(
    String courseId, 
    String taskId, 
    bool isCompleted
  ) async {
    try {
      await _courseTasksCol(courseId).doc(taskId).update({
        'isCompleted': isCompleted,
      });
      
      // Recalculate and update course progress
      await _updateCourseProgress(courseId);
    } catch (e) {
      throw Exception('Failed to update task: ${e.toString()}');
    }
  }

  /// Deletes a specific task from a course.
  /// Also updates the course's task count and recalculates progress.
  Future<void> deleteTask(String courseId, String taskId) async {
    try {
      // Delete the task document
      await _courseTasksCol(courseId).doc(taskId).delete();
      
      // Get all remaining tasks to recalculate
      final tasksSnapshot = await _courseTasksCol(courseId).get();
      final totalTasks = tasksSnapshot.docs.length;
      final completedTasks = tasksSnapshot.docs.where((doc) => doc.data()['isCompleted'] == true).length;
      final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
      
      // Update the course with new counts and progress
      final courseRef = _userCoursesCol.doc(courseId);
      await courseRef.update({
        'tasks': totalTasks,
        'progressPercent': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete task: ${e.toString()}');
    }
  }

  /// Deletes a course and all its associated tasks.
  Future<void> deleteCourse(String courseId) async {
    try {
      // First, delete all tasks in the course
      final tasksSnapshot = await _courseTasksCol(courseId).get();
      final batch = _db.batch();
      
      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the course document
      batch.delete(_userCoursesCol.doc(courseId));
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete course: ${e.toString()}');
    }
  }

  /// Deletes all tasks in a specific course (but keeps the course).
  Future<void> deleteAllTasksInCourse(String courseId) async {
    try {
      final tasksSnapshot = await _courseTasksCol(courseId).get();
      final batch = _db.batch();
      
      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Update course task count to 0 and reset progress
      batch.update(_userCoursesCol.doc(courseId), {
        'tasks': 0,
        'progressPercent': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete tasks: ${e.toString()}');
    }
  }
  
  /// Recalculates and updates the progress percentage for a course.
  /// Progress is calculated as: (completed tasks / total tasks) * 100
  Future<void> _updateCourseProgress(String courseId) async {
    try {
      final tasksSnapshot = await _courseTasksCol(courseId).get();
      final totalTasks = tasksSnapshot.docs.length;
      final completedTasks = tasksSnapshot.docs.where((doc) => doc.data()['isCompleted'] == true).length;
      
      final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
      
      await _userCoursesCol.doc(courseId).update({
        'progressPercent': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update course progress: ${e.toString()}');
    }
  }
}