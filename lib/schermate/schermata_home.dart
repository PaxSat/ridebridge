import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_auth.dart';
import '../servizi/servizio_database.dart';
import 'schermata_login.dart';
import 'schermata_crea_gruppo.dart';

/// Schermata principale dell'applicazione dopo il login.
class SchermataHome extends StatelessWidget {
  const SchermataHome({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final servizioDatabase = ServizioDatabase();
    final servizioAuth = ServizioAuth();

    return Scaffold(
      appBar: AppBar(
        title: const Text("RideBridge"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Esci',
            onPressed: () async {
              await servizioAuth.esci();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SchermataLogin()),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Utente?>(
        future: firebaseUser != null 
            ? servizioDatabase.leggiUtente(firebaseUser.uid) 
            : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Errore nel caricamento del profilo"));
          }

          final utente = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    backgroundImage: utente?.fotoUrl != null 
                        ? NetworkImage(utente!.fotoUrl!) 
                        : null,
                    child: utente?.fotoUrl == null 
                        ? const Icon(Icons.motorcycle, size: 60, color: Colors.orange) 
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "RideBridge",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Benvenuto, ${utente?.nome ?? 'Motociclista'}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Azioni Rapide
                  _costruisciBottoneAzione(
                    context: context,
                    icona: Icons.add_circle_outline,
                    etichetta: "CREA GRUPPO",
                    colore: Colors.orange,
                    azione: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SchermataCreaGruppo()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _costruisciBottoneAzione(
                    context: context,
                    icona: Icons.group_add_outlined,
                    etichetta: "ENTRA NEL GRUPPO",
                    colore: Colors.blue,
                    azione: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Funzionalità in arrivo")),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  const Divider(),
                  const Text(
                    "RideBridge v1.0.0 - Step 1 Completo",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _costruisciBottoneAzione({
    required BuildContext context,
    required IconData icona,
    required String etichetta,
    required Color colore,
    required VoidCallback azione,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: azione,
        icon: Icon(icona),
        label: Text(etichetta),
        style: ElevatedButton.styleFrom(
          backgroundColor: colore,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
