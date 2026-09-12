import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/configurazione_gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../modelli/route_progress.dart';
import '../modelli/engine_state.dart';
import '../modelli/tail_state.dart';
import '../servizi/servizio_posizione_fake.dart';
import '../servizi/servizio_posizione_real.dart';
import '../servizi/formation_manager.dart';
import '../servizi/waypoint_manager.dart';
import '../servizi/snake_formation_manager.dart';
import '../servizi/route_track_manager.dart';
import '../servizi/debug_manager.dart';
import '../servizi/leader_engine.dart';
import '../servizi/follower_engine.dart';

/// Schermata per monitorare lo stato della carovana (GeoRef V3) con Sezione Debug Condizionale.
class SchermataStatoCarovana extends StatefulWidget {
  final RuoloGruppo mioRuolo;
  final String mioUid;
  final String? idGruppo;

  const SchermataStatoCarovana({
    super.key,
    required this.mioRuolo,
    required this.mioUid,
    this.idGruppo,
  });

  @override
  State<SchermataStatoCarovana> createState() => _SchermataStatoCarovanaState();
}

class _SchermataStatoCarovanaState extends State<SchermataStatoCarovana> with WidgetsBindingObserver {
  final _fakeGps = ServizioPosizioneFake();
  final _trackManager = RouteTrackManager();
  final _snakeManager = SnakeFormationManager();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo();

  late LeaderEngine _leaderEngine;
  late FollowerEngine _followerEngine;

  bool _usaGpsReale = false;
  ServizioPosizioneReal? _servizioReal;
  bool _gpsDisabilitato = false;

  // Cache per mappare le informazioni complete provenienti dai due diversi flussi
  final Map<String, PartecipanteGruppo> _snapshotRidersCompleti = {};
  Map<String, PosizioneGps> _ultimePosizioni = {};
  final Map<String, RouteProgress> _progressi = {};
  final Map<String, String?> _messaggiNavigazione = {};
  final Map<String, AvvisoCarovana?> _avvisiAttivi = {};
  TailState? _tailState;
  StreamSubscription? _subscription;
  StreamSubscription? _localGpsSubscription;
  StreamSubscription<bool>? _gpsStatusSubscription;

  // Stato Simulatore Fake V3
  String _riderSelezionato = 'leader';
  double _metriSpostamento = 25.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _leaderEngine = LeaderEngine(_trackManager);
    _followerEngine = FollowerEngine(_snakeManager);

    if (widget.idGruppo != null) {
      _servizioReal = ServizioPosizioneReal(idGruppo: widget.idGruppo!, mioUid: widget.mioUid);
    }
    
    // Inizializza in base al DebugManager globale
    _usaGpsReale = !DebugManager().gpsFake;
    _cambiaSorgenteGps(_usaGpsReale);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _usaGpsReale) {
      _controllaGpsManualmente();
    }
  }

  Future<void> _controllaGpsManualmente() async {
    if (_servizioReal == null) return;
    final attivo = await _servizioReal!.isGpsAbilitato();
    if (mounted) {
      setState(() => _gpsDisabilitato = !attivo);
    }
  }

  void _cambiaSorgenteGps(bool reale) {
    _subscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _fakeGps.fermaSimulazione();
    _servizioReal?.ferma();

    setState(() {
      _usaGpsReale = reale;
      DebugManager().gpsFake = !reale;
      _gpsDisabilitato = false;
      
      _ultimePosizioni.clear();
      _snapshotRidersCompleti.clear();
      _progressi.clear();
      _messaggiNavigazione.clear();
      _avvisiAttivi.clear();
      _leaderEngine.reset();
      _followerEngine.reset();

      if (_usaGpsReale) {
        _subscription = _servizioReal?.streamPosizioni.listen((mappaPartecipanti) {
          if (mounted) {
            setState(() {
              _snapshotRidersCompleti.clear();
              _snapshotRidersCompleti.addAll(mappaPartecipanti);
              
              _ultimePosizioni.clear();
              mappaPartecipanti.forEach((uid, p) {
                if (p.posizioneGps != null) {
                  _ultimePosizioni[uid] = p.posizioneGps!;
                }
              });

              _processaMotoreV3();
            });
          }
        });

        _servizioReal?.avvia();
        _avviaBroadcastGpsReale();
      } else {
        _subscription = _fakeGps.streamPosizioni.listen((posizioni) {
          if (mounted) {
            setState(() {
              _ultimePosizioni = posizioni;
              
              // In modalità FAKE creiamo snap virtuali con partecipando=true per simulare
              _snapshotRidersCompleti.clear();
              posizioni.forEach((uid, gps) {
                _snapshotRidersCompleti[uid] = PartecipanteGruppo(
                  idUtente: uid,
                  ruolo: uid == 'leader' ? RuoloGruppo.leader : (uid == 'scopa' ? RuoloGruppo.scopa : RuoloGruppo.partecipante),
                  partecipando: true, // Tutti i rider immessi nel simulatore sono attivi
                  posizioneGps: gps,
                );
              });

              _processaMotoreV3();
            });
          }
        });
        _fakeGps.avviaSimulazione();
      }
        
      _gpsStatusSubscription = _servizioReal?.streamStatoGps.listen((attivo) {
        if (mounted) {
          setState(() => _gpsDisabilitato = !attivo);
        }
      });
    });
  }

  Future<void> _avviaBroadcastGpsReale() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _localGpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      final pos = PosizioneGps(
        latitudine: position.latitude,
        longitudine: position.longitude,
        altitudine: position.altitude,
        velocita: position.speed,
        direzione: position.heading,
        ultimoAggiornamento: position.timestamp,
      );
      _servizioReal?.aggiornaMiaPosizione(pos);
    });
  }

  void _processaMotoreV3() {
    final leaderKey = _usaGpsReale ? (_servizioReal?.leaderUid ?? '') : 'leader';
    final scopaKey = _usaGpsReale ? (_servizioReal?.scopaUid ?? '') : 'scopa';

    final leaderPos = _ultimePosizioni[leaderKey];
    if (leaderPos == null) return;

    // Conteggio dei soli partecipanti attivi (partecipando == true)
    final partecipantiAttivi = _snapshotRidersCompleti.values.where((p) => p.partecipando).toList();
    final int numeroPartecipantiAttivi = partecipantiAttivi.length;

    // 1. LeaderEngine costruisce lo snake condizionato alla modalità Ghost
    _leaderEngine.processaPosizioneLeader(leaderPos, numeroPartecipantiAttivi);

    final traccia = _leaderEngine.ottieniRoutePoints();
    final leaderSeqId = _leaderEngine.ultimoRoutePoint()?.sequenceId ?? 0;

    // REGOLE SNAKE: RoutePoints >= 2 altrimenti WAITING_SNAKE implicito negli stati
    final bool snakeValido = traccia.length >= 2;

    // 2. SOLO I PARTECIPANTI ATTIVI camminano sullo Snake
    _snapshotRidersCompleti.forEach((uid, rider) {
      if (rider.partecipando && rider.posizioneGps != null) {
        final progress = _followerEngine.aggiornaPosizionePartecipante(
          uid: uid,
          pos: rider.posizioneGps!,
          traccia: traccia,
          leaderSequenceId: leaderSeqId,
        );
        _progressi[uid] = progress;
      }
    });

    // 3. Calcolo TailState (I manager interni valutano le progressioni calcolate sopra dei soli attivi)
    _tailState = _snakeManager.calcolaTailState();

    // 4. Garbage Collection ordinaria basata ESCLUSIVAMENTE su chi sta partecipando
    if (partecipantiAttivi.isNotEmpty && snakeValido) {
      int minValidatedIndex = -1;
      for (var rider in partecipantiAttivi) {
        final p = _progressi[rider.idUtente];
        if (p == null) continue;
        if (p.lastValidatedIndex == -1) {
          minValidatedIndex = -1;
          break;
        }
        if (minValidatedIndex == -1 || p.lastValidatedIndex < minValidatedIndex) {
          minValidatedIndex = p.lastValidatedIndex;
        }
      }

      final completedIds = minValidatedIndex >= 0 
          ? List.generate(minValidatedIndex + 1, (i) => i) 
          : <int>[];

      _leaderEngine.eseguiGarbageCollection(
        completedSequenceIds: completedIds,
        distanzaMassimaGruppo: _config.distanzaMassimaGruppo,
      );
    }

    // 5. Analisi degli stati operativi solo per chi partecipa attivamente
    final leaderProgress = _progressi[leaderKey]?.routeProgress ?? 0.0;
    final scopaProgress = _progressi[scopaKey]?.routeProgress;

    _snapshotRidersCompleti.forEach((uid, rider) {
      if (rider.partecipando && rider.posizioneGps != null) {
        final p = _progressi[uid]!;
        final stato = _snakeManager.determinaStato(
          uid: uid,
          leaderProgress: leaderProgress,
          scopaProgress: scopaProgress,
          maxGroupDistance: _config.distanzaMassimaGruppo,
        );
        
        _avvisiAttivi[uid] = _formation.generaAvviso(uid, p.engineState, stato);
        
        final targetPoint = p.nextTargetIndex < traccia.length && p.nextTargetIndex >= 0 ? traccia[p.nextTargetIndex] : null;
        _messaggiNavigazione[uid] = _waypointManager.ottieniIstruzioneNavigazione(
          rider.posizioneGps!, targetPoint, _config.triggerDistanceMeters, p.engineState
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _fakeGps.fermaSimulazione();
    _servizioReal?.ferma();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool visibilitaCompleta = widget.mioRuolo == RuoloGruppo.leader || widget.mioRuolo == RuoloGruppo.scopa;
    final bool debugAttivo = DebugManager().debugMode;

    return Scaffold(
      appBar: AppBar(title: Text("📍 ${l10n.caravanStatus}"), centerTitle: true),
      body: Column(
        children: [
          if (_usaGpsReale && _gpsDisabilitato)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(8),
              child: const Text("GPS DISABILITATO!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView(
              children: [
                _costruisciListaMembriWidget(visibilitaCompleta),
                if (debugAttivo) ...[
                  const Divider(thickness: 3, color: Colors.deepPurple),
                  _costruisciPannelloDebugInformazioni(),
                  const Divider(),
                  _costruisciPannelloSimulatoreFake(),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costruisciListaMembriWidget(bool visibilitaCompleta) {
    final listaId = visibilitaCompleta ? _ultimePosizioni.keys.toList() : [widget.mioUid];
    listaId.sort((a, b) {
      final progA = _progressi[a]?.routeProgress ?? 0.0;
      final progB = _progressi[b]?.routeProgress ?? 0.0;
      return progB.compareTo(progA);
    });

    return Column(
      children: listaId.map((id) {
        final p = _progressi[id];
        final msg = _messaggiNavigazione[id];
        final avviso = _avvisiAttivi[id];
        if (p == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: p.engineState == EngineState.offRoute ? Colors.purple : Colors.green,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(id.toUpperCase()),
            subtitle: Text(tracciaValidaV3() ? (avviso?.messaggio ?? msg ?? "In marcia...") : "WAITING_SNAKE (Punti < 2)"),
            trailing: Text("${p.routeProgress.round()}m"),
          ),
        );
      }).toList(),
    );
  }

  bool tracciaValidaV3() => _leaderEngine.ottieniRoutePoints().length >= 2;

  Widget _costruisciPannelloDebugInformazioni() {
    final traccia = _leaderEngine.ottieniRoutePoints();
    final leaderKey = _usaGpsReale ? (_servizioReal?.leaderUid ?? 'N/A') : 'leader';
    final scopaKey = _usaGpsReale ? (_servizioReal?.scopaUid ?? 'N/A') : 'scopa';

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.deepPurple.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("A) DEBUG INFORMAZIONI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 8),
          Text("• GPS: ${_usaGpsReale ? 'REAL (Geolocator)' : 'FAKE (Simulatore)'}"),
          Text("• RoutePoints generati: ${traccia.length}"),
          Text("• Tail Index: ${_tailState?.tailIndex ?? -1} (${_tailState?.tailUid ?? 'N/A'})"),
          Text("• Leader UID: $leaderKey | Scopa UID: $scopaKey"),
          Text("• LastValidated mio: ${_progressi[widget.mioUid]?.lastValidatedIndex ?? -1}"),
          Text("• Target mio: ${_progressi[widget.mioUid]?.nextTargetIndex ?? -1}"),
          Text("• GC Status: Snake mobile attivo (${_config.distanzaMassimaGruppo.round()}m)"),
        ],
      ),
    );
  }

  Widget _costruisciPannelloSimulatoreFake() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("B) SIMULATORE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              Row(
                children: [
                  const Text("REALE / FAKE"),
                  Switch(
                    value: !_usaGpsReale,
                    onChanged: (val) => _cambiaSorgenteGps(!val),
                  ),
                ],
              )
            ],
          ),
          if (!_usaGpsReale) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Rider: "),
                DropdownButton<String>(
                  value: _riderSelezionato,
                  items: ['leader', 'scopa', 'p1', 'p2', 'p3'].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _riderSelezionato = val);
                  },
                ),
                const Spacer(),
                const Text("Metri: "),
                DropdownButton<double>(
                  value: _metriSpostamento,
                  items: [10.0, 25.0, 50.0, 100.0].map((double value) {
                    return DropdownMenuItem<double>(value: value, child: Text("${value.round()}m"));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _metriSpostamento = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Center(child: Text("JOYSTICK 8 DIREZIONI", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            _costruisciGrigliaJoystick(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _ultimePosizioni[_riderSelezionato] = PosizioneGps(
                        latitudine: 41.8902,
                        longitudine: 12.4922,
                        ultimoAggiornamento: DateTime.now(),
                      );
                      _processaMotoreV3();
                    });
                  },
                  child: const Text("ENTRA RIDER"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _ultimePosizioni.remove(_riderSelezionato);
                      _progressi.remove(_riderSelezionato);
                    });
                  },
                  child: const Text("ESCI RIDER"),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _costruisciGrigliaJoystick() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_joyButton("NW"), _joyButton("N"), _joyButton("NE")]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_joyButton("W"), const SizedBox(width: 50, height: 50, child: Icon(Icons.motorcycle, color: Colors.blue)), _joyButton("E")]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_joyButton("SW"), _joyButton("S"), _joyButton("SE")]),
      ],
    );
  }

  Widget _joyButton(String dir) {
    return Container(
      margin: const EdgeInsets.all(4),
      width: 50,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: Colors.blue.shade100),
        onPressed: () => _muoviRiderFake(dir),
        child: Text(dir, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }

  void _muoviRiderFake(String direzione) {
    final posAttuale = _ultimePosizioni[_riderSelezionato] ?? PosizioneGps(
      latitudine: 41.8902,
      longitudine: 12.4922,
      ultimoAggiornamento: DateTime.now(),
    );

    double dLat = 0.0;
    double dLon = 0.0;
    // Conversione approssimativa metri -> gradi
    final double offsetGradi = _metriSpostamento / 111320.0;

    if (direzione.contains("N")) dLat = offsetGradi;
    if (direzione.contains("S")) dLat = -offsetGradi;
    if (direzione.contains("E")) dLon = offsetGradi;
    if (direzione.contains("W")) dLon = -offsetGradi;

    setState(() {
      _ultimePosizioni[_riderSelezionato] = PosizioneGps(
        latitudine: posAttuale.latitudine + dLat,
        longitudine: posAttuale.longitudine + dLon,
        ultimoAggiornamento: DateTime.now(),
        direzione: posAttuale.direzione,
      );
      _processaMotoreV3();
    });
  }
}
