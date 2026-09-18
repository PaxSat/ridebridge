import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/georef_controller.dart';
import '../servizi/debug_manager.dart';
import '../modelli/route_point.dart';
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
    
    // Assicuriamoci che l'engine sia attivo se siamo in questa pagina
    if (!_geoRefController.isAttivo && _uid != null) {
      _geoRefController.start(
        idGruppo: widget.gruppo.id,
        mioUid: _uid,
        mioRuolo: widget.mioRuoloIniziale,
        configurazione: widget.gruppo.configurazione,
      );
    }

    // Attiva modalità Immersiva (Full Screen) per la guida
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Ripristina le barre di sistema all'uscita
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
    final String currentUid = _uid ?? "";
    final orientation = MediaQuery.of(context).orientation;
    final bool isLandscape = orientation == Orientation.landscape;

    return ListenableBuilder(
      listenable: _geoRefController,
      builder: (context, _) {
        final partecipantiAttivi = _geoRefController.riderPartecipanti;
        
        if (currentUid.isNotEmpty && partecipantiAttivi.isNotEmpty) {
          try {
            final me = partecipantiAttivi.firstWhereOrNull((p) => p.idUtente == currentUid);
            if (me != null) {
              _mioStatoLocale = me;
              _sosAttivo = me.statoAudio?.emergenzaAttiva ?? false;
              _canaleSpecialeAttivo = me.statoAudio?.canaleSpecialeAttivo ?? false;
            }
          } catch (_) {}
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _geoRefController.stop();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 40, // Ridotta per recuperare spazio
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.gruppo.nome.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Spacer(),
                  if (DebugManager().debugMode)
                    const Text("[CONV_LIVE]", style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            body: SafeArea(
              child: isLandscape 
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SINISTRA: Dashboard e Istruzioni
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            _costruisciSezioneParlante(isLandscape: true),
                            const SizedBox(height: 16),
                            _costruisciListaMembriHeader(currentUid),
                            _costruisciListaPartecipanti(partecipantiAttivi, currentUid),
                          ],
                        ),
                      ),
                      // DESTRA: Pulsantiera Operativa in Colonna Singola
                      Container(
                        width: 90, 
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          border: const Border(left: BorderSide(color: Colors.white10)),
                        ),
                        child: _costruisciGrigliaControlli(currentUid, isLandscape: true),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _costruisciHeaderControlli(currentUid),
                      _costruisciSezioneParlante(isLandscape: false),
                      _costruisciListaMembriHeader(currentUid),
                      _costruisciListaPartecipanti(partecipantiAttivi, currentUid),
                    ],
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _costruisciListaMembriHeader(String currentUid) {
    final l10n = AppLocalizations.of(context)!;
    final bool isBoss = widget.mioRuoloIniziale == RuoloGruppo.leader || widget.mioRuoloIniziale == RuoloGruppo.scopa;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(l10n.participantsLive.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const Spacer(),
              if (isBoss) ...[
                _tagComandoRapido("MUTA TUTTI", Icons.mic_off, Colors.red),
                const SizedBox(width: 8),
                _tagComandoRapido("ISOLA TUTTI", Icons.volume_off, Colors.blueGrey),
              ],
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _tagComandoRapido(String etichetta, IconData icona, Color colore) {
    return GestureDetector(
      onTap: () => _mostraInSviluppo(etichetta),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: colore.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icona, size: 10, color: colore),
            const SizedBox(width: 4),
            Text(etichetta, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: colore)),
          ],
        ),
      ),
    );
  }

  void _mostraInSviluppo(String funzione) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Funzione $funzione in fase di sviluppo tecnico..."),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _costruisciHeaderControlli(String currentUid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
      ),
      child: _costruisciGrigliaControlli(currentUid, isLandscape: false),
    );
  }

  Widget _costruisciGrigliaControlli(String currentUid, {required bool isLandscape}) {
    final l10n = AppLocalizations.of(context)!;
    
    final buttons = [
      if (widget.mioRuoloIniziale == RuoloGruppo.leader)
        _bottoneCircolare(
          icona: Icons.cleaning_services,
          etichetta: l10n.scopa,
          colore: _canaleSpecialeAttivo ? Colors.red : Colors.grey,
          onTap: _gestisciCanaleSpeciale,
          isLandscape: isLandscape,
        ),
      if (widget.mioRuoloIniziale == RuoloGruppo.scopa)
        _bottoneCircolare(
          icona: Icons.podcasts,
          etichetta: l10n.leader,
          colore: _canaleSpecialeAttivo ? Colors.red : Colors.grey,
          onTap: _gestisciCanaleSpeciale,
          isLandscape: isLandscape,
        ),

      if (widget.mioRuoloIniziale == RuoloGruppo.leader)
        ListenableBuilder(
          listenable: _geoRefController,
          builder: (context, _) => _bottoneCircolare(
            icona: Icons.visibility_off,
            etichetta: "GHOST",
            colore: DebugManager().ghostSnake ? Colors.deepPurple : Colors.white24,
            onTap: () {
              _geoRefController.impostaGhostSnake(!DebugManager().ghostSnake);
            },
            isLandscape: isLandscape,
          ),
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
        isLandscape: isLandscape,
      ),

      _bottoneCircolare(
        icona: Icons.warning_amber_rounded,
        etichetta: l10n.sos,
        colore: _sosAttivo ? Colors.red : Colors.grey,
        onTap: _gestisciSos,
        isLandscape: isLandscape,
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
        isLandscape: isLandscape,
      ),
    ];

    if (isLandscape) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons,
    );
  }

  Widget _bottoneCircolare({
    required IconData icona,
    required String etichetta,
    required Color colore,
    required VoidCallback onTap,
    required bool isLandscape,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isLandscape ? 4.0 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isLandscape ? 10 : 15),
              decoration: BoxDecoration(
                color: colore, 
                shape: BoxShape.circle,
                boxShadow: isLandscape ? [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))] : null,
              ),
              child: Icon(icona, color: Colors.white, size: isLandscape ? 22 : 28),
            ),
            const SizedBox(height: 4),
            Text(
              etichetta.toUpperCase(), 
              style: TextStyle(
                color: Colors.white, 
                fontSize: isLandscape ? 9 : 12, 
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _costruisciSezioneParlante({required bool isLandscape}) {
    final l10n = AppLocalizations.of(context)!;
    final String currentUid = _uid ?? "";

    return ListenableBuilder(
      listenable: _geoRefController,
      builder: (context, _) {
        final partecipantiAttivi = _geoRefController.riderPartecipanti;
        final nPartecipanti = partecipantiAttivi.length;

        final mioProgresso = _geoRefController.progressi[currentUid];
        
        // Calcolo posizione in carovana (ordinata per progresso decrescente)
        final partecipantiOrdinati = partecipantiAttivi.toList();
        partecipantiOrdinati.sort((a, b) {
          final progA = _geoRefController.progressi[a.idUtente]?.routeProgress ?? 0.0;
          final progB = _geoRefController.progressi[b.idUtente]?.routeProgress ?? 0.0;
          return progB.compareTo(progA);
        });
        final indiceInCarovana = partecipantiOrdinati.indexWhere((p) => p.idUtente == currentUid);
        final miaPosizione = indiceInCarovana != -1 ? (indiceInCarovana + 1) : 0;

        // Identificazione Leader e Coda per distanze topologiche
        double leaderProg = 0.0;
        double tailProg = 0.0;
        
        for (var p in _geoRefController.snapshotRidersCompleti.values) {
          if (p.ruolo == RuoloGruppo.leader) {
            leaderProg = _geoRefController.progressi[p.idUtente]?.routeProgress ?? 0.0;
          }
        }
        
        if (_geoRefController.tailState != null) {
          final traccia = _geoRefController.tracciaAttiva;
          final tailPoint = traccia.firstWhereOrNull((pt) => pt.sequenceId == _geoRefController.tailState!.tailIndex);
          tailProg = tailPoint?.distanzaProgressiva ?? 0.0;
        }

        final tracciaSnake = _geoRefController.tracciaAttiva;
        final nPunti = tracciaSnake.length;
        final nSvolte = tracciaSnake.where((p) => p.triggerReason == PointTriggerReason.turn).length;
        final snakeLen = tracciaSnake.isNotEmpty ? tracciaSnake.last.distanzaProgressiva : 0.0;

        final distLeader = (leaderProg - (mioProgresso?.routeProgress ?? 0.0)).abs();
        final distCoda = ((mioProgresso?.routeProgress ?? 0.0) - tailProg).abs();
        
        final istruzione = _geoRefController.messaggiNavigazione[currentUid];

        // Angolo di sterzata relativo
        final posGps = _geoRefController.ultimePosizioni[currentUid];
        final currentBearing = posGps?.direzione ?? 0.0;
        
        // Calcoliamo l'angolo relativo rispetto all'ultimo punto validato (o ultimo punto traccia se Leader)
        double relativeAngle = 0.0;
        final refPoint = tracciaSnake.firstWhereOrNull((p) => p.sequenceId == mioProgresso?.lastValidatedIndex) 
                      ?? tracciaSnake.lastOrNull;
        
        if (refPoint != null) {
          relativeAngle = currentBearing - refPoint.bearing;
          while (relativeAngle < -180) {
          relativeAngle += 360;
        }
        while (relativeAngle > 180) {
          relativeAngle -= 360;
        }
        }

        final bool exceedsThreshold = relativeAngle.abs() >= widget.gruppo.configurazione.turnThresholdAngle;
        final bool eLeader = widget.mioRuoloIniziale == RuoloGruppo.leader;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : 12, horizontal: 16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _sosAttivo ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _sosAttivo ? Colors.red : Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // RIGA 1: RIEPILOGO GENERALE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _datoSintetico(Icons.people, "$nPartecipanti"),
                  _separatoreSintetico(),
                  _datoSintetico(Icons.straighten, _formattaDistanza(snakeLen)),
                  _separatoreSintetico(),
                  _datoSintetico(Icons.adjust, "$nPunti"),
                  _separatoreSintetico(),
                  _datoSintetico(Icons.turn_right, "$nSvolte"),
                ],
              ),
              const Divider(height: 16),
              
              if (!eLeader || _sosAttivo) ...[
                Text(
                  _sosAttivo ? l10n.sosActive : l10n.speaking,
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    color: _sosAttivo ? Colors.red : Colors.orange
                  )
                ),
                Text(
                  _sosAttivo ? l10n.assistanceRequested : l10n.none,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 16),
              ],
              
              // CRUSCOTTO DI VIAGGIO (Colonne selettive per ruolo)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!eLeader) ...[
                    _colonnaCruscotto(
                      icona: const Icon(Icons.format_list_numbered, size: 16, color: Colors.blueGrey),
                      valore: miaPosizione > 0 ? "$miaPosizione/$nPartecipanti" : "-/$nPartecipanti",
                      label: "POS",
                    ),
                    _colonnaCruscotto(
                      icona: const Text("👑", style: TextStyle(fontSize: 14)),
                      valore: _formattaDistanza(distLeader),
                      label: "LEADER",
                    ),
                  ],
                  _colonnaCruscotto(
                    icona: const Text("🧹", style: TextStyle(fontSize: 14)),
                    valore: _formattaDistanza(distCoda),
                    label: "CODA",
                  ),
                  _colonnaCruscotto(
                    icona: const Text("📐", style: TextStyle(fontSize: 14)),
                    valore: "${relativeAngle > 0 ? '+' : ''}${relativeAngle.round()}°",
                    label: "ANGLE",
                    coloreValore: (eLeader && exceedsThreshold) ? Colors.red : null,
                  ),
                ],
              ),
              
              // ISTRUZIONI: Nascondere al Leader (Step 8 Clean-up)
              if (!eLeader && istruzione != null && istruzione.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
                    boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.navigation, size: 24, color: Colors.blue),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          istruzione.toUpperCase(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }
    );
  }

  Widget _datoSintetico(IconData icona, String testo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icona, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(testo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _separatoreSintetico() {
    return Container(
      height: 10,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _formattaDistanza(double metri) {
    if (metri < 1000) {
      return "${metri.round()} m";
    } else {
      return "${(metri / 1000).toStringAsFixed(1)} km";
    }
  }

  Widget _colonnaCruscotto({
    required Widget icona,
    required String valore,
    required String label,
    Color? coloreValore,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icona,
          const SizedBox(height: 4),
          Text(
            valore, 
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.bold, 
              color: coloreValore
            ), 
            overflow: TextOverflow.ellipsis
          ),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _costruisciListaPartecipanti(List<PartecipanteGruppo> partecipanti, String currentUid) {
    final l10n = AppLocalizations.of(context)!;
    if (partecipanti.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(l10n.noParticipants),
      ));
    }
    
    return Column(
      children: partecipanti.map((p) {
        final bool isMe = p.idUtente == currentUid;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('utenti').doc(p.idUtente).get(),
          builder: (context, uSnapshot) {
            final dati = uSnapshot.data?.data() as Map<String, dynamic>?;
            final String nome = (dati?['nickname']?.toString().isNotEmpty ?? false)
                ? dati!['nickname'].toString()
                : (dati?['nome']?.toString() ?? l10n.loading);
            final String moto = dati?['moto']?.toString() ?? "";
            
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isMe ? Colors.orange.shade100 : Colors.grey.shade200,
                    child: Text(_ottieniEmojiRuolo(p.ruolo), style: const TextStyle(fontSize: 14)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: p.online ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(nome + (isMe ? " (TU)" : ""), style: TextStyle(fontWeight: isMe ? FontWeight.w900 : FontWeight.bold, fontSize: 13)),
              subtitle: Text(moto, style: const TextStyle(fontSize: 11)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconaAudioToggle(Icons.mic, Icons.mic_off, true, "MICROFONO $nome"),
                  const SizedBox(width: 12),
                  _iconaAudioToggle(Icons.headset, Icons.headset_off, true, "CUFFIE $nome"),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _iconaAudioToggle(IconData on, IconData off, bool stato, String label) {
    return GestureDetector(
      onTap: () => _mostraInSviluppo(label),
      child: Icon(stato ? on : off, size: 18, color: stato ? Colors.blueGrey : Colors.red),
    );
  }

  String _ottieniEmojiRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader: return "👑";
      case RuoloGruppo.scopa: return "🧹";
      case RuoloGruppo.partecipante: return "👤";
    }
  }
}
