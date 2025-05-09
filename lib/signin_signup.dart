import 'package:flutter/material.dart';
import 'package:collab_prog/auth.dart';

class SigninSignup extends StatelessWidget {
  const SigninSignup({super.key});

  void nextpage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Auth(true)),
    );
  }

  void nextpagenew(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Auth(false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:  BoxDecoration(
          color: Theme.of(context).primaryColor,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to CollaborativeProgress',
                style: TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Assign, Work, Accomplish',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 200),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  nextpage(context);
                },
                child: Text(
                  'Sign In',
                  style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  nextpagenew(context);
                },
                child: Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
