
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_model.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';


class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  const CourseDetailScreen({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
        Color _getCourseColor(String courseId) {
          // Simple color assignment based on courseId hash
          final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal];
          return colors[courseId.hashCode % colors.length];
        }

        Widget _buildStatItem(String label, String value, IconData icon) {
          return Column(
            children: [
              Icon(icon, size: 20, color: Colors.blue),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          );
        }

        Widget _buildTaskCard(TaskModel task) {
          String formattedDate = task.dueDate != null
              ? '${task.dueDate!.toLocal()}'.split(' ')[0]
              : 'No deadline';
          Color priorityColor;
          String priorityLabel;
          switch (task.priority) {
            case 'high':
              priorityColor = Colors.red;
              priorityLabel = 'High';
              break;
            case 'medium':
              priorityColor = Colors.orange;
              priorityLabel = 'Medium';
              break;
            case 'low':
            default:
              priorityColor = Colors.green;
              priorityLabel = 'Low';
              break;
          }
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              title: Text(task.title, style: const TextStyle(fontSize: 15)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(task.description, style: const TextStyle(fontSize: 13)),
                    ),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 2),
                      Text(formattedDate, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 10),
                      Icon(Icons.flag, size: 13, color: priorityColor),
                      const SizedBox(width: 2),
                      Text(priorityLabel, style: TextStyle(fontSize: 12, color: priorityColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Edit Task',
                    onPressed: () => _showEditTaskDialog(task),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete Task',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Task'),
                          content: Text('Delete "${task.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _firestoreService.deleteTask(
                          widget.course.id ?? 'default',
                          task.id!,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted "${task.title}"'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  Checkbox(
                    value: task.isCompleted,
                    onChanged: (value) async {
                      await _firestoreService.updateTaskCompletion(
                        widget.course.id ?? 'default',
                        task.id!,
                        value ?? false,
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        }

        Future<void> _showEditTaskDialog(TaskModel task) async {
          final titleController = TextEditingController(text: task.title);
          final descController = TextEditingController(text: task.description);
          String priority = task.priority;
          DateTime? dueDate = task.dueDate;
          await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Edit Task'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      DropdownButtonFormField<String>(
                        value: priority,
                        items: const [
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                        ],
                        onChanged: (val) {
                          if (val != null) priority = val;
                        },
                        decoration: const InputDecoration(labelText: 'Priority'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Due Date:'),
                          const SizedBox(width: 8),
                          Text(dueDate != null ? '${dueDate?.toLocal()}'.split(' ')[0] : 'None'),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dueDate = picked;
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _firestoreService.updateTask(
                        widget.course.id ?? 'default',
                        task.id!,
                        {
                          'title': titleController.text,
                          'description': descController.text,
                          'priority': priority,
                          'dueDate': dueDate,
                        },
                      );
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        }
      @override
      Widget build(BuildContext context) {
        final color = _getCourseColor(widget.course.id ?? 'default');
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              widget.course.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') {
                    // TODO: Implement rename dialog
                  } else if (value == 'delete_all_tasks') {
                    _showDeleteAllTasksDialog();
                  } else if (value == 'delete_course') {
                    _showDeleteCourseDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Rename Course'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all_tasks',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 20),
                        SizedBox(width: 8),
                        Text('Delete All Tasks'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_course',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Course', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: StreamBuilder<CourseModel?>(
            stream: _firestoreService.watchCourses().map((courses) {
              try {
                return courses.firstWhere((c) => c.id == widget.course.id);
              } catch (e) {
                return null;
              }
            }),
            builder: (context, courseSnapshot) {
              final currentCourse = courseSnapshot.data ?? widget.course;
              final progressPercent = (currentCourse.progressPercent * 100).round();
              return StreamBuilder<List<TaskModel>>(
                stream: _firestoreService.watchTasksForCourse(widget.course.id ?? 'default'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading tasks: \\${snapshot.error}'),
                    );
                  }
                  final tasks = snapshot.data ?? [];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.course.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: color.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '$progressPercent%',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: currentCourse.progressPercent,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatItem(
                                          'Total Tasks',
                                          '${currentCourse.tasks}',
                                          Icons.assignment,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          'Current Tasks',
                                          '${tasks.where((t) => !t.isCompleted).length}',
                                          Icons.list,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          'Completed',
                                          '${tasks.where((t) => t.isCompleted).length}',
                                          Icons.check_circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Tasks',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (tasks.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_sortAndFilterTasks(tasks).length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.blue,
                                onPressed: _showAddTaskDialog,
                                tooltip: 'Add Task',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _sortBy,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
                                        DropdownMenuItem(value: 'priority', child: Text('Sort by Priority')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _sortBy = value);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _hideDoneTasks,
                                      onChanged: (value) {
                                        setState(() => _hideDoneTasks = value ?? false);
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const Text('Hide done', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final sortedTasks = _sortAndFilterTasks(tasks);
                                if (sortedTasks.isEmpty && _hideDoneTasks && tasks.isNotEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: Colors.green[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'All tasks completed!',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Uncheck "Hide done" to see them',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                if (sortedTasks.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.assignment_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No tasks yet',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Generate tasks from the Planner screen!',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: sortedTasks.length,
                                  itemBuilder: (context, index) {
                                    final task = sortedTasks[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Dismissible(
                                        key: Key(task.id ?? 'task_$index'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        confirmDismiss: (direction) async {
                                          return await showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Task'),
                                              content: Text('Delete "${task.title}"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(true),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        onDismissed: (direction) async {
                                          try {
                                            await _firestoreService.deleteTask(
                                              widget.course.id ?? 'default',
                                              task.id!,
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Deleted "${task.title}"'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to delete task: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: _buildTaskCard(task),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      }
    final FirestoreService _firestoreService = FirestoreService();
    String _sortBy = 'date';
    bool _hideDoneTasks = false;

    List<TaskModel> _sortAndFilterTasks(List<TaskModel> tasks) {
      var filteredTasks = _hideDoneTasks 
          ? tasks.where((task) => !task.isCompleted).toList()
          : tasks;
      filteredTasks.sort((a, b) {
        if (_sortBy == 'date') {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        } else if (_sortBy == 'priority') {
          const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
          return (priorityOrder[a.priority] ?? 3).compareTo(priorityOrder[b.priority] ?? 3);
        } else {
          return 0;
        }
      });
      return filteredTasks;
    }

    Future<void> _showAddTaskDialog() async {
      final titleController = TextEditingController();
      final descController = TextEditingController();
      String priority = 'medium';
      DateTime? dueDate;
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Add Task'),
                content: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      DropdownButtonFormField<String>(
                        value: priority,
                        items: const [
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => priority = val);
                        },
                        decoration: const InputDecoration(labelText: 'Priority'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Due Date:'),
                          const SizedBox(width: 8),
                          Text(dueDate != null ? '${dueDate!.toLocal()}'.split(' ')[0] : 'None'),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  dueDate = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;
                      await _firestoreService.addTask(
                        widget.course.id ?? 'default',
                        {
                          'title': titleController.text.trim(),
                          'description': descController.text.trim(),
                          'priority': priority,
                          'dueDate': dueDate,
                          'isCompleted': false,
                        },
                      );
                      if (mounted) setState(() {}); // Refresh UI immediately
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Future<void> _showDeleteCourseDialog() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Course'),
          content: const Text('Are you sure you want to delete this course and all its tasks? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await _firestoreService.deleteCourse(widget.course.id!);
          if (mounted) Navigator.of(context).pop(); // Go back after deletion
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete course: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }

    Future<void> _showDeleteAllTasksDialog() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete All Tasks'),
          content: const Text('Are you sure you want to delete all tasks in this course? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          final tasks = await _firestoreService.getTasksForCourse(widget.course.id!);
          for (final task in tasks) {
            await _firestoreService.deleteTask(widget.course.id!, task.id!);
          }
          if (mounted) setState(() {});
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete all tasks: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }

    Future<void> _showRenameCourseDialog() async {
      final controller = TextEditingController(text: widget.course.name);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename Course'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'New course name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rename'),
            ),
          ],
        ),
      );
      if (confirm == true && controller.text.trim().isNotEmpty) {
        try {
          await _firestoreService.renameCourse(widget.course.id!, controller.text.trim());
          if (mounted) setState(() {});
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to rename course: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  // ...existing code for all methods, build, dialogs, and widgets...
}
