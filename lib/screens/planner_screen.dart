import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../models/course_model.dart';

/// AI-powered task generation screen.
///
/// Allows users to generate study tasks in two ways:
/// 1. Upload a syllabus file (PDF, DOCX, TXT) via drag-and-drop or file picker
/// 2. Paste syllabus text directly into a text field
///
/// Tasks are generated using OpenAI via the backend API and automatically
/// saved to the 'planner-global' course in Firestore for unassigned tasks.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final TextEditingController _syllabusController = TextEditingController();
  bool _isLoading = false;
  PlatformFile? _selectedFile;
  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isDragHover = false;
  CourseModel? _selectedCourse;
  bool _tasksGenerated = false;

  /// Generates tasks from the text in the syllabus text field.
  /// Shows validation error if field is empty or no course selected.
  Future<void> _generatePlanFromText() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_syllabusController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste your syllabus text to generate a plan.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await _apiService.generateTasksFromSyllabus(
        syllabusText: _syllabusController.text,
        courseId: _selectedCourse!.id ?? '',
        courseName: _selectedCourse!.name,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _tasksGenerated = true;
          _syllabusController.clear();
          _selectedFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${tasks.length} tasks for ${_selectedCourse!.name}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Opens file picker for selecting syllabus files (PDF, DOC, DOCX, TXT).
  /// File is stored but generation happens when user clicks the button.
  Future<void> _pickFile() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _tasksGenerated = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Sends the selected file to the backend for AI-powered task generation.
  /// Displays success or error message via SnackBar.
  Future<void> _generatePlanFromFile() async {
    if (_selectedFile == null || _selectedCourse == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await _apiService.generateTasksFromFile(
        file: _selectedFile!,
        courseId: _selectedCourse!.id ?? '',
        courseName: _selectedCourse!.name,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _tasksGenerated = true;
          _syllabusController.clear();
          _selectedFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${tasks.length} tasks for ${_selectedCourse!.name}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Course selector
          const Text(
            'Select Course',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<CourseModel>>(
            stream: _firestoreService.watchCourses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }

              final courses = snapshot.data ?? [];
              
              if (courses.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No courses yet. Create a course in the Courses section first.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCourse?.id,
                    hint: const Text('Choose a course for task generation'),
                    items: courses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course.id,
                        child: Text(
                          course.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? courseId) {
                      setState(() {
                        _selectedCourse = courses.firstWhere((c) => c.id == courseId);
                        _tasksGenerated = false;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Success message when tasks generated
          if (_tasksGenerated)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tasks generated successfully! View them in the Courses section.',
                      style: TextStyle(fontSize: 14, color: Colors.green.shade900),
                    ),
                  ),
                ],
              ),
            ),
          
          // File upload section
          DropTarget(
            onDragDone: (detail) async {
              if (detail.files.isNotEmpty) {
                final file = detail.files.first;
                setState(() {
                  _selectedFile = PlatformFile(
                    name: file.name,
                    size: 0,
                    path: file.path,
                  );
                  _tasksGenerated = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File dropped: ${file.name}')),
                );
              }
            },
            onDragEntered: (detail) {
              setState(() {
                _isDragHover = true;
              });
            },
            onDragExited: (detail) {
              setState(() {
                _isDragHover = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isDragHover
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.shade50,
                border: Border.all(
                  color: _isDragHover ? Colors.blue : Colors.grey.shade300,
                  style: BorderStyle.solid,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: _isDragHover ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFile != null
                        ? 'File selected: ${_selectedFile!.name}'
                        : 'Drag & drop your syllabus here or click to browse',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDragHover
                          ? Colors.blue.shade600
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supported formats: TXT, PDF, DOC, DOCX',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Generate from file button
          if (_selectedFile != null)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generatePlanFromFile,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Plan from File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 24),

          // Text input section
          const Text(
            'Paste your syllabus text:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _syllabusController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste your course syllabus here...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 24),

          // Generate button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generatePlanFromText,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isLoading ? 'Generating...' : 'Generate Study Plan with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),


        ],
      ),
    );
  }



  @override
  void dispose() {
    _syllabusController.dispose();
    super.dispose();
  }
}