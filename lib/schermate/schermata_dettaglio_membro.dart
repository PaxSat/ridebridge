import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/servizio_database.dart';

/// Schermata che mostra i dettagli di un singolo membro del gruppo
/// e permette al Leader di gestirne i ruoli e i permessi.
class SchermataDettaglioMembro extends StatefulWidget {
  final String idGruppo;
  final String idUtente;

  const SchermataDettaglioMembro({
    super.key,
    required this.idGruppo,
    required this.idUtente,
  });

  @override
  State<SchermataDettaglioMembro> createState() => _SchermataDettaglioMembroState();
}

class _SchermataDettaglioMembroState extends State<SchermataDettaglioMembro> {
  final ServizioGruppi _servizioGruppi = ServizioGruppi();
  final ServizioDatabase _servizioDatabase = ServizioDatabase();
  final String? _mioUid = FirebaseAuth.instance.currentUser?.uid;

  String _formattaRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader: return "👑 Leader";
      case RuoloGruppo.scopa: return "🏍️ Scopa";
      case RuoloGruppo.partecipante: return "👤 Partecipante";
    }
  }

  @override
  Widget build(BuildContext context) {
    final mioUid = _mioUid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gruppi')
          .doc(widget.idGruppo)
          .collection('partecipanti')
          .doc(widget.idUtente)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final datiPartecipante = snapshot.data!.data() as Map<String, dynamic>?;
        if (datiPartecipante == null) return const Scaffold(body: Center(child: Text("Membro non trovato")));
        
        final p = PartecipanteGruppo.daMappa(datiPartecipante, widget.idUtente);
        final bool eMeStesso = widget.idUtente == _mioUid;

        return FutureBuilder<Utente?>(
          future: _servizioDatabase.leggiUtente(widget.idUtente),
          builder: (context, utenteSnapshot) {
            final utente = utenteSnapshot.data;
            final nomeVisualizzato = utente?.nickname?.isNotEmpty == true 
                ? utente!.nickname! 
                : (utente?.nome ?? "Caricamento...");

            return Scaffold(
              appBar: AppBar(
                title: const Text("Dettaglio Membro"),
                centerTitle: true,
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header Profilo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      color: Colors.orange.withValues(alpha: 0.1),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: utente?.fotoUrl != null ? NetworkImage(utente!.fotoUrl!) : null,
                            child: utente?.fotoUrl == null ? const Icon(Icons.person, size: 60) : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            nomeVisualizzato,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          if (utente?.moto?.isNotEmpty == true)
                            Text(
                              utente!.moto!,
                              style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _formattaRuolo(p.ruolo),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    // Stato Audio e Presenza
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _costruisciRigaStato(
                            icona: Icons.circle,
                            coloreIcona: p.online ? Colors.green : Colors.grey,
                            testo: p.online ? "Online" : "Offline",
                          ),
                          const Divider(),
                          _costruisciRigaStato(
                            icona: p.microfonoConsentito ? Icons.mic : Icons.mic_off,
                            coloreIcona: p.microfonoConsentito ? Colors.green : Colors.red,
                            testo: "Microfono: ${p.microfonoConsentito ? 'Abilitato' : 'Disabilitato'}",
                          ),
                          const Divider(),
                          _costruisciRigaStato(
                            icona: p.audioConsentito ? Icons.volume_up : Icons.volume_off,
                            coloreIcona: p.audioConsentito ? Colors.green : Colors.red,
                            testo: "Audio: ${p.audioConsentito ? 'Abilitato' : 'Disabilitato'}",
                          ),
                          if (p.statoAudio?.emergenzaAttiva == true) ...[
                            const Divider(),
                            _costruisciRigaStato(
                              icona: Icons.warning,
                              coloreIcona: Colors.red,
                              testo: "EMERGENZA ATTIVA",
                              stileTesto: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Azioni Amministratore (solo se il Leader guarda un altro)
                    FutureBuilder<PartecipanteGruppo?>(
                      future: mioUid != null ? _servizioGruppi.ottieniRuoloUtente(widget.idGruppo, mioUid) : Future.value(null),
                      builder: (context, mioRuoloSnapshot) {
                        final mioRuolo = mioRuoloSnapshot.data;
                        final bool ioSonoLeader = mioRuolo?.ruolo == RuoloGruppo.leader;

                        if (ioSonoLeader && !eMeStesso && mioUid != null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("AZIONI LEADER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 16),
                                _bottoneAzione(
                                  etichetta: p.ruolo == RuoloGruppo.scopa ? "Rimuovi Scopa" : "Nomina Scopa",
                                  icona: Icons.motorcycle,
                                  colore: Colors.orange,
                                  onPressed: () => _servizioGruppi.assegnaScopa(widget.idGruppo, mioUid, widget.idUtente),
                                ),
                                const SizedBox(height: 12),
                                _bottoneAzione(
                                  etichetta: p.microfonoConsentito ? "Disabilita Microfono" : "Abilita Microfono",
                                  icona: p.microfonoConsentito ? Icons.mic_off : Icons.mic,
                                  colore: Colors.blue,
                                  onPressed: () => p.microfonoConsentito 
                                      ? _servizioGruppi.disabilitaMicrofonoPartecipante(widget.idGruppo, mioUid, widget.idUtente)
                                      : _servizioGruppi.abilitaMicrofonoPartecipante(widget.idGruppo, mioUid, widget.idUtente),
                                ),
                                const SizedBox(height: 12),
                                _bottoneAzione(
                                  etichetta: p.audioConsentito ? "Disabilita Audio" : "Abilita Audio",
                                  icona: p.audioConsentito ? Icons.volume_off : Icons.volume_up,
                                  colore: Colors.blueGrey,
                                  onPressed: () => p.audioConsentito 
                                      ? _servizioGruppi.disabilitaAudioPartecipante(widget.idGruppo, mioUid, widget.idUtente)
                                      : _servizioGruppi.abilitaAudioPartecipante(widget.idGruppo, mioUid, widget.idUtente),
                                ),
                                const SizedBox(height: 12),
                                _bottoneAzione(
                                  etichetta: "Promuovi a Leader",
                                  icona: Icons.star,
                                  colore: Colors.red,
                                  onPressed: () => _confermaCambioLeader(context, nomeVisualizzato, mioUid),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _costruisciRigaStato({
    required IconData icona,
    required Color coloreIcona,
    required String testo,
    TextStyle? stileTesto,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icona, color: coloreIcona, size: 20),
          const SizedBox(width: 16),
          Text(testo, style: stileTesto ?? const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _bottoneAzione({
    required String etichetta,
    required IconData icona,
    required Color colore,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icona),
        label: Text(etichetta),
        style: ElevatedButton.styleFrom(
          backgroundColor: colore,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _confermaCambioLeader(BuildContext context, String nome, String mioUid) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Trasferisci Leadership"),
        content: Text("Vuoi davvero nominare $nome nuovo Leader? Perderai i poteri di comando."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULLA")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("CONFERMA"),
          ),
        ],
      ),
    );

    if (conferma == true) {
      try {
        await _servizioGruppi.cambiaLeader(widget.idGruppo, mioUid, widget.idUtente);
        if (!context.mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
