import 'package:ridebridge/servizi/georef_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../servizi/debug_manager.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
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
  final GeoRefController _geoRefController = GeoRefController();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  /// Gestisce l'ingresso nella conversazione live.
  Future<void> _partecipaLive(BuildContext context, Gruppo gruppo) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      // Recuperiamo il ruolo attuale dell'utente nel gruppo
      final partecipante = await _servizioGruppi.ottieniRuoloUtente(gruppo.id, uid);
      
      if (partecipante != null && context.mounted) {
        // 1. Avvia la partecipazione (Livello PARTECIPA) - Rientro rapido senza popup
        await _geoRefController.start(
          idGruppo: gruppo.id,
          mioUid: uid,
          mioRuolo: partecipante.ruolo,
          configurazione: gruppo.configurazione,
        );

        if (!context.mounted) return;

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
          SnackBar(content: Text(AppLocalizations.of(context)!.joinLiveError(e.toString()))),
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
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: DebugManager(),
            builder: (context, _) => DebugManager().debugMode 
                ? const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Center(
                      child: Text(
                        "[MY_GRPS]",
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _servizioGruppi.mieiGruppiConRuolo(_uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(l10n.loginError(snapshot.error.toString())));
          }

          final listaDati = snapshot.data ?? [];

          if (listaDati.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noGroupsJoined,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.backToHome),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listaDati.length,
            itemBuilder: (context, index) {
              final dati = listaDati[index];
              final Gruppo gruppo = dati['gruppo'];
              final RuoloGruppo mioRuolo = dati['ruolo'];

              Widget? iconaRuolo;
              switch (mioRuolo) {
                case RuoloGruppo.leader:
                  iconaRuolo = const Text("👑", style: TextStyle(fontSize: 18));
                  break;
                case RuoloGruppo.scopa:
                  iconaRuolo = const Text("🧹", style: TextStyle(fontSize: 18));
                  break;
                default:
                  iconaRuolo = null;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: iconaRuolo,
                  ),
                  title: Text(
                    gruppo.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text("${l10n.groupCode}: ${gruppo.codiceAccesso}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mioRuolo == RuoloGruppo.leader)
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
                        child: Text(l10n.joinLive, style: const TextStyle(fontWeight: FontWeight.bold)),
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
