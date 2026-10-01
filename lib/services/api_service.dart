import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';

/// Service for communicating with the Node.js backend API.
///
/// This service handles AI-powered task generation using OpenAI's GPT model.
/// The backend processes syllabus content (either as text or uploaded files)
/// and generates structured study tasks that are automatically saved to Firestore.
///
/// Backend endpoint automatically detects platform:
/// - Android emulator: http://10.0.2.2:3000
/// - iOS simulator/Web/Desktop (macOS/Windows/Linux): http://localhost:3000
/// Required: Node.js backend must be running with OpenAI API key configured.
class ApiService {
  /// Backend URL - automatically detects platform and uses correct localhost address
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
  }
  /// Generates tasks from an uploaded file (PDF, DOCX, or TXT).
  ///
  /// The backend extracts text from the file, sends it to OpenAI for analysis,
  /// and saves the generated tasks to Firestore under the specified course.
  ///
  /// Parameters:
  /// - [file]: The uploaded file containing syllabus content
  /// - [courseId]: Optional course ID. Defaults to 'planner-global' for general tasks
  /// - [courseName]: Optional course name for display purposes
  ///
  /// Returns a list of generated tasks. Tasks are also saved to Firestore automatically.
  ///
  /// Throws [Exception] if:
  /// - File cannot be read or is empty
  /// - Backend is unreachable
  /// - OpenAI API fails to generate tasks
  /// - File format is not supported (must be PDF, DOCX, or TXT)
  Future<List<TaskModel>> generateTasksFromFile({
    required PlatformFile file,
    String? courseId,
    String? courseName,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo-user';
    final finalCourseId = courseId ?? 'planner-global';
    
    try {
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/api/generate-tasks-from-file')
      );

      // Add file to the request
      if (file.bytes != null) {
        // Web platform
        request.files.add(http.MultipartFile.fromBytes(
          'syllabus',
          file.bytes!,
          filename: file.name,
        ));
      } else if (file.path != null) {
        // Mobile platform
        request.files.add(await http.MultipartFile.fromPath(
          'syllabus',
          file.path!,
          filename: file.name,
        ));
      } else {
        throw Exception('Unable to access file data');
      }

      // Add additional fields
      request.fields['userId'] = userId;
      request.fields['courseId'] = finalCourseId;
      if (courseName != null) {
        request.fields['courseName'] = courseName;
      }

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final taskList = data['tasks'] as List;
        
        return taskList
            .map((taskJson) => TaskModel.fromJson(taskJson as Map<String, dynamic>))
            .toList();
      } else {
        String message = 'Failed to generate tasks from file';
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          if (errorData['error'] is String) {
            message = errorData['error'];
          }
        } catch (_) {
          // If we can't parse the error, use default message
        }
        throw Exception(message);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow; // Re-throw if it's already a formatted exception
      }
      throw Exception('Failed to upload file and generate tasks: $e');
    }
  }

  /// Generates tasks from plain text syllabus content.
  ///
  /// The backend sends the text to OpenAI for analysis and generates
  /// structured study tasks that are automatically saved to Firestore.
  ///
  /// Parameters:
  /// - [syllabusText]: The raw syllabus text to analyze
  /// - [courseId]: Optional course ID. Defaults to 'planner-global' for general tasks
  /// - [courseName]: Optional course name for display purposes
  ///
  /// Returns a list of generated tasks. Tasks are also saved to Firestore automatically.
  ///
  /// Throws [Exception] if:
  /// - Backend is unreachable
  /// - OpenAI API fails to generate tasks
  /// - Syllabus text is empty or invalid
  Future<List<TaskModel>> generateTasksFromSyllabus({
    required String syllabusText,
    String? courseId,
    String? courseName,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo-user';
    final finalCourseId = courseId ?? 'planner-global';
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-tasks'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'courseId': finalCourseId,
          'syllabusText': syllabusText,
          if (courseName != null) 'courseName': courseName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final taskList = data['tasks'] as List;
        
        return taskList
            .map((taskJson) => TaskModel.fromJson(taskJson as Map<String, dynamic>))
            .toList();
      } else {
        String message = 'Failed to generate tasks';
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          if (errorData['error'] is String) {
            message = errorData['error'];
          }
        } catch (_) {
          // If we can't parse the error, use default message
        }
        throw Exception(message);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow; // Re-throw if it's already a formatted exception
      }
      throw Exception('Failed to generate tasks: $e');
    }
  }
}
