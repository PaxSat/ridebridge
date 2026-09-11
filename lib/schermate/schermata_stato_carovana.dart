import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/configurazione_gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../modelli/route_point.dart';
import '../modelli/route_progress.dart';
import '../modelli/engine_state.dart';
import '../modelli/tail_state.dart';
import '../servizi/servizio_posizione_fake.dart';
import '../servizi/servizio_posizione_real.dart';
import '../servizi/formation_manager.dart';
import '../servizi/waypoint_manager.dart';
import '../servizi/snake_formation_manager.dart';
import '../servizi/route_track_manager.dart';

/// Schermata per monitorare lo stato della carovana e la navigazione (GeoRef V2).
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

class _SchermataStatoCarovanaState extends State<SchermataStatoCarovana> {
  final _fakeGps = ServizioPosizioneFake();
  final _trackManager = RouteTrackManager();
  final _snakeManager = SnakeFormationManager();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo();

  bool _usaGpsReale = false;
  ServizioPosizioneReal? _servizioReal;

  Map<String, PosizioneGps> _ultimePosizioni = {};
  final Map<String, RouteProgress> _progressi = {};
  final Map<String, String?> _messaggiNavigazione = {};
  final Map<String, AvvisoCarovana?> _avvisiAttivi = {};
  TailState? _tailState;
  StreamSubscription? _subscription;

  // Debug GC Stats
  int _gcEliminatiPassati = 0;
  int _gcEliminatiDistanza = 0;

  @override
  void initState() {
    super.initState();
    if (widget.idGruppo != null) {
      _servizioReal = ServizioPosizioneReal(idGruppo: widget.idGruppo!, mioUid: widget.mioUid);
    }
    _cambiaSorgenteGps(false);
  }

  void _cambiaSorgenteGps(bool reale) {
    _subscription?.cancel();
    _fakeGps.fermaSimulazione();
    _servizioReal?.ferma();

    setState(() {
      _usaGpsReale = reale;
      // Reset stati per evitare conflitti tra simulazione e reale
      _ultimePosizioni.clear();
      _progressi.clear();
      _messaggiNavigazione.clear();
      _avvisiAttivi.clear();
      _trackManager.reset();
      _snakeManager.reset();

      final stream = _usaGpsReale ? _servizioReal?.streamPosizioni : _fakeGps.streamPosizioni;

      _subscription = stream?.listen((posizioni) {
        if (mounted) {
          setState(() {
            _ultimePosizioni = posizioni;
            _processaMotoreV2();
          });
        }
      });

      if (_usaGpsReale) {
        _servizioReal?.avvia();
      } else {
        _fakeGps.avviaSimulazione();
      }
    });
  }

  RoutePoint? _trovaRoutePointDaSequenceId(List<RoutePoint> traccia, int sequenceId) {
    if (sequenceId < 0) return null;
    return traccia.cast<RoutePoint?>().firstWhere(
      (pt) => pt?.sequenceId == sequenceId,
      orElse: () => null,
    );
  }

  void _processaMotoreV2() {
    final leaderPos = _ultimePosizioni['leader'];
    if (leaderPos == null) return;

    // 1. Il Leader genera la traccia
    _trackManager.aggiungiPosizioneLeader(leaderPos);
    final traccia = _trackManager.ottieniRoutePoints();
    final leaderSeqId = _trackManager.ultimoRoutePoint()?.sequenceId ?? 0;

    // 2. I partecipanti camminano sullo Snake
    _ultimePosizioni.forEach((uid, pos) {
      final progress = _snakeManager.aggiornaPosizionePartecipante(
        uid: uid,
        pos: pos,
        traccia: traccia,
        leaderSequenceId: leaderSeqId,
      );
      _progressi[uid] = progress;
    });

    // 3. Calcolo TailState
    _tailState = _snakeManager.calcolaTailState();

    // 4. Esecuzione Garbage Collection (GeoRef V2)
    // Regola 1: Rimuove i punti passati da tutti i partecipanti (Basato su lastValidatedIndex reale).
    // Regola 2: Mantiene la finestra mobile (distanzaMassimaGruppo).
    if (_ultimePosizioni.isNotEmpty) {
      // Calcoliamo il minimo lastValidatedIndex reale tra tutti i partecipanti attivi
      int minValidatedIndex = -1;
      
      for (var uid in _ultimePosizioni.keys) {
        final p = _progressi[uid];
        if (p == null) continue;
        
        // Se un partecipante non ha mai validato nulla, non possiamo eliminare per "passati tutti"
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

      final stats = _trackManager.garbageCollection(
        completedSequenceIds: completedIds,
        maxSnakeLength: _config.distanzaMassimaGruppo,
      );
      _gcEliminatiPassati = stats['passed'] ?? 0;
      _gcEliminatiDistanza = stats['distance'] ?? 0;
    }

    // 5. Analisi stati e messaggi
    final leaderProgress = _progressi['leader']?.routeProgress ?? 0.0;
    final scopaProgress = _progressi['scopa']?.routeProgress;

    _ultimePosizioni.forEach((uid, pos) {
      final p = _progressi[uid]!;
      
      final stato = _snakeManager.determinaStato(
        uid: uid,
        leaderProgress: leaderProgress,
        scopaProgress: scopaProgress,
        maxGroupDistance: _config.distanzaMassimaGruppo,
      );
      
      _avvisiAttivi[uid] = _formation.generaAvviso(uid, p.engineState, stato);
      
      final targetPoint = _trovaRoutePointDaSequenceId(traccia, p.nextTargetIndex);
      _messaggiNavigazione[uid] = _waypointManager.ottieniIstruzioneNavigazione(
        pos, targetPoint, _config.triggerDistanceMeters, p.engineState
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fakeGps.fermaSimulazione();
    _servizioReal?.ferma();
    super.dispose();
  }

  Future<void> _navigaAlLeader() async {
    final leader = _ultimePosizioni['leader'];
    if (leader == null) return;
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${leader.latitudine},${leader.longitudine}");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool visibilitaCompleta = widget.mioRuolo == RuoloGruppo.leader || widget.mioRuolo == RuoloGruppo.scopa;

    return Scaffold(
      appBar: AppBar(title: Text("📍 ${l10n.caravanStatus}"), centerTitle: true),
      body: Column(
        children: [
          _costruisciHeader(),
          const Divider(thickness: 2),
          _costruisciListaMembri(visibilitaCompleta),
        ],
      ),
    );
  }

  Widget _costruisciHeader() {
    final leader = _ultimePosizioni['leader'];
    final traccia = _trackManager.ottieniRoutePoints();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("MODALITÀ GPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(
                children: [
                  const Text("FAKE", style: TextStyle(fontSize: 10)),
                  Switch(
                    value: _usaGpsReale,
                    onChanged: widget.idGruppo != null ? _cambiaSorgenteGps : null,
                    activeThumbColor: Colors.green,
                  ),
                  const Text("REAL", style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("LEADER (SNAKE HEAD)", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Tail Index: ${_tailState?.tailIndex ?? 0}"),
            ],
          ),
          if (leader != null) ...[
            const SizedBox(height: 8),
            Text("Progressione: ${(_trackManager.lunghezzaPercorso()).round()}m"),
            Text("Punti Traccia: ${traccia.length}"),
          ],
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text("SEZIONE ROUTE POINTS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            dense: true,
            children: traccia.map((pt) {
              return ListTile(
                dense: true,
                title: Text("SEQ ${pt.sequenceId} • ${pt.distanzaProgressiva.round()}m"),
                subtitle: Text("Lat: ${pt.latitudine.toStringAsFixed(6)} • Lon: ${pt.longitudine.toStringAsFixed(6)}"),
              );
            }).toList(),
          ),
          ExpansionTile(
            title: const Text("SEZIONE TAIL DEBUG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            dense: true,
            children: [
              ListTile(
                dense: true,
                title: Text("Tail UID: ${_tailState?.tailUid ?? 'N/A'}"),
                subtitle: Text("Tail Index: ${_tailState?.tailIndex ?? 0}"),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text("GC DEBUG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            dense: true,
            children: [
              ListTile(
                dense: true,
                title: Text("Snake Length Attuale: ${traccia.isEmpty ? 0 : (traccia.last.distanzaProgressiva - traccia.first.distanzaProgressiva).round()}m"),
                subtitle: Text("Snake Length Configurata: ${_config.distanzaMassimaGruppo.round()}m"),
              ),
              ListTile(
                dense: true,
                title: Text("Range SEQ: ${traccia.isEmpty ? 'N/A' : '${traccia.first.sequenceId} -> ${traccia.last.sequenceId}'}"),
                subtitle: Text("Eliminati: $_gcEliminatiPassati (Passati) | $_gcEliminatiDistanza (Snake Window)"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Calcolo manuale del minimo lastValidatedIndex per coerenza con la logica automatica
                int minIdx = -1;
                for (var uid in _ultimePosizioni.keys) {
                  final p = _progressi[uid];
                  if (p == null || p.lastValidatedIndex == -1) {
                    minIdx = -1;
                    break;
                  }
                  if (minIdx == -1 || p.lastValidatedIndex < minIdx) minIdx = p.lastValidatedIndex;
                }

                final completedIds = minIdx >= 0 
                    ? List.generate(minIdx + 1, (i) => i) 
                    : <int>[];
                
                final stats = _trackManager.garbageCollection(
                  completedSequenceIds: completedIds,
                  maxSnakeLength: _config.distanzaMassimaGruppo,
                );

                _gcEliminatiPassati = stats['passed'] ?? 0;
                _gcEliminatiDistanza = stats['distance'] ?? 0;
                
                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("🛠️ GC Manuale: ${_gcEliminatiPassati + _gcEliminatiDistanza} punti eliminati."),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text("FORCE GC NOW"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _trackManager.reset();
                _snakeManager.reset();
                _progressi.clear();
                _messaggiNavigazione.clear();
                _avvisiAttivi.clear();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🔄 Engine Reset Completato"),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text("RESET ENGINE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _trackManager.reset();
                _snakeManager.reset();
                _progressi.clear();
                _messaggiNavigazione.clear();
                _avvisiAttivi.clear();

                final baseTime = DateTime.now();
                for (int i = 0; i <= 40; i++) {
                  // Spostamento di 0.00045 gradi ~ 50 metri
                  final lat = 45.0 + (i * 0.00045);
                  final pos = PosizioneGps(
                    latitudine: lat,
                    longitudine: 9.0,
                    ultimoAggiornamento: baseTime.add(Duration(seconds: i * 5)),
                  );
                  _trackManager.aggiungiPosizioneLeader(pos);
                  
                  if (i == 30) {
                    _ultimePosizioni['leader'] = pos;
                  }
                }

                setState(() {});
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🛤️ Traccia Fake Generata: 40 punti (2000m)"),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text("GENERA TRACCIA FAKE (1500m)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final traccia = _trackManager.ottieniRoutePoints();
                final p2 = traccia.cast<RoutePoint?>().firstWhere(
                  (p) => p?.sequenceId == 2,
                  orElse: () => null,
                );

                if (p2 != null) {
                  setState(() {
                    _ultimePosizioni['mario'] = PosizioneGps(
                      latitudine: p2.latitudine,
                      longitudine: p2.longitudine,
                      ultimoAggiornamento: DateTime.now(),
                    );
                    _processaMotoreV2();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("👤 MARIO (Motociclista) posizionato a SEQ 2"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ Errore: SEQ 2 non trovato nella traccia"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text("SIMULA RIDER ARRETRATO"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final traccia = _trackManager.ottieniRoutePoints();
                final p35 = traccia.cast<RoutePoint?>().firstWhere(
                  (p) => p?.sequenceId == 35,
                  orElse: () => null,
                );

                if (p35 != null) {
                  setState(() {
                    _ultimePosizioni['luigi'] = PosizioneGps(
                      latitudine: p35.latitudine,
                      longitudine: p35.longitudine,
                      ultimoAggiornamento: DateTime.now(),
                    );
                    _processaMotoreV2();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🚀 LUIGI (Motociclista) posizionato a SEQ 35 (AHEAD)"),
                      backgroundColor: Colors.purple,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ Errore: SEQ 35 non trovato. Generare traccia più lunga."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.trending_up),
              label: const Text("SIMULA RIDER AHEAD (SEQ 35)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costruisciListaMembri(bool visibilitaCompleta) {
    final listaId = visibilitaCompleta ? _ultimePosizioni.keys.toList() : [widget.mioUid];
    
    // Ordine carovana reale basato sulla progressione
    listaId.sort((a, b) {
      final progA = _progressi[a]?.routeProgress ?? 0.0;
      final progB = _progressi[b]?.routeProgress ?? 0.0;
      return progB.compareTo(progA);
    });

    return Expanded(
      child: ListView(
        children: listaId.map((id) {
          final p = _progressi[id];
          final msg = _messaggiNavigazione[id];
          final avviso = _avvisiAttivi[id];
          
          if (p == null) return const SizedBox.shrink();

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _ottieniColoreStato(p.engineState, avviso?.tipo),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(id.toUpperCase()),
              subtitle: Text(avviso?.messaggio ?? (msg ?? "In marcia...")),
              trailing: (p.engineState == EngineState.offRoute)
                  ? IconButton(icon: const Icon(Icons.navigation, color: Colors.blue), onPressed: _navigaAlLeader)
                  : Text("${p.routeProgress.round()}m"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SEZIONE RIDER DEBUG", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      Text("UID: ${p.uid}"),
                      Text("Engine State: ${p.engineState.name}"),
                      Text("Last Validated Index: ${p.lastValidatedIndex}"),
                      Text("Next Target Index: ${p.nextTargetIndex}"),
                      Text("Route Progress: ${p.routeProgress.toStringAsFixed(1)}m"),
                      Text("Consecutive Misses: ${p.consecutiveMisses}"),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _ottieniColoreStato(EngineState engine, TipoAvvisoCarovana? avviso) {
    if (engine == EngineState.offRoute) return Colors.purple;
    if (avviso == TipoAvvisoCarovana.aheadOfLeader) return Colors.orange;
    if (avviso == TipoAvvisoCarovana.behindSweeper) return Colors.red;
    return Colors.green;
  }
}
