import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Search extends StatefulWidget {
  const Search({super.key});
  @override
  State<Search> createState() {
    return _SearchState();
  }
}

class _SearchState extends State<Search> {
  TextEditingController searchController = TextEditingController();
  bool isLoading = false;
  String userName = "";
  final User? user = FirebaseAuth.instance.currentUser;
  String? uid;
  bool isJoined=false;

  @override
  void initState() {
    getuserName();
    super.initState();
  }

  Future<void> getuserName() async {
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
        setState(() {
          userName = userData?["displayName"] as String;
          uid = user!.uid;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        title: const Text(
          "Search",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 27),
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
        child: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Search groups....",
                          hintStyle:
                              TextStyle(color: Colors.white, fontSize: 16)),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {});
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: groupList()),
          ],
        ),
      ),
    );
  }

 Stream<QuerySnapshot> searchByName(String groupName) {
  if (groupName.isEmpty) {
    return FirebaseFirestore.instance.collection('groups').snapshots();
  } else {
  
    String lowerBound = groupName;
    String upperBound = groupName + '\uf8ff'; 

    return FirebaseFirestore.instance
        .collection('groups')
        .where("groupName", isGreaterThanOrEqualTo: lowerBound)
        .where("groupName", isLessThan: upperBound)
        .snapshots();
  }
}

  Widget groupList() {
    return StreamBuilder<QuerySnapshot>(
      stream: searchByName(searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor),
          );
        } else if (snapshot.hasError) {
          return Center(child: Text("An error occurred: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No groups found"));
        } else {
          return ListView.builder(
            shrinkWrap: true,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final group = snapshot.data!.docs[index];
              return GroupTile(
                userName,
                group['groupId'],
                group['groupName'],
                group['admin'],
              );
            },
          );
        }
      },
    );
  }

  String getName(String r) {
    return r.substring(r.indexOf("_") + 1);
  }

  Future<bool> isUserJoined(
      String groupName, String groupId, String userName) async {
    final userDocumentReference = FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection('client')
        .doc('details');
    DocumentSnapshot documentSnapshot = await userDocumentReference.get();

    if (documentSnapshot.exists) {
      final userData = documentSnapshot.data() as Map<String, dynamic>?;

      List<dynamic> groups = userData?['groups'] ?? [];

      return groups.contains("${groupId}_$groupName");
    } else {
      return false;
    }
  }

  Future<void> toggleGroupJoin(
      String groupId, String userName, String groupName) async {
    try {
      final userDocumentReference = FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .collection('client')
          .doc('details');
      final groupDocumentReference = FirebaseFirestore.instance.collection('groups').doc(groupId);

      final documentSnapshot = await userDocumentReference.get();

      if (documentSnapshot.exists) {
        final userData = documentSnapshot.data();
        List groups = userData?['groups'] ?? [];

        if (groups.contains("${groupId}_$groupName")) {
          // Leave group logic
          await userDocumentReference.update({
            "groups": FieldValue.arrayRemove(["${groupId}_$groupName"])
          });
          await groupDocumentReference.update({
            "members": FieldValue.arrayRemove(["${uid}_$userName"])
          });
          showSnackbar(context, Colors.red, "Left the group $groupName");
        } else {
          // Join group logic
          await groupDocumentReference.update({
            "members": FieldValue.arrayUnion(["${uid}_$userName"]),
          });
          await userDocumentReference.update({
            "groups": FieldValue.arrayUnion(["${groupId}_$groupName"]),
          });
          showSnackbar(context, Colors.green, "Successfully joined the group");
        }

        // Fetch the latest join status after toggling.
        final updatedJoinedStatus = await isUserJoined(groupName, groupId, userName);
        setState(() {
          isJoined = updatedJoinedStatus;
        });
      } else {
        // Handle the case where the document does not exist
        print("User document does not exist");
      }
    } catch (e) {
      // Handle errors and display them if necessary
      print("Error toggling group join status: $e");
    }
  }

  void showSnackbar(BuildContext context, Color color, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: "OK",
          onPressed: () {},
          textColor: Colors.white,
        ),
      ),
    );
  }

  Widget GroupTile(
      String userName, String groupId, String groupName, String admin) {
    return FutureBuilder(
      future: isUserJoined(groupName, groupId, userName),
      builder: (context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Show loading state
        }
        if (snapshot.hasData) {
          bool isJoined = snapshot.data!;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                groupName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(groupName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text("Admin: ${getName(admin)}"),
            trailing: InkWell(
              onTap: () async {
                await toggleGroupJoin(groupId, userName, groupName);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isJoined ? Colors.black : Theme.of(context).primaryColor,
                  border: isJoined
                      ? Border.all(color: Colors.white, width: 1)
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  isJoined ? "Joined" : "Join Now",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        } else {
          return const Text("Error loading group data"); // Error state
        }
      },
    );
  }
}
