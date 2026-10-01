import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a course with metadata about progress and task counts.
///
/// Courses are stored in Firestore under: `users/{userId}/courses/{courseId}`
/// Each course can have multiple tasks stored in a subcollection: `tasks/`
class CourseModel {
  /// Firestore document ID. Null for new courses not yet saved.
  final String? id;
  
  /// Course name (e.g., "Computer Architecture")
  final String name;
  
  /// Course code/number (e.g., "CS 401")
  final String courseCode;
  
  /// Instructor name
  final String instructor;
  
  /// Total number of weeks in the course
  final int weeks;
  
  /// Total count of tasks associated with this course
  final int tasks;
  
  /// Progress percentage (0.0 to 100.0)
  final double progressPercent;
  
  /// Timestamp when course was created
  final DateTime? createdAt;

  CourseModel({
    this.id,
    required this.name,
    this.courseCode = '',
    this.instructor = '',
    this.weeks = 0,
    this.tasks = 0,
    this.progressPercent = 0.0,
    this.createdAt,
  });

  /// Deserializes a CourseModel from Firestore JSON data.
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        parsedCreatedAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.parse(json['createdAt']);
      }
    }
    
    return CourseModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      courseCode: json['courseCode']?.toString() ?? '',
      instructor: json['instructor']?.toString() ?? '',
      weeks: json['weeks'] as int? ?? 0,
      tasks: json['tasks'] as int? ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      createdAt: parsedCreatedAt,
    );
  }

  /// Serializes the CourseModel to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'courseCode': courseCode,
      'instructor': instructor,
      'weeks': weeks,
      'tasks': tasks,
      'progressPercent': progressPercent,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  /// Creates a copy of this CourseModel with specified fields updated.
  CourseModel copyWith({
    String? id,
    String? name,
    String? courseCode,
    String? instructor,
    int? weeks,
    int? tasks,
    double? progressPercent,
    DateTime? createdAt,
  }) {
    return CourseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      courseCode: courseCode ?? this.courseCode,
      instructor: instructor ?? this.instructor,
      weeks: weeks ?? this.weeks,
      tasks: tasks ?? this.tasks,
      progressPercent: progressPercent ?? this.progressPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}