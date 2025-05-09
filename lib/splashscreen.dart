import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Splashscreen extends StatelessWidget {
  const Splashscreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple, Colors.deepPurpleAccent],
          ),
        ),
        child: const Center(
          child: SpinKitCubeGrid(color: Colors.white, size: 140),
        ),
      ),
    );
  }
}
