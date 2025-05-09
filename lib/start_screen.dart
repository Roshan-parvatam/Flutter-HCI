import 'package:collab_prog/auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  void timing(BuildContext context) {
    Timer(
      const Duration(seconds: 2),
      () {
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Auth(true)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Homepage()),
            );
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    timing(context);

    // Get screen size
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: screenWidth * 0.4,
                height: screenWidth * 0.4,
                child: Image.asset('assets/images/prew.png'),
              ),
              const SizedBox(height: 20),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'CollaborativeProgress',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
               const SpinKitCubeGrid(color: Colors.white, size: 140),
            ],
          ),
        ),
      ),
    );
  }
}
