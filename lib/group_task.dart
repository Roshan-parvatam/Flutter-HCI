import 'dart:io'; // Import for File
import 'package:file_picker/file_picker.dart'; // Import for file picker
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs
import 'package:awesome_notifications/awesome_notifications.dart';

class CreateTaskScreen extends StatefulWidget {
  final String groupID;

  const CreateTaskScreen({super.key, required this.groupID});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedMemberId;
  String? _selectedMemberName;
  String? _fileUrl; // New field for file URL

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isAdmin = false;
  String admin = "";
  String adminID = "";
  bool _isUploading = false; // Track uploading state

  @override
  void initState() {
    super.initState();
    _checkIfUserIsAdmin();
  }

  Future<void> _checkIfUserIsAdmin() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final groupCollection = FirebaseFirestore.instance.collection('groups');
      final groupDocumentReference = groupCollection.doc(widget.groupID);
      String getName(String res) {
        return res.substring(res.indexOf("_") + 1);
      }

      String getId(String res) {
        return res.substring(0, res.indexOf("_"));
      }

      DocumentSnapshot groupSnapshot = await groupDocumentReference.get();

      String ad = groupSnapshot.get("admin");
      admin = getName(ad);
      adminID = getId(ad);
    } catch (error) {
      print('Error checking admin status: $error');
    }
    setState(() {
      if (user.uid == adminID) {
        isAdmin = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }

    final CollectionReference tasksCollection = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupID)
        .collection('tasks');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pending Tasks',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: tasksCollection
                            .where('isCompleted',
                                isEqualTo: false) // Pending tasks
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading tasks'));
                          }

                          final tasks = snapshot.data?.docs
                                  .where((task) =>
                                      isAdmin ||
                                      task['member'] == user.uid ||
                                      task['member'] == null)
                                  .toList() ??
                              [];

                          return ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              var task = tasks[index];
                              return Dismissible(
                                key: Key(task.id),
                                background: _buildSwipeActionLeft(),
                                secondaryBackground: _buildSwipeActionRight(),
                                confirmDismiss: (direction) async {
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    _editTask(task);
                                    return false;
                                  } else {
                                    return await _confirmDeleteTask(task.id);
                                  }
                                },
                                child: Card(
                                  elevation: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    title: Text(task['name']),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(task['description'] ?? ''),
                                        if (task['fileUrl'] != null &&
                                            task['fileUrl'].isNotEmpty)
                                          Column(
                                            children: [
                                              TextButton(
                                                onPressed: () async {
                                                  // Open file in browser
                                                  await launch(task['fileUrl']);
                                                },
                                                child:
                                                    const Text('Download File'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  setState(() {
                                                    _isUploading = true;
                                                  });
                                                  await FirebaseStorage.instance
                                                      .refFromURL(
                                                          task['fileUrl'])
                                                      .delete();
                                                  await tasksCollection
                                                      .doc(task.id)
                                                      .update({'fileUrl': ''});
                                                  setState(() {
                                                    _isUploading = false;
                                                  });
                                                },
                                                child:
                                                    const Text('Remove File'),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  // Open file in browser for preview
                                                  await launch(task['fileUrl']);
                                                },
                                                child:
                                                    const Text('Preview File'),
                                              ),
                                            ],
                                          ),
                                        if (task['member'] == user.uid &&
                                            !task['isCompleted'])
                                          ElevatedButton(
                                            onPressed: () {
                                              _uploadFile(task.id);
                                            },
                                            child: const Text('Upload File'),
                                          ),
                                      ],
                                    ),
                                    trailing: Checkbox(
                                      value: task['isCompleted'],
                                      onChanged: (bool? value) {
                                        tasksCollection.doc(task.id).update({
                                          'isCompleted': value!,
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Completed Tasks',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: tasksCollection
                            .where('isCompleted',
                                isEqualTo: true) // Completed tasks
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading tasks'));
                          }

                          final tasks = snapshot.data?.docs
                                  .where((task) =>
                                      isAdmin ||
                                      task['member'] == user.uid ||
                                      task['member'] == null)
                                  .toList() ??
                              [];

                          return ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              var task = tasks[index];
                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text(task['name']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(task['description'] ?? ''),
                                      if (task['fileUrl'] != null &&
                                          task['fileUrl'].isNotEmpty)
                                        Column(
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                // Open file in browser
                                                await launch(task['fileUrl']);
                                              },
                                              child:
                                                  const Text('Download File'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                // Open file in browser for preview
                                                await launch(task['fileUrl']);
                                              },
                                              child: const Text('Preview File'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  trailing: Checkbox(
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
                  ],
                ),
              ),
              if (isAdmin)
                ElevatedButton(
                  onPressed: () {
                    _showTaskFormDialog(tasksCollection);
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(60, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Create Task'),
                      SizedBox(width: 4),
                      Icon(Icons.create, size: 16),
                    ],
                  ),
                ),

              if (_isUploading)
                Center(
                    child:
                        CircularProgressIndicator()), // Show uploading indicator
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeActionLeft() {
    return Container(
      color: Colors.blue,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.edit, color: Colors.white),
    );
  }

  Widget _buildSwipeActionRight() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  Future<void> _showTaskFormDialog(CollectionReference tasksCollection,
      [QueryDocumentSnapshot? task]) async {
    if (task != null) {
      _taskNameController.text = task['name'];
      _descriptionController.text = task['description'] ?? '';
      _selectedDate = (task['date'] as Timestamp?)?.toDate();
      _selectedTime =
          _selectedDate != null ? TimeOfDay.fromDateTime(_selectedDate!) : null;
      _dateController.text = _selectedDate != null
          ? DateFormat.yMMMd().format(_selectedDate!)
          : '';
      _timeController.text =
          _selectedTime != null ? _selectedTime!.format(context) : '';
      _selectedMemberId = task['member'];
      _selectedMemberName = await _getMemberName(_selectedMemberId!);
      _fileUrl = task['fileUrl'] ?? '';
    } else {
      _taskNameController.clear();
      _descriptionController.clear();
      _selectedDate = null;
      _selectedTime = null;
      _dateController.clear();
      _timeController.clear();
      _selectedMemberId = null;
      _selectedMemberName = null;
      _fileUrl = '';
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(task == null ? 'Create New Task' : 'Edit Task'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _taskNameController,
                    decoration: const InputDecoration(labelText: 'Task Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a task name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextFormField(
                    readOnly: true,
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      hintText: 'Select a date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );

                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                          _dateController.text =
                              DateFormat.yMMMd().format(_selectedDate!);
                        });
                      }
                    },
                  ),
                  TextFormField(
                    readOnly: true,
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      hintText: 'Select a time',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    onTap: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );

                      if (pickedTime != null) {
                        setState(() {
                          _selectedTime = pickedTime;
                          _timeController.text = _selectedTime!.format(context);
                        });
                      }
                    },
                  ),
                  TextFormField(
                    readOnly: true,
                    controller: _memberController,
                    decoration: const InputDecoration(
                      labelText: 'Assigned member',
                      hintText: 'Assigned Member',
                      suffixIcon: Icon(Icons.person),
                    ),
                  ),
                  // Show only when creating a new task
                  ElevatedButton(
                    onPressed: () {
                      _showMemberSelectionDialog();
                      if (_selectedMemberName != null) {
                        setState(() {
                          _memberController.text =
                              _selectedMemberName.toString();
                        });
                      }
                    },
                    child: const Text('Select Member'),
                  ),
                  if (_fileUrl != null &&
                      _fileUrl!.isNotEmpty) // Show if file URL exists
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: TextButton(
                        onPressed: () async {
                          // Open file in browser
                          await launch(_fileUrl!);
                        },
                        child: const Text('Download File'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            if (isAdmin) // Only show 'Create' or 'Update' button for admins
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    if (task == null) {
                      // Create new task
                      await tasksCollection.add({
                        'name': _taskNameController.text,
                        'description': _descriptionController.text,
                        'date': _selectedDate != null
                            ? Timestamp.fromDate(_selectedDate!)
                            : null,
                        'time': _selectedTime != null
                            ? _selectedTime!.format(context)
                            : null,
                        'member': _selectedMemberId,
                        'fileUrl': _fileUrl ?? '',
                        'isCompleted': false,
                      });

                      // Send notification
                      _sendNotification(
                          _selectedMemberId!, _taskNameController.text);
                    } else {
                      // Update existing task
                      await tasksCollection.doc(task.id).update({
                        'name': _taskNameController.text,
                        'description': _descriptionController.text,
                        'date': _selectedDate != null
                            ? Timestamp.fromDate(_selectedDate!)
                            : null,
                        'time': _selectedTime != null
                            ? _selectedTime!.format(context)
                            : null,
                        'member': _selectedMemberId,
                        'fileUrl': _fileUrl ?? '',
                      });
                    }

                    Navigator.of(context).pop();
                  }
                },
                child: Text(task == null ? 'Create Task' : 'Update Task'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _sendNotification(String memberId, String taskName) async {
    final memberDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(memberId)
        .get();
    final memberName = memberDoc.data()?['name'] ?? 'Member';

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'basic_channel',
        title: 'New Task Assigned',
        body: 'Hello $memberName, you have been assigned a new task: $taskName',
      ),
    );
  }

  Future<void> _showMemberSelectionDialog() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final CollectionReference groupCollection =
        FirebaseFirestore.instance.collection('groups');

    final DocumentSnapshot groupSnapshot =
        await groupCollection.doc(widget.groupID).get();
    if (!groupSnapshot.exists) return;

    final List<dynamic> membersList =
        groupSnapshot.get('members') as List<dynamic>;

    final selectedMember = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Member'),
          content: SingleChildScrollView(
            child: ListBody(
              children: membersList.map((member) {
                final parts = member.toString().split('_');
                final memberId = parts[0];
                final memberName = parts[1];
                return ListTile(
                  title: Text(memberName),
                  onTap: () {
                    Navigator.of(context)
                        .pop({'id': memberId, 'name': memberName});
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedMember != null) {
      setState(() {
        _selectedMemberId = selectedMember['id'];
        _selectedMemberName = selectedMember['name'];
      });
    }
  }

  Future<String?> _getMemberName(String memberId) async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupID)
          .collection('members')
          .doc(memberId)
          .get();

      return memberDoc.data()?['name'];
    } catch (e) {
      print('Error getting member name: $e');
      return null;
    }
  }

  Future<void> _uploadFile(String taskId) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path!);
      final fileName = path.basename(file.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('task_files')
          .child(taskId)
          .child(fileName);

      try {
        setState(() {
          _isUploading = true;
        });

        await ref.putFile(file);
        final fileUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupID)
            .collection('tasks')
            .doc(taskId)
            .update({'fileUrl': fileUrl});

        setState(() {
          _fileUrl = fileUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        print('Error uploading file: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload file')),
        );
      }
    }
  }

  Future<bool> _confirmDeleteTask(String taskId) async {
    if (!isAdmin) {
      // If the user is not an admin, return false
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can delete tasks')),
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupID)
                    .collection('tasks')
                    .doc(taskId)
                    .delete();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _editTask(QueryDocumentSnapshot task) {
    _showTaskFormDialog(
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupID)
          .collection('tasks'),
      task,
    );
  }
}
