import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class CompletedTasksScreen extends StatelessWidget {
  const CompletedTasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }

    final CollectionReference personalTasksCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks');

    final CollectionReference groupTasksCollection = FirebaseFirestore.instance
        .collection('groups');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          'Completed Tasks',
          style: TextStyle(fontSize: 20 * textScaleFactor),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<List<DocumentSnapshot>>(
          stream: combineStreams(user.uid, personalTasksCollection, groupTasksCollection),
          builder: (context, AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error loading tasks'));
            }

            final tasks = snapshot.data ?? [];

            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                var task = tasks[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8 * textScaleFactor, horizontal: 16 * textScaleFactor),
                  child: Card(
                    elevation: 4 * textScaleFactor,
                    margin: EdgeInsets.symmetric(vertical: 8 * textScaleFactor),
                    child: CheckboxListTile(
                      title: Text(
                        task['name'],
                        style: TextStyle(fontSize: 18 * textScaleFactor),
                      ),
                      subtitle: Text(
                        task['description'] ?? '',
                        style: TextStyle(fontSize: 14 * textScaleFactor),
                      ),
                      value: true, // Always true because this is the completed tasks screen
                      onChanged: (bool? value) {
                        // Toggle the task completion status
                        if (task.reference.path.contains('/users/')) {
                          // Personal task
                          personalTasksCollection.doc(task.id).update({
                            'isCompleted': false, // Set to false to move it back to CreateTaskScreen
                          });
                        } else {
                          // Group task
                          task.reference.update({
                            'isCompleted': false, // Set to false to move it back to CreateTaskScreen
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Stream<List<DocumentSnapshot>> combineStreams(
    String userId,
    CollectionReference personalTasksCollection,
    CollectionReference groupTasksCollection,
  ) async* {
    final personalTasksStream = personalTasksCollection.where('isCompleted', isEqualTo: true).snapshots();
    final groupTasksStream = groupTasksCollection.snapshots().asyncExpand((groupSnapshot) async* {
      final completedGroupTasks = <DocumentSnapshot>[];
      for (var groupDoc in groupSnapshot.docs) {
        final tasksQuerySnapshot = await groupTasksCollection
            .doc(groupDoc.id)
            .collection('tasks')
            .where('member', isEqualTo: userId)
            .where('isCompleted', isEqualTo: true)
            .get();
        completedGroupTasks.addAll(tasksQuerySnapshot.docs);
      }
      yield completedGroupTasks;
    });

    await for (final personalTasks in personalTasksStream) {
      final groupTasks = await groupTasksStream.first;
      yield [...personalTasks.docs, ...groupTasks];
    }
  }
}
