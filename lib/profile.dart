import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'settings.dart';
import 'auth.dart';
import 'userpicker.dart';
import 'completed_tasks_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  String _profileImageUrl = '';
  String name = '';
  bool isOrientationLocked = false;
  String email = '';
  String accountCreationDate = '';
  String lastLogin = '';

  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    
    // Call methods to initialize data and animations
    _fetchProfileImageUrl();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..forward();

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
              name = userData['displayName'] as String? ?? '';
              email = userData['email'] as String? ?? '';
              accountCreationDate = currentUser.metadata.creationTime?.toLocal().toString() ?? 'N/A';
              lastLogin = currentUser.metadata.lastSignInTime?.toLocal().toString() ?? 'N/A';
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 27 * textScaleFactor,
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).primaryColor,
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
              title: Text(
                'Completed Tasks',
                style: TextStyle(color: Colors.white, fontSize: 17 * textScaleFactor),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CompletedTasksScreen()),
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * textScaleFactor, vertical: 30 * textScaleFactor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _profileImageUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 80 * textScaleFactor,
                            backgroundImage: NetworkImage(_profileImageUrl),
                          )
                        : CircleAvatar(
                            radius: 80 * textScaleFactor,
                            child: Icon(Icons.account_circle, size: 80 * textScaleFactor),
                          ),
                  ),
                  SizedBox(height: 20 * textScaleFactor),
                  SlideTransition(
                    position: _offsetAnimation,
                    child: _buildUserInfoCard(
                      icon: Icons.person,
                      label: "Name",
                      value: name,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  SlideTransition(
                    position: _offsetAnimation,
                    child: _buildUserInfoCard(
                      icon: Icons.email,
                      label: "Email",
                      value: email,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  SlideTransition(
                    position: _offsetAnimation,
                    child: _buildUserInfoCard(
                      icon: Icons.date_range,
                      label: "Account Created",
                      value: accountCreationDate,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                  SlideTransition(
                    position: _offsetAnimation,
                    child: _buildUserInfoCard(
                      icon: Icons.access_time,
                      label: "Last Login",
                      value: lastLogin,
                      textScaleFactor: textScaleFactor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16 * textScaleFactor,
            left: MediaQuery.of(context).size.width * 0.5 - 140 * textScaleFactor, // Center alignment
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              icon: Icon(Icons.settings, color: Colors.white),
              label: Text(
                'Go to Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required double textScaleFactor,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8 * textScaleFactor),
      padding: EdgeInsets.all(15 * textScaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 30 * textScaleFactor, color: Theme.of(context).primaryColor),
          SizedBox(width: 10 * textScaleFactor),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 17 * textScaleFactor, fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(fontSize: 17 * textScaleFactor)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
