import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  File? _pickedImageFile;

  Future<void> pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final cameraPermissionStatus = await Permission.camera.request();
      if (cameraPermissionStatus != PermissionStatus.granted) {
        return;
      }
    } else if (source == ImageSource.gallery) {
      final galleryPermissionStatus = await Permission.photos.request();
      if (galleryPermissionStatus != PermissionStatus.granted) {
        return;
      }
    }

    final pickedImage = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      _pickedImageFile = File(pickedImage.path);
    });
    await _updateProfileImage(_pickedImageFile!);
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfileImage(File pickedImage) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (error) {
        print('Error updating profile image: $error');
      }
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Theme.of(context).primaryColor,
      title: const Text(
        'Settings',
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.person,
                            color: Theme.of(context).colorScheme.primary),
                        title: const Text('Edit Display Name'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          EditDisplayNameDialog(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.image,
                            color: Theme.of(context).colorScheme.primary),
                        title: const Text('Edit Profile Picture'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          _showPicker(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.email,
                            color: Theme.of(context).colorScheme.primary),
                        title: const Text('Edit Email'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          EditEmailDialog(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.lock,
                            color: Theme.of(context).colorScheme.primary),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          ChangePasswordDialog(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.info,
                            color: Theme.of(context).colorScheme.primary),
                        title: const Text('About'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Implement about section logic
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


Future<void> _updateDisplayName(
    BuildContext context, String displayName) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('client')
        .doc('details')
        .update({
      'displayName': displayName,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Display name updated successfully')),
    );
  }
}

Future<void> EditDisplayNameDialog(BuildContext context) {
  final _displayNameController = TextEditingController();
  bool _isLoading = false;

  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Edit Display Name',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    TextField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: 'New Display Name',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: _isLoading
                ? []
                : [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });

                        await _updateDisplayName(
                            context, _displayNameController.text);

                        setState(() {
                          _isLoading = false;
                        });

                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
          );
        },
      );
    },
  );
}

Future<void> _updateEmail(BuildContext context, String newEmail) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await user.updateEmail(newEmail);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email updated successfully')),
    );
  }
}

Future<void> _updateEmailAddress(BuildContext context, String newEmail) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('client')
        .doc('details')
        .update({
      'email': newEmail,
    });
  }
}

Future<void> EditEmailDialog(BuildContext context) {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Edit Email',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'New Email',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: _isLoading
                ? []
                : [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });

                        await _updateEmail(context, _emailController.text);
                        await _updateEmailAddress(
                            context, _emailController.text);

                        setState(() {
                          _isLoading = false;
                        });

                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
          );
        },
      );
    },
  );
}

Future<void> _changePassword(BuildContext context, String newPassword) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await user.updatePassword(newPassword);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );
  }
}

Future<void> ChangePasswordDialog(BuildContext context) {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Change Password',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      obscureText: true,
                    ),
                ],
              ),
            ),
            actions: _isLoading
                ? []
                : [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });

                        await _changePassword(
                            context, _passwordController.text);

                        setState(() {
                          _isLoading = false;
                        });

                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
          );
        },
      );
    },
  );
}
}
