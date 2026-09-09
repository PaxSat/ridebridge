import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/servizio_database.dart';

/// Schermata principale dell'interfono live.
class SchermataConversazione extends StatefulWidget {
  final Gruppo gruppo;
  final RuoloGruppo mioRuoloIniziale;

  const SchermataConversazione({
    super.key,
    required this.gruppo,
    required this.mioRuoloIniziale,
  });

  @override
  State<SchermataConversazione> createState() => _SchermataConversazioneState();
}

class _SchermataConversazioneState extends State<SchermataConversazione> {
  final ServizioGruppi _servizioGruppi = ServizioGruppi();
  final ServizioDatabase _servizioDatabase = ServizioDatabase();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  bool _canaleSpecialeAttivo = false;
  bool _sosAttivo = false;
  PartecipanteGruppo? _mioStatoLocale;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _servizioGruppi.aggiornaPresenza(widget.gruppo.id, _uid, true);
    }
  }

  @override
  void dispose() {
    if (_uid != null) {
      _servizioGruppi.aggiornaPresenza(widget.gruppo.id, _uid, false);
    }
    super.dispose();
  }

  /// Gestisce la pressione del pulsante Canale Speciale (Leader/Scopa).
  void _gestisciCanaleSpeciale() async {
    if (_uid == null || _mioStatoLocale?.statoAudio == null) return;

    final nuovoStato = !_canaleSpecialeAttivo;
    setState(() => _canaleSpecialeAttivo = nuovoStato);

    final statoAudioAggiornato = _mioStatoLocale!.statoAudio!.copiaCon(
      canaleSpecialeAttivo: nuovoStato,
      ultimoAggiornamento: DateTime.now(),
    );

    await _servizioGruppi.aggiornaStatoAudio(widget.gruppo.id, _uid, statoAudioAggiornato);
  }

  /// Gestisce la pressione del pulsante SOS.
  void _gestisciSos() async {
    if (_uid == null) return;
    
    final nuovoStato = !_sosAttivo;
    setState(() => _sosAttivo = nuovoStato);
    
    if (nuovoStato) {
      await _servizioGruppi.attivaEmergenza(widget.gruppo.id, _uid);
    } else {
      await _servizioGruppi.disattivaEmergenza(widget.gruppo.id, _uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PartecipanteGruppo>>(
      stream: FirebaseFirestore.instance
          .collection('gruppi')
          .doc(widget.gruppo.id)
          .collection('partecipanti')
          .where('online', isEqualTo: true) // Filtriamo solo gli utenti online
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PartecipanteGruppo.daMappa(doc.data(), doc.id))
              .toList()),
      builder: (context, snapshot) {
        final partecipanti = snapshot.data ?? [];
        
        // Sincronizziamo lo stato locale con i dati Firestore per l'utente corrente
        if (_uid != null && partecipanti.isNotEmpty) {
          try {
            final me = partecipanti.firstWhere((p) => p.idUtente == _uid);
            _mioStatoLocale = me;
            _sosAttivo = me.statoAudio?.emergenzaAttiva ?? false;
            _canaleSpecialeAttivo = me.statoAudio?.canaleSpecialeAttivo ?? false;
          } catch (_) {}
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.gruppo.nome),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              _costruisciHeaderControlli(),
              _costruisciSezioneParlante(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("PARTECIPANTI LIVE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(child: _costruisciListaPartecipanti(partecipanti)),
            ],
          ),
        );
      }
    );
  }

  Widget _costruisciHeaderControlli() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.mioRuoloIniziale == RuoloGruppo.leader)
            _bottoneCircolare(
              icona: Icons.podcasts,
              etichetta: "SCOPA",
              colore: _canaleSpecialeAttivo ? Colors.red : Colors.grey,
              onTap: _gestisciCanaleSpeciale,
            ),
          if (widget.mioRuoloIniziale == RuoloGruppo.scopa)
            _bottoneCircolare(
              icona: Icons.podcasts,
              etichetta: "LEADER",
              colore: _canaleSpecialeAttivo ? Colors.red : Colors.grey,
              onTap: _gestisciCanaleSpeciale,
            ),

          _bottoneCircolare(
            icona: Icons.warning_amber_rounded,
            etichetta: "SOS",
            colore: _sosAttivo ? Colors.red : Colors.grey,
            onTap: _gestisciSos,
          ),

          _bottoneCircolare(
            icona: Icons.close,
            etichetta: "ESCI",
            colore: Colors.white24,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _costruisciSezioneParlante() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _sosAttivo ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _sosAttivo ? Colors.red : Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            _sosAttivo ? "🚨 SOS ATTIVO" : "🎤 STA PARLANDO",
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
              color: _sosAttivo ? Colors.red : Colors.orange
            )
          ),
          const SizedBox(height: 12),
          Text(
            _sosAttivo ? "RICHIESTA ASSISTENZA" : "Nessuno",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _costruisciListaPartecipanti(List<PartecipanteGruppo> partecipanti) {
    if (partecipanti.isEmpty) return const Center(child: Text("Nessun partecipante"));
    
    return ListView.builder(
      itemCount: partecipanti.length,
      itemBuilder: (context, index) {
        final p = partecipanti[index];
        return FutureBuilder<Utente?>(
          future: _servizioDatabase.leggiUtente(p.idUtente),
          builder: (context, uSnapshot) {
            final utente = uSnapshot.data;
            final nome = utente?.nickname?.isNotEmpty == true ? utente!.nickname! : (utente?.nome ?? "...");

            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: utente?.fotoUrl != null ? NetworkImage(utente!.fotoUrl!) : null,
                    child: utente?.fotoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: p.online ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text("${_ottieniEmojiRuolo(p.ruolo)} $nome", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(utente?.moto ?? ""),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.statoAudio?.canaleSpecialeAttivo == true)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.podcasts, color: Colors.blue, size: 20),
                    ),
                  if (p.statoAudio?.emergenzaAttiva == true)
                    const Icon(Icons.warning, color: Colors.red),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _bottoneCircolare({
    required IconData icona,
    required String etichetta,
    required Color colore,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
            child: Icon(icona, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(etichetta, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _ottieniEmojiRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader: return "👑";
      case RuoloGruppo.scopa: return "🏍️";
      case RuoloGruppo.partecipante: return "👤";
    }
  }
}
