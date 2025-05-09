import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'settings.dart';
import 'auth.dart';
import 'dart:io';
import 'completed_tasks_screen.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() {
    return _CreateTaskScreenState();
  }
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _profileImageUrl = '';
  String name = '';
  bool isOrientationLocked = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileImageUrl();
  }

  Future<void> _fetchProfileImageUrl() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('client')
            .doc('details')
            .get();

        if (docSnapshot.exists) {
          final userData = docSnapshot.data();
          if (userData != null) {
            final imageUrl = userData['imageURL'] as String?;
            final displayName = userData['displayName'] as String?;
            setState(() {
              _profileImageUrl = imageUrl ?? '';
              name = displayName ?? 'No Name';
            });
          }
        }
      }
    } catch (error) {
      print('Error fetching profile data: $error');
    }
  }

  Future<void> _updateProfileImage(File pickedImage) async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user.uid}.jpg');
        await storageRef.putFile(pickedImage);
        final imageURL = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
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

  void _toggleOrientationLock() {
    setState(() {
      isOrientationLocked = !isOrientationLocked;
      if (isOrientationLocked) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat.yMd().format(_selectedDate!);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _selectedTime!.format(context);
      });
    }
  }

  Future<void> _showTaskFormDialog(CollectionReference tasksCollection) async {
    _taskNameController.clear();
    _descriptionController.clear();
    _dateController.clear();
    _timeController.clear();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Task'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: ListBody(
                children: <Widget>[
                  TextFormField(
                    controller: _taskNameController,
                    decoration: const InputDecoration(labelText: 'Task Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter task name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(labelText: 'Date'),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context);
                    },
                  ),
                  TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(labelText: 'Time'),
                    readOnly: true,
                    onTap: () {
                      _selectTime(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  tasksCollection.add({
                    'name': _taskNameController.text,
                    'description': _descriptionController.text,
                    'date': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
                    'time': _selectedTime != null ? _selectedTime!.format(context) : null,
                    'isCompleted': false,
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }

    final CollectionReference tasksCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks');

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "My Tasks",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 27 * textScaleFactor,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      drawer: Drawer(
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: 50 * textScaleFactor),
          children: [
            Center(
              child: Text(
                "HELLO ${name.toUpperCase()}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20 * textScaleFactor,
                ),
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
                      child: Icon(
                        Icons.account_circle,
                        size: 80 * textScaleFactor,
                        color: Colors.white,
                      ),
                    ),
            ),
            SizedBox(height: 20 * textScaleFactor),
            ListTile(
              leading: Icon(
                Icons.screen_lock_rotation,
                color: Colors.white,
                size: 24 * textScaleFactor,
              ),
              title: Text(
                isOrientationLocked
                    ? 'Unlock Orientation'
                    : 'Lock Orientation',
                style: TextStyle(color: Colors.white, fontSize: 16 * textScaleFactor),
              ),
              onTap: _toggleOrientationLock,
            ),
            SizedBox(height: 10 * textScaleFactor),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: Colors.white,
                size: 24 * textScaleFactor,
              ),
              title: Text(
                'Settings',
                style: TextStyle(color: Colors.white, fontSize: 16 * textScaleFactor),
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
              leading: Icon(
                Icons.check,
                color: Colors.white,
                size: 24 * textScaleFactor,
              ),
              title: Text(
                'Completed Tasks',
                style: TextStyle(color: Colors.white, fontSize: 16 * textScaleFactor),
              ),
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
                    Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 24 * textScaleFactor,
                    ),
                    SizedBox(width: 8 * textScaleFactor),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.white, fontSize: 16 * textScaleFactor),
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
        child: Padding(
          padding: EdgeInsets.all(16 * textScaleFactor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StreamBuilder(
                  stream: tasksCollection
                      .where('isCompleted', isEqualTo: false)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading tasks'));
                    }

                    final tasks = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        var task = tasks[index];
                        return Dismissible(
                          key: Key(task.id),
                          background: _buildSwipeActionLeft(),
                          secondaryBackground: _buildSwipeActionRight(),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              _editTask(task, tasksCollection);
                              return false;
                            } else {
                              return await _confirmDeleteTask(task.id, tasksCollection);
                            }
                          },
                          child: Card(
                            elevation: 4 * textScaleFactor,
                            margin: EdgeInsets.symmetric(vertical: 8 * textScaleFactor),
                            child: CheckboxListTile(
                              title: Text(task['name']),
                              subtitle: Text(task['description'] ?? ''),
                              value: task['isCompleted'],
                              onChanged: (bool? value) {
                                tasksCollection.doc(task.id).update({
                                  'isCompleted': value!,
                                });
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _showTaskFormDialog(tasksCollection);
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20 * textScaleFactor, vertical: 15 * textScaleFactor),
                  textStyle: TextStyle(fontSize: 20 * textScaleFactor),
                ),
                child: const Text('Create Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeActionLeft() {
    return Container(
      color: Colors.blue,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSwipeActionRight() {
    return Container(
      color: Colors.red,
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.delete, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _editTask(QueryDocumentSnapshot task, CollectionReference tasksCollection) async {
    _taskNameController.text = task['name'];
    _descriptionController.text = task['description'] ?? '';
    _selectedDate = task['date']?.toDate();
    _selectedTime = task['time'] != null
        ? TimeOfDay(
            hour: int.parse(task['time'].split(':')[0]),
            minute: int.parse(task['time'].split(':')[1]),
          )
        : null;

    _dateController.text = _selectedDate != null
        ? DateFormat.yMd().format(_selectedDate!)
        : '';
    _timeController.text = _selectedTime != null
        ? _selectedTime!.format(context)
        : '';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: ListBody(
                children: <Widget>[
                  TextFormField(
                    controller: _taskNameController,
                    decoration: const InputDecoration(labelText: 'Task Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter task name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(labelText: 'Date'),
                    readOnly: true,
                    onTap: () {
                      _selectDate(context);
                    },
                  ),
                  TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(labelText: 'Time'),
                    readOnly: true,
                    onTap: () {
                      _selectTime(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  tasksCollection.doc(task.id).update({
                    'name': _taskNameController.text,
                    'description': _descriptionController.text,
                    'date': _selectedDate != null
                        ? Timestamp.fromDate(_selectedDate!)
                        : null,
                    'time': _selectedTime != null
                        ? _selectedTime!.format(context)
                        : null,
                    'isCompleted': false,
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeleteTask(String taskId, CollectionReference tasksCollection) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                tasksCollection.doc(taskId).delete();
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }
}
