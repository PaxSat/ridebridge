import 'package:ridebridge/servizi/servizio_auth.dart';
import 'package:ridebridge/schermate/schermata_home.dart';

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.motorcycle,
              size: 100,
              color: Colors.orange,
            ),

            const SizedBox(height: 20),

            const Text(
              "RideBridge",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () async {

                try {

                  final risultato =
                  await ServizioAuth()
                      .accediConGoogle();

                  if (risultato != null &&
                      context.mounted) {

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const SchermataHome(),
                      ),
                    );
                  }
                }
                catch (errore) {

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        errore.toString(),
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                "ACCEDI CON GOOGLE",
              ),
            ),

          ],
        ),
      ),
    );
  }
}