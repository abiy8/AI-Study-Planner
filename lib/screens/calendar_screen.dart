import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../models/task_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();
  List<TaskModel> _allTasks = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Calendar'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _firestoreService.watchAllTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading tasks: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          _allTasks = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildCalendarHeader(),
                _buildCalendarGrid(),
                const Divider(height: 1, thickness: 2),
                _buildSelectedDateTasks(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                      1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                _getMonthYear(_selectedDate),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                      1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 0),
          Row(
            children: [
              'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
            ].map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.1,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
        ),
        itemCount: _getDaysInMonth(),
        itemBuilder: (context, index) {
          final day = _getCalendarDay(index);
          if (day == null) {
            return const SizedBox();
          }
          final date = DateTime(_selectedDate.year, _selectedDate.month, day);
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, DateTime.now());
          final tasksForDay = _getTasksForDate(date);
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
              if (tasksForDay.isNotEmpty) {
                _showTasksDialog(date, tasksForDay);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue
                    : isToday
                        ? Colors.blue.shade100
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: tasksForDay.isNotEmpty
                    ? Border.all(color: Colors.orange, width: 1)
                    : null,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? Colors.blue
                                : Colors.black,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (tasksForDay.isNotEmpty)
                      Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDateTasks() {
    final tasksForSelectedDate = _getTasksForDate(_selectedDate);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tasks for ${_formatDate(_selectedDate)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (tasksForSelectedDate.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _addTasksToGoogleCalendar(tasksForSelectedDate),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Add to Calendar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasksForSelectedDate.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks for this date',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tasks with due dates will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tasksForSelectedDate.length,
                    itemBuilder: (context, index) {
                      final task = tasksForSelectedDate[index];
                      return _buildTaskCard(task);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) {
                        if (value != null && task.id != null) {
                          _firestoreService.updateTaskCompletion(
                            task.courseId,
                            task.id!,
                            value,
                          );
                        }
                      },
                    ),
                    IconButton(
                      onPressed: () => _addSingleTaskToGoogleCalendar(task),
                      icon: const Icon(Icons.calendar_today, size: 20),
                      tooltip: 'Add to Google Calendar',
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (task.estimatedHours > 0) ...[
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${task.estimatedHours}h estimated',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  int _getDaysInMonth() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    
    return firstWeekday + daysInMonth;
  }

  int? _getCalendarDay(int index) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final firstWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    
    if (index < firstWeekday) {
      return null; // Empty cell before month starts
    }
    
    return index - firstWeekday + 1;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    // Normalize both dates to local midnight for comparison
    final d1 = DateTime(date1.year, date1.month, date1.day);
    final d2 = DateTime(date2.year, date2.month, date2.day);
    // Debug print for troubleshooting
    // ignore: avoid_print
    print('Comparing dueDate: $d1 with selected: $d2');
    return d1 == d2;
  }

  List<TaskModel> _getTasksForDate(DateTime date) {
    return _allTasks.where((task) {
      if (task.dueDate == null) return false;
      return _isSameDay(task.dueDate!, date);
    }).toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _addSingleTaskToGoogleCalendar(TaskModel task) async {
    try {
      final startDate = task.dueDate ?? DateTime.now();
      // Set start time to 9:00 AM
      final startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        9,
        0,
      );
      final endDateTime = startDateTime.add(
        Duration(hours: task.estimatedHours > 0 ? task.estimatedHours : 1),
      );
      
      final url = _buildGoogleCalendarUrl(
        title: task.title,
        description: task.description,
        startDate: startDateTime,
        endDate: endDateTime,
      );

      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Google Calendar...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening calendar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addTasksToGoogleCalendar(List<TaskModel> tasks) async {
    for (final task in tasks) {
      await _addSingleTaskToGoogleCalendar(task);
      // Add a small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${tasks.length} task(s) to Google Calendar'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _buildGoogleCalendarUrl({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startDateFormatted = _formatDateForUrl(startDate);
    final endDateFormatted = _formatDateForUrl(endDate);
    
    final titleParam = Uri.encodeComponent(title);
    final descriptionParam = Uri.encodeComponent(description.isEmpty ? 'Study task from AI Study Planner' : description);
    
    return 'https://www.google.com/calendar/render'
        '?action=TEMPLATE'
        '&text=$titleParam'
        '&details=$descriptionParam'
        '&dates=$startDateFormatted/$endDateFormatted';
  }

  String _formatDateForUrl(DateTime date) {
    // Convert to UTC for Google Calendar
    final utcDate = date.toUtc();
    return '${utcDate.year.toString().padLeft(4, '0')}'
        '${utcDate.month.toString().padLeft(2, '0')}'
        '${utcDate.day.toString().padLeft(2, '0')}T'
        '${utcDate.hour.toString().padLeft(2, '0')}'
        '${utcDate.minute.toString().padLeft(2, '0')}'
        '${utcDate.second.toString().padLeft(2, '0')}Z';
  }
  
  /// Shows a dialog with all tasks for the selected date
  void _showTasksDialog(DateTime date, List<TaskModel> tasks) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<TaskModel>>(
        stream: _firestoreService.watchAllTasks(),
        builder: (context, snapshot) {
          // Get updated tasks for this date
          final updatedTasks = snapshot.hasData
              ? snapshot.data!.where((task) {
                  if (task.dueDate == null) return false;
                  return _isSameDay(task.dueDate!, date);
                }).toList()
              : tasks;

          return Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tasks for ${_formatDate(date)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          '${updatedTasks.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable task list
                  Flexible(
                    child: updatedTasks.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No tasks for this date'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: updatedTasks.length,
                            itemBuilder: (context, index) {
                              final task = updatedTasks[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: Checkbox(
                                          value: task.isCompleted,
                                          onChanged: (bool? value) {
                                            if (value != null && task.id != null) {
                                              _firestoreService.updateTaskCompletion(
                                                task.courseId,
                                                task.id!,
                                                value,
                                              );
                                            }
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.padded,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            if (task.description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                task.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getPriorityColor(task.priority),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    task.priority.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                if (task.estimatedHours > 0) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${task.estimatedHours}h',
                                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: IconButton(
                                          icon: const Icon(Icons.calendar_today, size: 16),
                                          onPressed: () => _addSingleTaskToGoogleCalendar(task),
                                          tooltip: 'Add to Calendar',
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Action buttons
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        if (updatedTasks.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _addTasksToGoogleCalendar(updatedTasks);
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: const Text('Add All', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}