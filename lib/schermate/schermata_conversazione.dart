import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/servizio_database.dart';
import '../servizi/formation_manager.dart';

import 'schermata_stato_carovana.dart';

import '../modelli/posizione_gps.dart';
import '../servizi/location_evaluator.dart';

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
  final LocationEvaluator _evaluator = LocationEvaluator();
  final FormationManager _formationManager = FormationManager();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  bool _canaleSpecialeAttivo = false;
  bool _sosAttivo = false;
  PartecipanteGruppo? _mioStatoLocale;
  StatoCarovana _mioStatoCarovana = StatoCarovana.inGroup;
  PosizioneGps? _posLeader;

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

  /// Apre l'app di navigazione esterna verso la posizione del Leader.
  Future<void> _navigaAlLeader() async {
    if (_posLeader == null) return;

    final lat = _posLeader!.latitudine;
    final lon = _posLeader!.longitudine;

    Uri uri;
    if (Platform.isAndroid) {
      uri = Uri.parse("google.navigation:q=$lat,$lon&mode=d");
    } else if (Platform.isIOS) {
      uri = Uri.parse("comgooglemaps://?q=$lat,$lon");
    } else {
      uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallbackUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
        var partecipanti = snapshot.data ?? [];
        
        final Map<String, StatoCarovana> statiCarovanaMembri = {};

        // Sincronizziamo lo stato locale con i dati Firestore per l'utente corrente
        PartecipanteGruppo? leader;
        PartecipanteGruppo? scopa;

        if (_uid != null && partecipanti.isNotEmpty) {
          try {
            final me = partecipanti.firstWhere((p) => p.idUtente == _uid);
            _mioStatoLocale = me;
            _sosAttivo = me.statoAudio?.emergenzaAttiva ?? false;
            _canaleSpecialeAttivo = me.statoAudio?.canaleSpecialeAttivo ?? false;

            leader = partecipanti.firstWhere((p) => p.ruolo == RuoloGruppo.leader);
            _posLeader = leader.posizioneGps;
            
            try {
              scopa = partecipanti.firstWhere((p) => p.ruolo == RuoloGruppo.scopa);
            } catch (_) {}

            // CALCOLO STATO CAROVANA PER TUTTI (per i colori dei dot)
            for (var p in partecipanti) {
              if (p.posizioneGps != null && _posLeader != null) {
                statiCarovanaMembri[p.idUtente] = _formationManager.verificaFormazione(
                  idUtente: p.idUtente,
                  idLeader: leader.idUtente,
                  idScopa: scopa?.idUtente,
                  posizioneUtente: p.posizioneGps!,
                  posizioneLeader: _posLeader!,
                  posizioneScopa: scopa?.posizioneGps,
                  config: widget.gruppo.configurazione,
                );
              } else {
                statiCarovanaMembri[p.idUtente] = StatoCarovana.inGroup;
              }
            }

            _mioStatoCarovana = statiCarovanaMembri[_uid] ?? StatoCarovana.inGroup;
          } catch (_) {}
        }

        // ORDINAMENTO PER DISTANZA DAL LEADER (Ordine Carovana)
        if (_posLeader != null) {
          final PosizioneGps posLeaderSicura = _posLeader!;
          partecipanti.sort((a, b) {
            // Il Leader è sempre il primo (distanza 0)
            if (a.ruolo == RuoloGruppo.leader) return -1;
            if (b.ruolo == RuoloGruppo.leader) return 1;
            
            final distA = a.posizioneGps != null 
                ? _evaluator.distanzaTraDuePunti(posLeaderSicura.latitudine, posLeaderSicura.longitudine, a.posizioneGps!.latitudine, a.posizioneGps!.longitudine)
                : 999999.0;
            final distB = b.posizioneGps != null 
                ? _evaluator.distanzaTraDuePunti(posLeaderSicura.latitudine, posLeaderSicura.longitudine, b.posizioneGps!.latitudine, b.posizioneGps!.longitudine)
                : 999999.0;
            return distA.compareTo(distB);
          });
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
              Expanded(child: _costruisciListaPartecipanti(partecipanti, statiCarovanaMembri)),
            ],
          ),
        );
      }
    );
  }

  Widget _costruisciHeaderControlli() {
    final l10n = AppLocalizations.of(context)!;
    final bool fuoriFormazione = _mioStatoCarovana == StatoCarovana.aheadOfLeader || _mioStatoCarovana == StatoCarovana.offRoute;

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

          if (fuoriFormazione)
            _bottoneCircolare(
              icona: Icons.navigation,
              etichetta: l10n.rejoinLeader.split(' ').last.toUpperCase(), // "LEADER"
              colore: Colors.blue,
              onTap: _navigaAlLeader,
            )
          else
            _bottoneCircolare(
              icona: Icons.location_on,
              etichetta: l10n.caravanStatus.split(' ')[1].toUpperCase(), // "CAROVANA"
              colore: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SchermataStatoCarovana(
                      mioRuolo: widget.mioRuoloIniziale,
                      mioUid: _uid ?? "",
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
            onTap: () => Navigator.pop(context),
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

  Color _ottieniColoreStato(StatoCarovana? stato) {
    switch (stato) {
      case StatoCarovana.aheadOfLeader: return Colors.orange;
      case StatoCarovana.behindSweeper: return Colors.red;
      case StatoCarovana.offRoute: return Colors.purple;
      case StatoCarovana.groupBroken: return Colors.black;
      default: return Colors.green;
    }
  }

  Widget _costruisciListaPartecipanti(List<PartecipanteGruppo> partecipanti, Map<String, StatoCarovana> stati) {
    final l10n = AppLocalizations.of(context)!;
    if (partecipanti.isEmpty) return Center(child: Text(l10n.noParticipants));
    
    return ListView.builder(
      itemCount: partecipanti.length,
      itemBuilder: (context, index) {
        final p = partecipanti[index];
        final stato = stati[p.idUtente];

        return FutureBuilder<Utente?>(
          future: _servizioDatabase.leggiUtente(p.idUtente),
          builder: (context, uSnapshot) {
            final utente = uSnapshot.data;
            final nome = utente?.nickname?.isNotEmpty == true ? utente!.nickname! : (utente?.nome ?? l10n.loading);
            
            // Calcolo distanza dal LEADER per il sottotitolo
            String subtitleText = utente?.moto ?? "";
            if (p.ruolo != RuoloGruppo.leader && _posLeader != null && p.posizioneGps != null) {
              final d = _evaluator.distanzaTraDuePunti(
                _posLeader!.latitudine, _posLeader!.longitudine,
                p.posizioneGps!.latitudine, p.posizioneGps!.longitudine,
              );
              subtitleText = "${utente?.moto ?? ''} • ${d.round()}m dal Leader".trim();
            }

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
                        color: p.online ? _ottieniColoreStato(stato) : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text("${_ottieniEmojiRuolo(p.ruolo)} $nome", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitleText),
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

  String _ottieniEmojiRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader: return "👑";
      case RuoloGruppo.scopa: return "🏍️";
      case RuoloGruppo.partecipante: return "👤";
    }
  }
}
