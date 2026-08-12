import 'package:firebase_auth/firebase_auth.dart';
import 'schermata_crea_gruppo.dart';
import 'package:flutter/material.dart';

class SchermataHome extends StatelessWidget {
  const SchermataHome({super.key});

  @override
  Widget build(BuildContext context) {
    final utente=FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("RideBridge")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.motorcycle, size: 100, color: Colors.orange),

            const SizedBox(height: 20),

            const Text(
              "RideBridge",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "Ciao ${utente?.displayName ?? 'Motociclista'}",
            ),

            const Text("Interfono per motociclisti"),

            const SizedBox(height: 40),

            SizedBox(
              width: 250,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (context) => SchermataCreaGruppo(),
                    ),
                  );
                },
                child: const Text("CREA GRUPPO"),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: 250,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Funzione in sviluppo")),
                  );
                },
                child: const Text("ENTRA NEL GRUPPO"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
