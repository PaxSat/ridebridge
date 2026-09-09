import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../modelli/gruppo.dart';
import '../servizi/servizio_gruppi.dart';
import 'schermata_dettaglio_gruppo.dart';
import 'schermata_conversazione.dart';
import 'schermata_configurazione_gruppo.dart';

/// Schermata che mostra l'elenco dei gruppi a cui l'utente appartiene.
class SchermataMieiGruppi extends StatefulWidget {
  const SchermataMieiGruppi({super.key});

  @override
  State<SchermataMieiGruppi> createState() => _SchermataMieiGruppiState();
}

class _SchermataMieiGruppiState extends State<SchermataMieiGruppi> {
  final ServizioGruppi _servizioGruppi = ServizioGruppi();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  /// Gestisce l'ingresso nella conversazione live.
  Future<void> _partecipaLive(BuildContext context, Gruppo gruppo) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      // Recuperiamo il ruolo attuale dell'utente nel gruppo
      final partecipante = await _servizioGruppi.ottieniRuoloUtente(gruppo.id, uid);
      
      if (partecipante != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SchermataConversazione(
              gruppo: gruppo,
              mioRuoloIniziale: partecipante.ruolo,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'accesso alla live: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_uid == null) {
      return Scaffold(body: Center(child: Text(l10n.loginError("Utente non autenticato"))));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myGroups),
      ),
      body: FutureBuilder<List<Gruppo>>(
        future: _servizioGruppi.mieiGruppi(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(l10n.loginError(snapshot.error.toString())));
          }

          final gruppi = snapshot.data ?? [];

          if (gruppi.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.myGroups, // Or a specific empty message string
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.logoutTooltip), // Or a specific "Back" string
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: gruppi.length,
            itemBuilder: (context, index) {
              final gruppo = gruppi[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.motorcycle, color: Colors.white),
                  ),
                  title: Text(
                    gruppo.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text("Codice: ${gruppo.codiceAccesso}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (gruppo.idCreatore == _uid)
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.blueGrey),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SchermataConfigurazioneGruppo(gruppo: gruppo),
                              ),
                            );
                            setState(() {});
                          },
                        ),
                      ElevatedButton(
                        onPressed: () => _partecipaLive(context, gruppo),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text("PARTECIPA", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SchermataDettaglioGruppo(gruppo: gruppo),
                      ),
                    );
                    // Ricarica la lista al ritorno
                    setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
