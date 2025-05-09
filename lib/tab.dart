import 'package:flutter/material.dart';
import 'chatpage.dart';
import 'group_task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'groupinfo.dart';

class TaskManagerScreen extends StatefulWidget {
  final String userName;
  final String groupID;
  final String groupName;

  const TaskManagerScreen({
    Key? key,
    required this.userName,
    required this.groupID,
    required this.groupName,
  }) : super(key: key);

  @override
  State<TaskManagerScreen> createState() {
    return _TaskManagerScreenState();
  }
}

class _TaskManagerScreenState extends State<TaskManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }
  final groupsCollection = FirebaseFirestore.instance.collection('groups');
  getChats(String groupId) {
    return groupsCollection
        .doc(groupId)
        .collection("messages")
        .orderBy("time")
        .snapshots();
  }
    Future getAdmin(String groupId) async {
    DocumentReference d = groupsCollection.doc(groupId);
    DocumentSnapshot documentSnapshot = await d.get();
    return documentSnapshot['admin'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Text(
          widget.groupName,
          style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold, fontSize: 27),
        ),
        backgroundColor:Colors.blueAccent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Tasks'),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupInfo(
                        groupID: widget.groupID,
                        groupName: widget.groupName,
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.info),
              color: Colors.white)
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            ChatPage(
              userName: widget.userName,
              groupID: widget.groupID,
              groupName: widget.groupName,
            ),
            CreateTaskScreen(groupID:widget.groupID),
          ],
        ),
      ),
    );
  }
}