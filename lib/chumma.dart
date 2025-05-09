import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedMemberId;
  String? _selectedMemberName;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isAdmin = false;
  String admin = "";
  String adminID = "";

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
      backgroundColor: Theme.of(context).primaryColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: tasksCollection.snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading tasks'));
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
                          if (direction == DismissDirection.startToEnd) {
                            _editTask(task);
                            return false;
                          } else {
                            return await _confirmDeleteTask(task.id);
                          }
                        },
                        child: Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
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
            if (isAdmin)
              ElevatedButton(
                onPressed: () {
                  _showTaskFormDialog(tasksCollection);
                },
                child: const Text('Create Task'),
              ),
          ],
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
    } else {
      _taskNameController.clear();
      _descriptionController.clear();
      _selectedDate = null;
      _selectedTime = null;
      _dateController.clear();
      _timeController.clear();
      _selectedMemberId = null;
      _selectedMemberName = null;
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
                    controller:
                        TextEditingController(text: _selectedMemberName),
                    decoration: InputDecoration(
                      labelText: 'Member',
                      hintText: _selectedMemberName != null
                          ? _selectedMemberName!
                          : 'Please select a member',
                      suffixIcon: const Icon(Icons.person),
                    ),
                    onTap: _selectMember,
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
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  if (task == null) {
                    _createTask(tasksCollection);
                  } else {
                    _updateTask(tasksCollection, task.id);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createTask(CollectionReference tasksCollection) async {
    await tasksCollection.add({
      'name': _taskNameController.text,
      'description': _descriptionController.text,
      'date': _selectedDate != null
          ? Timestamp.fromDate(DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime?.hour ?? 0,
              _selectedTime?.minute ?? 0,
            ))
          : null,
      'isCompleted': false,
      'member': _selectedMemberId,
    });
  }

  Future<void> _updateTask(
      CollectionReference tasksCollection, String id) async {
    await tasksCollection.doc(id).update({
      'name': _taskNameController.text,
      'description': _descriptionController.text,
      'date': _selectedDate != null
          ? Timestamp.fromDate(DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime?.hour ?? 0,
              _selectedTime?.minute ?? 0,
            ))
          : null,
      'member': _selectedMemberId,
    });
  }

  Future<bool> _confirmDeleteTask(String id) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text('Are you sure you want to delete this task?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _selectMember() async {
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
    final memberDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupID)
        .collection('members')
        .doc(memberId)
        .get();
    return memberDoc.data()?['name'];
  }

  void _editTask(QueryDocumentSnapshot task) {
    _showTaskFormDialog(
        FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupID)
            .collection('tasks'),
        task);
  }
}