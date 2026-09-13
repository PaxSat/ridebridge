import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/georef_controller.dart';
import 'schermata_stato_carovana.dart';

/// Schermata principale dell'interfono live (Livello GRUPPO).
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
  final GeoRefController _geoRefController = GeoRefController();
  
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
    final l10n = AppLocalizations.of(context)!;
    final String currentUid = _uid ?? "";

    return StreamBuilder<List<PartecipanteGruppo>>(
      stream: FirebaseFirestore.instance
          .collection('gruppi')
          .doc(widget.gruppo.id)
          .collection('partecipanti')
          // online o partecipando attivi
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PartecipanteGruppo.daMappa(doc.data(), doc.id))
              .toList()),
      builder: (context, snapshot) {
        var tuttiPartecipanti = snapshot.data ?? [];
        
        // In Conversazione (PARTECIPA) vediamo solo chi è effettivamente attivo nella sessione
        var partecipantiAttivi = tuttiPartecipanti.where((p) => p.partecipando == true).toList();
        
        if (currentUid.isNotEmpty && tuttiPartecipanti.isNotEmpty) {
          try {
            final me = tuttiPartecipanti.firstWhere((p) => p.idUtente == currentUid);
            _mioStatoLocale = me;
            _sosAttivo = me.statoAudio?.emergenzaAttiva ?? false;
            _canaleSpecialeAttivo = me.statoAudio?.canaleSpecialeAttivo ?? false;
          } catch (_) {}
        }

        // Ordinamento per ruolo nella conversazione
        partecipantiAttivi.sort((a, b) => a.ruolo.index.compareTo(b.ruolo.index));

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _geoRefController.stop();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.gruppo.nome),
              centerTitle: true,
              automaticallyImplyLeading: false,
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _costruisciHeaderControlli(currentUid),
                _costruisciSezioneParlante(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.people, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(l10n.participantsLive, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ),
                _costruisciListaPartecipanti(partecipantiAttivi),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _costruisciHeaderControlli(String currentUid) {
    final l10n = AppLocalizations.of(context)!;

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
              etichetta: l10n.scopa,
              colore: _canaleSpecialeAttivo ? Colors.red : Colors.grey,
              onTap: _gestisciCanaleSpeciale,
            ),
          if (widget.mioRuoloIniziale == RuoloGruppo.scopa)
            _bottoneCircolare(
              icona: Icons.podcasts,
              etichetta: l10n.leader,
              colore: _canaleSpecialeAttivo ? Colors.red : Colors.grey,
              onTap: _gestisciCanaleSpeciale,
            ),

          _bottoneCircolare(
            icona: Icons.location_on,
            etichetta: "CAROVANA",
            colore: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchermataStatoCarovana(
                    mioRuolo: widget.mioRuoloIniziale,
                    mioUid: currentUid,
                    idGruppo: widget.gruppo.id,
                  ),
                ),
              );
            },
          ),

          _bottoneCircolare(
            icona: Icons.warning_amber_rounded,
            etichetta: l10n.sos,
            colore: _sosAttivo ? Colors.red : Colors.grey,
            onTap: _gestisciSos,
          ),

          _bottoneCircolare(
            icona: Icons.close,
            etichetta: l10n.exit,
            colore: Colors.white24,
            onTap: () async {
              await _geoRefController.stop();
              if (!mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
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

  Widget _costruisciSezioneParlante() {
    final l10n = AppLocalizations.of(context)!;

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
            _sosAttivo ? l10n.sosActive : l10n.speaking,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
              color: _sosAttivo ? Colors.red : Colors.orange
            )
          ),
          const SizedBox(height: 12),
          Text(
            _sosAttivo ? l10n.assistanceRequested : l10n.none,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _costruisciListaPartecipanti(List<PartecipanteGruppo> partecipanti) {
    final l10n = AppLocalizations.of(context)!;
    if (partecipanti.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(l10n.noParticipants),
      ));
    }
    
    return Column(
      children: partecipanti.map((p) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('utenti').doc(p.idUtente).get(),
          builder: (context, uSnapshot) {
            final dati = uSnapshot.data?.data() as Map<String, dynamic>?;
            final String nome = (dati?['nickname']?.toString().isNotEmpty ?? false)
                ? dati!['nickname'].toString()
                : (dati?['nome']?.toString() ?? l10n.loading);
            final String moto = dati?['moto']?.toString() ?? "";
            final String? fotoUrl = dati?['fotoUrl']?.toString();
            
            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
                    child: (fotoUrl == null || fotoUrl.isEmpty) ? const Icon(Icons.person) : null,
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
              subtitle: Text(moto),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.statoAudio?.canaleSpecialeAttivo ?? false)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.podcasts, color: Colors.blue, size: 20),
                    ),
                  if (p.statoAudio?.emergenzaAttiva ?? false)
                    const Icon(Icons.warning, color: Colors.red),
                ],
              ),
            );
          },
        );
      }).toList(),
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
