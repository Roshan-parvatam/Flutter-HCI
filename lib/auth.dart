import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collab_prog/homepage.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collab_prog/user_picker_image.dart';
import 'package:google_sign_in/google_sign_in.dart';

final _firebase = FirebaseAuth.instance;
String? userEmail;

class Auth extends StatefulWidget {
  Auth(this._islogin, {super.key});
  bool _islogin;

  @override
  State<Auth> createState() {
    return _AuthState();
  }
}

class _AuthState extends State<Auth> {
  File? selectedImage;
  String? imageURL = '';
  var enteredEmail = '';
  var enteredPassword = '';
  final _form = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleLoginSignup() {
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebase.signInWithCredential(credential);
      final User? user = userCredential.user;

      userEmail = user?.email;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const Homepage(),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${error.toString()}'),
        ),
      );
    }
  }

  void submit() async {
    final isValid = _form.currentState!.validate();
    if (isValid) {
      _form.currentState!.save();
    }

    try {
      if (widget._islogin) {
        final userCredentials = await _firebase.signInWithEmailAndPassword(
          email: enteredEmail,
          password: enteredPassword,
        );
        userEmail = enteredEmail;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Homepage(),
          ),
        );
      } else {
        final userCredentials = await _firebase.createUserWithEmailAndPassword(
          email: enteredEmail,
          password: enteredPassword,
        );
        final User? user = userCredentials.user;
        setState(() {
          widget._islogin = true;
        });

        if (selectedImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('user_images')
              .child('${userCredentials.user!.uid}.jpg');
          await storageRef.putFile(selectedImage!);
          final imageURL = await storageRef.getDownloadURL();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('client')
              .doc('details')
              .set({
            'displayName': _displayNameController.text,
            'email': enteredEmail,
            'imageURL': imageURL,
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('client')
              .doc('details')
              .set({
            'displayName': _displayNameController.text,
            'email': enteredEmail,
          });
        }
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        // Handle specific error if needed
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Authentication failed.'),
        ),
      );
    }
  }

  void forgotPasswordDialog() async {
    final forgotPasswordEmailController = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextFormField(
            controller: forgotPasswordEmailController,
            decoration: const InputDecoration(
              labelText: 'Enter your email',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () async {
                final email = forgotPasswordEmailController.text.trim();
                UserCredential? create;
                try {
                  create = await _firebase.createUserWithEmailAndPassword(
                      email: email, password: 'abcdefg');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid mail!'),
                    ),
                  );
                  await create.user!.delete();
                  Navigator.of(context).pop();
                } on FirebaseAuthException catch (error) {
                  if (error.code == 'email-already-in-use') {
                    await _firebase.sendPasswordResetEmail(email: email);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent!'),
                      ),
                    );
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid mail!'),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: screenHeight * 0.1),
                        Center(
                          child: Text(
                            'Welcome to CollaborativeProgress',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24 * textScaleFactor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Center(
                          child: Text(
                            'Assign, Work, Accomplish',
                            style: TextStyle(
                              fontSize: 18 * textScaleFactor,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Form(
                            key: _form,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!widget._islogin)
                                  UserPickerImage(
                                    (pickedImage) {
                                      selectedImage = pickedImage;
                                    },
                                  ),
                                TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    labelStyle: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16 * textScaleFactor,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16 * textScaleFactor,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  controller: _emailController,
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty ||
                                        !value.contains('@')) {
                                      return 'Please enter a valid email address.';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    enteredEmail = value!;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16 * textScaleFactor,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16 * textScaleFactor,
                                  ),
                                  obscureText: true,
                                  controller: _passwordController,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().length < 6) {
                                      return 'Password must be at least 6 characters long.';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    enteredPassword = value!;
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (!widget._islogin)
                                  TextFormField(
                                    enabled: !widget._islogin,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      labelStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16 * textScaleFactor,
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16 * textScaleFactor,
                                    ),
                                    obscureText: true,
                                    controller: _confirmPasswordController,
                                    validator: (value) {
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match.';
                                      }
                                      return null;
                                    },
                                  ),
                                const SizedBox(height: 12),
                                if (!widget._islogin)
                                  TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Display Name',
                                      labelStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16 * textScaleFactor,
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16 * textScaleFactor,
                                    ),
                                    controller: _displayNameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autocorrect: true,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a display name.';
                                      }
                                      return null;
                                    },
                                  ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 24),
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    widget._islogin ? 'Login' : 'Signup',
                                    style: TextStyle(
                                      fontSize: 18 * textScaleFactor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (widget._islogin)
                                  TextButton(
                                    onPressed: forgotPasswordDialog,
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget._islogin
                                          ? 'Don\'t have an account?'
                                          : 'Already have an account?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16 * textScaleFactor,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          widget._islogin = !widget._islogin;
                                          _toggleLoginSignup();
                                        });
                                      },
                                      child: Text(
                                        widget._islogin ? 'Signup' : 'Login',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 16 * textScaleFactor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Or',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16 * textScaleFactor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _signInWithGoogle,
                                  style: ElevatedButton.styleFrom(
                                  
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/google.png',
                                        height: 24,
                                        width: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Sign in with Google',
                                        style: TextStyle(
                                          fontSize: 16 * textScaleFactor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
