import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'userpicker.dart';
import 'dart:io';
import 'settings.dart';
import 'completed_tasks_screen.dart';
import 'auth.dart';

class HomeWidgets extends StatefulWidget {
  const HomeWidgets({super.key});

  @override
  State<HomeWidgets> createState() => _HomeWidgetsState();
}

class _HomeWidgetsState extends State<HomeWidgets> {
  String _profileImageUrl = '';
  String name = '';

  bool isOrientationLocked = false;
  int totalTasks = 0;
  int pendingTasks = 0;
  int completedTasks = 0;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    _fetchProfileImageUrl();
  }
  Future<void> _fetchProfileImageUrl() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('client')
            .doc('details')
            .get();

        if (docSnapshot.exists) {
          final userData = docSnapshot.data();
          if (userData != null) {
            final imageUrl = userData['imageURL'] as String?;
            setState(() {
              _profileImageUrl = imageUrl ?? '';
              name = userData['displayName'] as String;
            });
          } else {
            print('User data is null');
          }
        } else {}
      } else {
        print('Current user is null');
      }
    } catch (error) {
      print('Error fetching profile data: $error');
    }
  }

  void _toggleOrientationLock() {
    setState(() {
      isOrientationLocked = !isOrientationLocked;
      if (isOrientationLocked) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    });
  }

  Future<void> _updateProfileImage(File pickedImage) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${currentUser.uid}.jpg');
        await storageRef.putFile(pickedImage);
        final imageURL = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('client')
            .doc('details')
            .update({
          'imageURL': imageURL,
        });

        setState(() {
          _profileImageUrl = imageURL;
        });
      }
    } catch (error) {
      print('Error updating profile image: $error');
    }
  }

  Future<void> _fetchTasks() async {
    if (user != null) {
      // Fetch group tasks
      final groupsSnapshot =
          await FirebaseFirestore.instance.collection('groups').get();
      for (var groupDoc in groupsSnapshot.docs) {
        final tasksSnapshot =
            await groupDoc.reference.collection('tasks').get();
        for (var taskDoc in tasksSnapshot.docs) {
          final taskData = taskDoc.data();
          setState(() {
            totalTasks++;
            if (taskData['isCompleted'] == true) {
              completedTasks++;
            } else {
              pendingTasks++;
            }
          });
        }
      }

      // Fetch personal tasks
      final userTasksSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('tasks')
          .get();
      for (var taskDoc in userTasksSnapshot.docs) {
        final taskData = taskDoc.data();
        setState(() {
          totalTasks++;
          if (taskData['isCompleted'] == true) {
            completedTasks++;
          } else {
            pendingTasks++;
          }
        });
      }
    }

    // Print the task counts
    print('Total tasks: $totalTasks');
    print('Pending tasks: $pendingTasks');
    print('Completed tasks: $completedTasks');
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    final double completedPercentage =
        totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
    final double pendingPercentage =
        totalTasks > 0 ? (pendingTasks / totalTasks) * 100 : 0;

    final Map<String, double> dataMap = {
      "Pending": pendingTasks.toDouble(),
      "Completed": completedTasks.toDouble(),
    };

    return Scaffold(
      appBar: AppBar(
      
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 5,
        title: Text(
          'Task Overview',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 27 * textScaleFactor,
            fontFamily: 'Roboto',
          ),
        ),
      ),drawer: Drawer(
        backgroundColor: Theme.of(context).primaryColor,
        child: Center(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 50 * textScaleFactor),
            children: [
              Center(
                child: Text(
                  "HELLO ${name.toUpperCase()}",
                  style: TextStyle(color: Colors.white, fontSize: 20 * textScaleFactor),
                ),
              ),
              SizedBox(height: 10 * textScaleFactor),
              Center(
                child: _profileImageUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 50 * textScaleFactor,
                        backgroundImage: NetworkImage(_profileImageUrl),
                      )
                    : CircleAvatar(
                        radius: 50 * textScaleFactor,
                        child: Icon(Icons.account_circle, size: 80 * textScaleFactor, color: Colors.white),
                      ),
              ),
              SizedBox(height: 10 * textScaleFactor),
              UserPickerImage(_updateProfileImage),
              SizedBox(height: 20 * textScaleFactor),
              ListTile(
                leading: Icon(Icons.screen_lock_rotation, color: Colors.white),
                title: Text(
                  isOrientationLocked ? 'Unlock Orientation' : 'Lock Orientation',
                  style: TextStyle(color: Colors.white, fontSize: 17 * textScaleFactor),
                ),
                onTap: _toggleOrientationLock,
              ),
              SizedBox(height: 10 * textScaleFactor),
              ListTile(
                leading: Icon(Icons.settings, color: Colors.white),
                title: Text(
                  'Go to Settings',
                  style: TextStyle(color: Colors.white, fontSize: 17 * textScaleFactor),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
              SizedBox(height: 10 * textScaleFactor),
              ListTile(
                leading: Icon(Icons.task_alt, color: Colors.white),
                title: Text('Completed Tasks', style: TextStyle(color: Colors.white, fontSize: 17 * textScaleFactor)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CompletedTasksScreen()),
                  );
                },
              ),
              SizedBox(height: 300 * textScaleFactor),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Auth(true)),
                    );
                  },
                  child: Column(
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 24 * textScaleFactor),
                      SizedBox(width: 8 * textScaleFactor),
                      Text('Logout', style: TextStyle(color: Colors.white, fontSize: 17 * textScaleFactor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16 * textScaleFactor),
                    child: PieChart(
                      dataMap: dataMap,
                      chartType: ChartType.ring,
                      ringStrokeWidth: 32,
                      chartRadius: mediaQuery.size.width / 2,
                      colorList: [Colors.red, Colors.green],
                      legendOptions: const LegendOptions(
                        legendPosition: LegendPosition.left,
                        showLegendsInRow: false,
                        legendTextStyle: TextStyle(fontSize: 14),
                      ),
                      chartValuesOptions: const ChartValuesOptions(
                        showChartValuesInPercentage: true,
                        showChartValues: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildStatsCard('Total tasks', totalTasks),
                _buildStatsCard('Pending tasks', pendingTasks),
                _buildStatsCard('Completed tasks', completedTasks),
                _buildStatsCard(
                  'Completion percentage',
                  completedPercentage.toStringAsFixed(2) + '%',
                ),
                _buildStatsCard(
                  'Pending percentage',
                  pendingPercentage.toStringAsFixed(2) + '%',
                ),
                const SizedBox(height: 20),
                Text(
                  'Productivity Tip:',
                  style: TextStyle(
                    fontSize: 18 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _getProductivityTip(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16 * textScaleFactor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              value.toString(),
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductivityTip() {
    final tips = [
  'Break tasks into smaller, manageable chunks.',
  'Set specific goals and deadlines for each task.',
  'Prioritize your tasks based on urgency and importance.',
  'Eliminate distractions to stay focused.',
  'Take regular breaks to recharge and avoid burnout.',
  'Use the Pomodoro Technique: work for 25 minutes, then take a 5-minute break.',
  'Keep a daily to-do list and check off completed tasks.',
  'Set SMART goals (Specific, Measurable, Achievable, Relevant, Time-bound).',
  'Plan your day the night before to start with a clear focus.',
  'Limit multitasking to avoid spreading yourself too thin.',
  'Use productivity tools and apps to help manage your tasks and time.',
  'Organize your workspace to reduce clutter and improve efficiency.',
  'Delegate tasks when possible to focus on high-priority work.',
  'Avoid procrastination by tackling the most challenging tasks first.',
  'Set aside specific times for checking emails and messages.',
  'Use the two-minute rule: if a task can be completed in two minutes, do it immediately.',
  'Create a productive morning routine to start your day off right.',
  'Eliminate unnecessary meetings or keep them brief and to the point.',
  'Break large projects into smaller milestones to track progress more easily.',
  'Set boundaries with work and personal life to maintain a healthy balance.',
  'Use visual aids like charts and graphs to track progress and stay motivated.',
  'Practice mindfulness or meditation to improve focus and reduce stress.',
  'Establish a regular work schedule to build consistency and routine.',
  'Keep your digital files and documents organized for quick access.',
  'Avoid checking social media or unrelated websites during work hours.',
  'Invest in ergonomic furniture and tools to improve comfort and productivity.',
  'Practice the 80/20 rule: focus on the 20% of tasks that provide 80% of the results.',
  'Stay hydrated and eat nutritious meals to maintain energy levels.',
  'Use a task management system to prioritize and track tasks effectively.',
  'Regularly review and adjust your goals and strategies based on progress.',
  'Create a “Not-To-Do” list to avoid time-wasting activities.',
  'Reward yourself for completing tasks to stay motivated.',
  'Learn to say no to additional tasks that don’t align with your priorities.',
  'Use keyboard shortcuts to streamline repetitive tasks on your computer.',
  'Maintain a positive mindset and stay resilient in the face of challenges.',
  'Implement the Eisenhower Matrix to prioritize tasks based on urgency and importance.',
  'Minimize decision fatigue by setting routines and automating repetitive decisions.',
  'Limit your use of notifications to stay focused on important tasks.',
  'Develop a habit of reflecting on your daily accomplishments and areas for improvement.',
  'Utilize time blocking to allocate specific periods for different tasks or activities.',
  'Set clear deadlines for each phase of a project to ensure timely completion.',
  'Create templates for recurring tasks to save time on repetitive work.',
  'Stay informed about productivity techniques and continuously seek improvement.',
  'Keep your goals visible and remind yourself of them regularly.',
  'Use affirmations and positive reinforcement to build confidence and motivation.',
  'Establish a clear purpose for each task to stay focused and driven.',
  'Learn and practice effective time management skills to maximize productivity.',
  'Surround yourself with supportive and like-minded individuals.',
  'Track your progress and celebrate milestones to stay motivated and engaged.',
  'Practice effective communication to reduce misunderstandings and improve collaboration.',
  'Keep a journal to document ideas, reflections, and progress over time.',
  'Stay adaptable and be open to trying new methods or tools that could enhance productivity.',
  'Remember that productivity is a journey, and continuously strive for improvement.'
];

    return tips[(DateTime.now().millisecondsSinceEpoch % tips.length)];
  }
}
