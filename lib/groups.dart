import 'package:collab_prog/settings.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'userpicker.dart';
import 'package:collab_prog/auth.dart';
import 'package:flutter/services.dart';
import 'search.dart';
import 'group_tile.dart';
import 'package:lottie/lottie.dart';
import 'completed_tasks_screen.dart';

String name = '';

class Group extends StatefulWidget {
  const Group({Key? key}) : super(key: key);

  @override
  State<Group> createState() => _GroupState();
}

class _GroupState extends State<Group> {
  String _profileImageUrl = '';

  bool isDarkTheme = false;
  bool isOrientationLocked = false;
  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;
  String groupname = '';

  @override
  void initState() {
    super.initState();
    _fetchProfileImageUrl();
  }

  String getId(String res) {
    return res.substring(0, res.indexOf("_"));
  }

  String getName(String res) {
    return res.substring(res.indexOf("_") + 1);
  }
  

  Future<void> _fetchProfileImageUrl() async {
    try {
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
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
          } else {
            print('User data is null');
          }
        } else {
          print('Document does not exist');
        }
      } else {
        print('Current user is null');
      }
    } catch (error) {
      print('Error fetching profile data: $error');
    }
  }

  Future<void> _updateProfileImage(File pickedImage) async {
    try {
      if (user != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user!.uid}.jpg');
        await storageRef.putFile(pickedImage);
        final imageURL = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
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

  Future<void> createGroup(
      String userName, String userId, String groupName) async {
    final groupCollection = FirebaseFirestore.instance.collection('groups');

    final groupDocumentReference = await groupCollection.add({
      "groupName": groupName,
      "groupIcon": "",
      "admin": "${userId}_$userName",
      "members": [],
      "groupId": "",
      "recentMessage": "",
      "recentMessageSender": "",
    });

    await groupDocumentReference.update({
      "members": FieldValue.arrayUnion(["${userId}_$userName"]),
      "groupId": groupDocumentReference.id,
    });

    final userDocumentReference = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('client')
        .doc('details');

    return await userDocumentReference.update({
      "groups":
          FieldValue.arrayUnion(["${groupDocumentReference.id}_$groupName"]),
    });
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

  void _showCreateGroupDialog(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Create a group",
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 20 * textScaleFactor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isLoading
                  ? Center(
                      child: Lottie.asset(
                        'assets/animations/loading_animation.json',
                        width: 150 * textScaleFactor,
                        height: 150 * textScaleFactor,
                        fit: BoxFit.cover,
                      ),
                    )
                  : TextField(
                      onChanged: (val) {
                        setState(() {
                          groupname = val;
                        });
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2 * textScaleFactor,
                          ),
                          borderRadius: BorderRadius.circular(20 * textScaleFactor),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2 * textScaleFactor,
                          ),
                          borderRadius: BorderRadius.circular(20 * textScaleFactor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2 * textScaleFactor,
                          ),
                          borderRadius: BorderRadius.circular(20 * textScaleFactor),
                        ),
                      ),
                    )
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * textScaleFactor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (groupname.isNotEmpty) {
                  setState(() {
                    _isLoading = true;
                  });
                  try {
                    await createGroup(name, user!.uid, groupname);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Group created successfully',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16 * textScaleFactor,
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error creating group: $e',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16 * textScaleFactor,
                          ),
                        ),
                      ),
                    );
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text(
                "Create",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * textScaleFactor,
                ),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    return MaterialApp(
      home: Scaffold(
       
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Search()),
                );
              },
              icon: Icon(Icons.search, size: 24 * textScaleFactor),
              color: Colors.white,
            )
          ],
          elevation: 0,
          centerTitle: true,
          backgroundColor: Theme.of(context).primaryColor,
          title: Text(
            "Groups",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 27 * textScaleFactor,
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: Theme.of(context).primaryColor,
          child: Center(
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
                          child: Icon(Icons.account_circle,
                              size: 80 * textScaleFactor, color: Colors.white),
                        ),
                ),
                SizedBox(height: 10 * textScaleFactor),
                UserPickerImage(_updateProfileImage),
                SizedBox(height: 20 * textScaleFactor),
                ListTile(
                  leading: Icon(Icons.screen_lock_rotation, color: Colors.white, size: 24 * textScaleFactor),
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
                  leading: Icon(Icons.settings, color: Colors.white, size: 24 * textScaleFactor),
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
                  leading: Icon(Icons.task_alt, color: Colors.white, size: 24 * textScaleFactor),
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
                        Icon(Icons.logout, color: Colors.white, size: 24 * textScaleFactor),
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
            padding: EdgeInsets.all(16.0 * textScaleFactor),
            child: GroupListStream(isLoading: _isLoading),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showCreateGroupDialog(context);
          },
          elevation: 0,
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.add, color: Colors.white, size: 30 * textScaleFactor),
        ),
      ),
    );
  }
}

class GroupListStream extends StatefulWidget {
  final bool isLoading;
  const GroupListStream({required this.isLoading});

  @override
  _GroupListStreamState createState() => _GroupListStreamState();
}

class _GroupListStreamState extends State<GroupListStream> {
  late Stream<DocumentSnapshot> groups;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      groups = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('client')
          .doc('details')
          .snapshots();
    } else {
      groups = Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    if (widget.isLoading) {
      return Center(
        child: Lottie.asset(
          'assets/animations/loading_animation.json',
          width: 150 * textScaleFactor,
          height: 150 * textScaleFactor,
        ),
      );
    }
    return groupList();
  }

  Widget groupList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: groups,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
          );
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading groups'));
        }

        if (snapshot.hasData) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;

          if (data != null &&
              data['groups'] != null &&
              (data['groups'] as List).isNotEmpty) {
            final groupList = data['groups'];
            return ListView.builder(
              itemCount: groupList.length,
              itemBuilder: (context, index) {
                final reverseIndex = groupList.length - index - 1;
                return GroupTile(
                  groupID: getId(groupList[reverseIndex]),
                  groupName: getName(groupList[reverseIndex]),
                  userName: name,
                );
              },
            );
          } else {
            return noGroupWidget();
          }
        } else {
          return const Center(child: Text('No groups data available'));
        }
      },
    );
  }

  String getId(String res) {
    return res.substring(0, res.indexOf("_"));
  }

  String getName(String res) {
    return res.substring(res.indexOf("_") + 1);
  }

  Widget noGroupWidget() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 25 * MediaQuery.of(context).textScaleFactor),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: Colors.black, size: 75 * MediaQuery.of(context).textScaleFactor),
            SizedBox(height: 20 * MediaQuery.of(context).textScaleFactor),
            Text(
              "No groups to display, please join a group",
              style: TextStyle(
                color: Colors.black,
                fontSize: 16 * MediaQuery.of(context).textScaleFactor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
