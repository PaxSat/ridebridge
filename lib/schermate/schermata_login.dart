import 'package:flutter/material.dart';

class SchermataLogin extends StatelessWidget {

  const SchermataLogin({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("RideBridge"),
      ),

      body: Center(
        child: ElevatedButton(
          onPressed: () {

          },
          child: const Text(
            "ACCEDI CON GOOGLE",
          ),
        ),
      ),
    );
  }
}