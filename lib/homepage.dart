import 'package:collab_prog/auth.dart';
import 'package:collab_prog/calender.dart';
import 'package:collab_prog/create_task.dart';
import 'package:collab_prog/groups.dart';
import 'package:collab_prog/homewidgets.dart';
import 'package:collab_prog/profile.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() {
    return _HomepageState();
  }
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 2;
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchProfileImageUrl();
  }

  static const List<Widget> _widgetOptions = [
    CreateTaskScreen(),
    Group(),
    HomeWidgets(),
    Calender(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
          if (imageUrl != null && imageUrl.isNotEmpty) {
            setState(() {
              _profileImageUrl = imageUrl;
            });
          } else {
            setState(() {
              _profileImageUrl = '';
            });
          }
        } else {
          print('User data is null');
        }
      } else {
      }
    } else {
      print('Current user is null');
    }
  } catch (error) {
    print('Error fetching profile data: $error');

  }
}



  @override
  Widget build(BuildContext context) {
    _fetchProfileImageUrl();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor
        ),
        child: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).primaryColor,
        items: [
          const BottomNavigationBarItem(
            icon: SizedBox(
              height: 24,
              width: 24,
              child: Icon(Icons.add),
            ),
            label: 'Create',
          ),
          const BottomNavigationBarItem(
            icon: SizedBox(
              height: 24,
              width: 24,
              child: Icon(Icons.group),
            ),
            label: 'Group',
          ),
          const BottomNavigationBarItem(
            icon: SizedBox(
              height: 24,
              width: 24,
              child: Icon(Icons.home),
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: SizedBox(
              height: 24,
              width: 24,
              child: Icon(Icons.calendar_view_day_rounded),
            ),
            label: 'Calender',
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              height: 24,
              width: 24,
              child: _profileImageUrl.isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(_profileImageUrl),
                    )
                  : const SizedBox(
                      height: 24,
                      width: 24,
                      child: Icon(Icons.account_circle),
                    ),
            ),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}
