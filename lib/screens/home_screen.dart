import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/account_service.dart';
import 'planner_screen.dart';
import 'courses_screen.dart';
import 'calendar_screen.dart';

/// Main application home screen with bottom navigation.
///
/// Provides navigation between four main sections:
/// - Dashboard: Overview of tasks, courses, and recent activity
/// - Planner: AI-powered task generation from syllabi
/// - Courses: Course management and task viewing
/// - Calendar: Google Calendar integration
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
    final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Start periodic task checking for notifications from all courses
    _notificationService.startPeriodicCheck(
      _firestoreService.watchAllTasks(),
    );
  }
  
  @override
  void dispose() {
    _notificationService.stopPeriodicCheck();
    super.dispose();
  }
  
  final List<Widget> _screens = [
    const HomeTab(),
    const CoursesScreen(),
    const PlannerScreen(),
    const CalendarScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Courses',
    'Planner',
    'Calendar',
  ];

  /// Updates the selected bottom navigation tab.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'logout') {
                await _authService.signOut();
              } else if (value == 'delete_account') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('Are you sure you want to delete your account? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  bool deleted = false;
                  while (!deleted) {
                    try {
                      await _accountService.deleteAccountAndData(
                        onError: (msg) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete account: $msg')),
                            );
                          }
                        },
                        onRequiresRecentLogin: () async {
                          // Prompt user to re-authenticate with Google
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please sign in again to delete your account.')),
                            );
                          }
                          try {
                            await _authService.signInWithGoogle();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Re-authentication failed: $e')),
                              );
                            }
                          }
                        },
                      );
                      deleted = true;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Account deleted.')),
                        );
                      }
                    } catch (e) {
                      if (e.toString().contains('requires-recent-login')) {
                        // Loop will retry after re-authentication
                        continue;
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete account: $e')),
                        );
                      }
                      break;
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_account',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Account', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}

/// Dashboard tab showing overview statistics and recent activity.
/// Displays real-time data from Firestore.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          StreamBuilder<User?>(
            stream: authService.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final displayName = user?.displayName ?? 'User';
              final email = user?.email ?? 'No email';
              
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.metadata.creationTime != null &&
                      DateTime.now().difference(user!.metadata.creationTime!).inMinutes < 5
                          ? 'Welcome!'
                          : 'Welcome back!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick stats - Real data from Firestore
          StreamBuilder<List<dynamic>>(
            stream: firestoreService.watchAllTasks(),
            builder: (context, taskSnapshot) {
              return StreamBuilder(
                stream: firestoreService.watchCourses(),
                builder: (context, courseSnapshot) {
                  final tasks = taskSnapshot.data ?? [];
                  final courses = courseSnapshot.data ?? [];
                  
                  final today = DateTime.now();
                  final tasksToday = tasks.where((task) {
                    if (task.dueDate == null) return false;
                    return task.dueDate!.year == today.year &&
                           task.dueDate!.month == today.month &&
                           task.dueDate!.day == today.day;
                  }).length;
                  
                  final completedTasks = tasks.where((task) => task.isCompleted).length;
                  // Only count courses with at least one incomplete task
                  final activeCourses = courses.where((course) {
                    final courseTasks = tasks.where((t) => t.courseId == course.id).toList();
                    return courseTasks.any((t) => !t.isCompleted);
                  }).length;
                  // Only sum estimatedMinutes for incomplete tasks
                  final incompleteTasks = tasks.where((t) => !t.isCompleted);
                  final totalMinutes = incompleteTasks.fold<int>(0, (sum, task) => (sum + task.estimatedMinutes).toInt());
                  final totalHours = (totalMinutes / 60).toStringAsFixed(1);

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Tasks Today',
                              tasksToday.toString(),
                              Icons.assignment_turned_in,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Completed',
                              completedTasks.toString(),
                              Icons.check_circle,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Active Courses',
                              activeCourses.toString(),
                              Icons.school,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Study Hours',
                              totalHours,
                              Icons.schedule,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Recent activity - Only show if there are actual tasks
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<dynamic>>(
            stream: firestoreService.watchAllTasks(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No activity yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate tasks to get started!',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final tasks = snapshot.data!;
              // Only completed tasks, sorted by most recent completion (createdAt descending)
              final completedTasks = tasks
                  .where((task) => task.isCompleted && task.createdAt != null)
                  .toList();
              completedTasks.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
              // Remove duplicates by title (if any)
              final seenTitles = <String>{};
              final uniqueRecent = <dynamic>[];
              for (final t in completedTasks) {
                if (!seenTitles.contains(t.title)) {
                  uniqueRecent.add(t);
                  seenTitles.add(t.title);
                }
                if (uniqueRecent.length >= 5) break;
              }

              return Column(
                children: uniqueRecent.map((task) {
                  final timeAgo = task.createdAt != null
                      ? _getTimeAgo(task.createdAt!)
                      : 'Recently';
                  return _buildActivityItem(
                    'Completed: ${task.title}',
                    timeAgo,
                    Icons.check_circle,
                    Colors.green,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}