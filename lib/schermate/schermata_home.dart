import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_auth.dart';
import '../servizi/servizio_database.dart';
import 'schermata_login.dart';
import 'schermata_crea_gruppo.dart';
import 'schermata_miei_gruppi.dart';
import 'schermata_entra_gruppo.dart';
import 'schermata_profilo.dart';

/// Schermata principale dell'applicazione dopo il login.
class SchermataHome extends StatefulWidget {
  const SchermataHome({super.key});

  @override
  State<SchermataHome> createState() => _SchermataHomeState();
}

class _SchermataHomeState extends State<SchermataHome> {
  final _servizioDatabase = ServizioDatabase();
  final _servizioAuth = ServizioAuth();
  final _firebaseUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutTooltip,
            onPressed: () async {
              await _servizioAuth.esci();
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
        future: _firebaseUser != null 
            ? _servizioDatabase.leggiUtente(_firebaseUser.uid) 
            : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Errore nel caricamento del profilo"));
          }

          final utente = snapshot.data;

          // Determiniamo il nome da visualizzare (Nickname se presente, altrimenti Nome Google)
          final nomeVisualizzato = utente?.nickname?.isNotEmpty == true 
              ? utente!.nickname! 
              : (utente?.nome ?? 'Motociclista');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    backgroundImage: utente?.fotoUrl != null 
                        ? NetworkImage(utente!.fotoUrl!) 
                        : null,
                    child: utente?.fotoUrl == null 
                        ? const Icon(Icons.motorcycle, size: 60, color: Colors.orange) 
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.appTitle,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.welcomeMessage(nomeVisualizzato),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Azioni Rapide
                  _costruisciBottoneAzione(
                    context: context,
                    icona: Icons.account_circle_outlined,
                    etichetta: l10n.profile,
                    colore: Colors.blueGrey,
                    azione: () async {
                      if (utente != null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SchermataProfilo(utente: utente),
                          ),
                        );
                        // Ricarichiamo i dati al ritorno dal profilo
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _costruisciBottoneAzione(
                    context: context,
                    icona: Icons.groups_outlined,
                    etichetta: l10n.myGroups,
                    colore: Colors.green,
                    azione: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SchermataMieiGruppi()),
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  _costruisciBottoneAzione(
                    context: context,
                    icona: Icons.add_circle_outline,
                    etichetta: l10n.createGroup,
                    colore: Colors.orange,
                    azione: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SchermataCreaGruppo()),
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  _costruisciBottoneAzione(
                    context: context,
                    icona: Icons.group_add_outlined,
                    etichetta: l10n.joinGroup,
                    colore: Colors.blue,
                    azione: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SchermataEntraGruppo()),
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 40),
                  const Divider(),
                  const Text(
                    "RideBridge v1.0.0 - Step 2 Completo",
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
