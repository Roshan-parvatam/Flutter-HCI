import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'auth.dart';
import 'completed_tasks_screen.dart';
import 'settings.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class Calender extends StatefulWidget {
  const Calender({super.key});

  @override
  State<Calender> createState() => _HomeWidgetsState();
}

class _HomeWidgetsState extends State<Calender> {
  String _profileImageUrl = '';
  String name = '';

  bool isOrientationLocked = false;

  List<Appointment> _appointments = [];

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

  Future<void> _fetchTasks() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        List<Appointment> appointments = [];

        // Fetch group tasks
        final groupsSnapshot =
            await FirebaseFirestore.instance.collection('groups').get();
        print('Groups fetched: ${groupsSnapshot.docs.length}');

        for (var groupDoc in groupsSnapshot.docs) {
          print('Fetching tasks for group: ${groupDoc.id}');

          final String groupName =
              groupDoc.data()['groupName'] ?? 'Unnamed Group';
          final tasksSnapshot =
              await groupDoc.reference.collection('tasks').get();
          print(
              'Tasks fetched for group ${groupDoc.id}: ${tasksSnapshot.docs.length}');

          for (var taskDoc in tasksSnapshot.docs) {
            final taskData = taskDoc.data();

            // Filter tasks based on member field
            final String taskMember = taskData['member'] ?? '';
            if (taskMember != user.uid) {
              continue; // Skip tasks not assigned to the current user
            }

            DateTime? startTime;
            DateTime? endTime;

            if (taskData['date'] != null) {
              try {
                if (taskData['date'] is Timestamp) {
                  final timestamp = taskData['date'] as Timestamp;
                  final date = timestamp.toDate();
                  startTime = DateTime(date.year, date.month, date.day);
                }
              } catch (e) {
                print('Invalid date format for task: ${taskDoc.id}');
                startTime = null;
              }
            }

            if (taskData['time'] != null && startTime != null) {
              try {
                endTime = _parseEndTimeString(taskData['time'], startTime);
              } catch (e) {
                print('Invalid time format for task: ${taskDoc.id}');
                endTime = startTime?.add(Duration(hours: 1));
              }
            } else {
              endTime = startTime?.add(Duration(hours: 1));
            }

            final String subject = taskData['name'] ?? 'No Title';

            print(
                'Task: ${taskDoc.id}, Subject: $subject, Start Time: $startTime, End Time: $endTime, Group: $groupName');

            appointments.add(
              Appointment(
                startTime: startTime ?? DateTime.now(),
                endTime: endTime ??
                    startTime?.add(Duration(hours: 1)) ??
                    DateTime.now().add(Duration(hours: 1)),
                subject: '$subject - $groupName',
                color: Colors.blue,
              ),
            );
          }
        }

        // Fetch personal tasks
        final userTasksSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .get();
        print('Personal tasks fetched: ${userTasksSnapshot.docs.length}');

        for (var taskDoc in userTasksSnapshot.docs) {
          final taskData = taskDoc.data();

          DateTime? startTime;
          DateTime? endTime;

          if (taskData['date'] != null) {
            try {
              if (taskData['date'] is Timestamp) {
                final timestamp = taskData['date'] as Timestamp;
                final date = timestamp.toDate();
                startTime = DateTime(date.year, date.month, date.day);
              }
            } catch (e) {
              print('Invalid date format for task: ${taskDoc.id}');
              startTime = null;
            }
          }

          if (taskData['time'] != null && startTime != null) {
            try {
              endTime = _parseEndTimeString(taskData['time'], startTime);
            } catch (e) {
              print('Invalid time format for task: ${taskDoc.id}');
              endTime = startTime?.add(Duration(hours: 1));
            }
          } else {
            endTime = startTime?.add(Duration(hours: 1));
          }

          final String subject = taskData['name'] ?? 'No Title';

          print(
              'Personal Task: ${taskDoc.id}, Subject: $subject, Start Time: $startTime, End Time: $endTime');

          appointments.add(
            Appointment(
              startTime: startTime ?? DateTime.now(),
              endTime: endTime ??
                  startTime?.add(Duration(hours: 1)) ??
                  DateTime.now().add(Duration(hours: 1)),
              subject: subject,
              color: Colors.green, // Different color for personal tasks
            ),
          );
        }

        print('Total appointments fetched: ${appointments.length}');

        setState(() {
          _appointments = appointments;
        });
      } catch (e) {
        print('Error fetching tasks: $e');
      }
    } else {
      print('No user is currently signed in.');
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

  DateTime _parseEndTimeString(String timeString, DateTime startDate) {
    try {
      final timeFormat =
          DateFormat('h:mm a'); // Custom format for parsing "7:00 PM"
      final time = timeFormat.parse(timeString);
      return DateTime(startDate.year, startDate.month, startDate.day, time.hour,
          time.minute);
    } catch (e) {
      print('Error parsing time string: $timeString. Error: $e');
      return startDate
          .add(Duration(hours: 1)); // Default to 1 hour if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Calendar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 27,
          ),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 50),
          children: [
            Center(
              child: Text(
                "HELLO ${name.toUpperCase()}",
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _profileImageUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(_profileImageUrl),
                    )
                  : const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.account_circle,
                          size: 80, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading:
                  const Icon(Icons.screen_lock_rotation, color: Colors.white),
              title: Text(
                isOrientationLocked ? 'Unlock Orientation' : 'Lock Orientation',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: _toggleOrientationLock,
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(
                Icons.task_alt,
                color: Colors.white,
              ),
              title: const Text(
                'Completed Tasks',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CompletedTasksScreen()),
                );
              },
            ),
            const SizedBox(height: 300),
            Center(
              child: TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Auth(true)),
                  );
                },
                child: const Column(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          ],
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
        child: Container(
          
          child: SfCalendar(
            view: CalendarView.day,
            dataSource: TaskDataSource(_appointments),
            monthViewSettings: const MonthViewSettings(
              appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
            ),
          ),
        ),
      ),
    );
  }
}

class TaskDataSource extends CalendarDataSource {
  TaskDataSource(List<Appointment> source) {
    appointments = source;
  }
}
