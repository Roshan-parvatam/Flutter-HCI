import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'groups.dart';

class GroupInfo extends StatefulWidget {
  final String groupID;
  final String groupName;

  const GroupInfo({
    super.key,
    required this.groupID,
    required this.groupName,
  });

  @override
  State<GroupInfo> createState() => _GroupInfoState();
}

class _GroupInfoState extends State<GroupInfo> {
  Stream<DocumentSnapshot>? members;
  User? currentUser;
  String email = "";
  String adminID = "";
  String name = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  Future<void> getCurrentUser() async {
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await getMembers();
      await getEmail();
    }
  }

  Future<void> getMembers() async {
    final memberStream = getGroupMembers(widget.groupID);
    setState(() {
      members = memberStream;
    });
  }

  Stream<DocumentSnapshot> getGroupMembers(String groupID) {
    final groupCollection = FirebaseFirestore.instance.collection('groups');
    return groupCollection.doc(groupID).snapshots();
  }

  Future<void> leave() async {
    setState(() {
      isLoading = true;
    });

    try {
      final groupCollection = FirebaseFirestore.instance.collection('groups');
      final userDocumentReference = FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser!.uid)
          .collection('client')
          .doc('details');
      final groupDocumentReference = groupCollection.doc(widget.groupID);

      final documentSnapshot = await userDocumentReference.get();

      if (documentSnapshot.exists) {
        final userData = documentSnapshot.data();
        List groups = userData?['groups'] ?? [];

        if (groups.contains("${widget.groupID}_${widget.groupName}")) {
          await userDocumentReference.update({
            "groups": FieldValue.arrayRemove(["${widget.groupID}_${widget.groupName}"])
          });
          await groupDocumentReference.update({
            "members": FieldValue.arrayRemove(
                ["${currentUser!.uid}_${currentUser!.displayName}"])
          });

          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (error) {
      print("Error leaving group: $error");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteGroup() async {
    setState(() {
      isLoading = true;
    });

    try {
      final groupCollection = FirebaseFirestore.instance.collection('groups');
      await groupCollection.doc(widget.groupID).delete();
      Navigator.of(context).pop();
    } catch (error) {
      print("Error deleting group: $error");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getEmail() async {
    String getName(String res) {
      return res.substring(res.indexOf("_") + 1);
    }

    String getId(String res) {
      return res.substring(0, res.indexOf("_"));
    }

    try {
      final groupCollection = FirebaseFirestore.instance.collection('groups');
      final groupDocumentReference = groupCollection.doc(widget.groupID);
      DocumentSnapshot groupSnapshot = await groupDocumentReference.get();

      String admin = groupSnapshot.get("admin");
      adminID = getId(admin);

      final adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminID)
          .collection('client')
          .doc('details')
          .get();

      final adminData = adminSnapshot.data();
      setState(() {
        email = adminData?["email"] as String;
      });

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('client')
          .doc('details')
          .get();

      final userData = userSnapshot.data();
      setState(() {
        name = userData?["displayName"] as String? ?? "";
      });
    } catch (error) {
      print("Error getting email and admin details: $error");
    }
  }

  Future<void> kickMember(String memberID, String memberName) async {
    try {
      final groupCollection = FirebaseFirestore.instance.collection('groups');
      final groupDocumentReference = groupCollection.doc(widget.groupID);

      await groupDocumentReference.update({
        "members": FieldValue.arrayRemove(["${memberID}_${memberName}"])
      });

      final userDocumentReference = FirebaseFirestore.instance
          .collection("users")
          .doc(memberID)
          .collection('client')
          .doc('details');

      final documentSnapshot = await userDocumentReference.get();

      if (documentSnapshot.exists) {
        final userData = documentSnapshot.data();
        List groups = userData?['groups'] ?? [];

        if (groups.contains("${widget.groupID}_${widget.groupName}")) {
          await userDocumentReference.update({
            "groups": FieldValue.arrayRemove(["${widget.groupID}_${widget.groupName}"])
          });
        }
      }
    } catch (error) {
      print("Error kicking member: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = adminID == currentUser?.uid; // Changed this line
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text(
          "Group Info",
          style: TextStyle(color: Colors.white, fontSize: 20 * textScaleFactor),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(
                        "Delete Group",
                        style: TextStyle(fontSize: 18 * textScaleFactor),
                      ),
                      content: Text(
                        "Are you sure you want to delete the group?",
                        style: TextStyle(fontSize: 16 * textScaleFactor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 16 * textScaleFactor),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await deleteGroup();
                          },
                          child: Text(
                            "Delete",
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 16 * textScaleFactor),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: Icon(
                color: Colors.white,
                Icons.delete,
                size: 24 * textScaleFactor,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text(
                      "Leave",
                      style: TextStyle(fontSize: 18 * textScaleFactor),
                    ),
                    content: Text(
                      "Are you sure you want to exit the group?",
                      style: TextStyle(fontSize: 16 * textScaleFactor),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 16 * textScaleFactor),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await leave();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Group(),
                            ),
                          );
                        },
                        child: Text(
                          "Leave",
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 16 * textScaleFactor),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(
            horizontal: 20 * mediaQuery.textScaleFactor,
            vertical: 20 * mediaQuery.textScaleFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(20 * mediaQuery.textScaleFactor),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(30 * mediaQuery.textScaleFactor),
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50 * mediaQuery.textScaleFactor,
                      backgroundColor: const Color.fromARGB(255, 234, 134, 123),
                      child: Text(
                        widget.groupName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 50 * textScaleFactor),
                      ),
                    ),
                  ),
                  SizedBox(
                      height: 10 *
                          mediaQuery.textScaleFactor), // Add spacing here
                  Text(
                    widget.groupName,
                    style: TextStyle(fontSize: 20 * textScaleFactor),
                  ),
                  Text(
                    "Admin: $email",
                    style: TextStyle(fontSize: 14 * textScaleFactor),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 15 * mediaQuery.textScaleFactor,
            ),
            Text(
              "Members",
              style: TextStyle(fontSize: 20 * textScaleFactor),
            ),
            memberList(isAdmin, textScaleFactor),
          ],
        ),
      ),
    );
  }

  Widget memberList(bool isAdmin, double textScaleFactor) {
    return StreamBuilder<DocumentSnapshot>(
      stream: members,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
            child: Text("No members found."),
          );
        }

        String getName(String res) {
          return res.substring(res.indexOf("_") + 1);
        }

        String getId(String res) {
          return res.substring(0, res.indexOf("_"));
        }

        final membersList = snapshot.data!.get('members') as List<dynamic>;

        return ListView.builder(
          shrinkWrap: true,
          itemCount: membersList.length,
          itemBuilder: (context, index) {
            String member = membersList[index];
            String memberName = getName(member);
            String memberID = getId(member);

            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 5 * textScaleFactor,
                  vertical: 10 * textScaleFactor),
              leading: CircleAvatar(
                radius: 30 * textScaleFactor,
                backgroundColor: Colors.grey,
                child: Text(
                  memberName.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 15 * textScaleFactor),
                ),
              ),
              title: Text(memberName, style: TextStyle(fontSize: 16 * textScaleFactor)),
              trailing: isAdmin && memberID != currentUser!.uid
                  ? IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 24 * textScaleFactor),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(
                                "Remove Member",
                                style: TextStyle(fontSize: 18 * textScaleFactor),
                              ),
                              content: Text(
                                "Are you sure you want to remove $memberName from the group?",
                                style: TextStyle(fontSize: 16 * textScaleFactor),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 16 * textScaleFactor),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await kickMember(memberID, memberName);
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    "Remove",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 16 * textScaleFactor),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
