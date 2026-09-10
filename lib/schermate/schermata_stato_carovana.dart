import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/configurazione_gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../modelli/route_progress.dart';
import '../modelli/engine_state.dart';
import '../modelli/tail_state.dart';
import '../servizi/servizio_posizione_fake.dart';
import '../servizi/formation_manager.dart';
import '../servizi/waypoint_manager.dart';
import '../servizi/snake_formation_manager.dart';
import '../servizi/route_track_manager.dart';

/// Schermata per monitorare lo stato della carovana e la navigazione (GeoRef V2).
class SchermataStatoCarovana extends StatefulWidget {
  final RuoloGruppo mioRuolo;
  final String mioUid;

  const SchermataStatoCarovana({
    super.key,
    required this.mioRuolo,
    required this.mioUid,
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

  Map<String, PosizioneGps> _ultimePosizioni = {};
  final Map<String, RouteProgress> _progressi = {};
  final Map<String, String?> _messaggiNavigazione = {};
  final Map<String, AvvisoCarovana?> _avvisiAttivi = {};
  TailState? _tailState;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _fakeGps.streamPosizioni.listen((posizioni) {
      if (mounted) {
        setState(() {
          _ultimePosizioni = posizioni;
          _processaMotoreV2();
        });
      }
    });
    _fakeGps.avviaSimulazione();
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

    // 4. Analisi stati e messaggi
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
      
      final targetPoint = p.nextTargetIndex < traccia.length ? traccia[p.nextTargetIndex] : null;
      _messaggiNavigazione[uid] = _waypointManager.ottieniIstruzioneNavigazione(
        pos, targetPoint, _config.triggerDistanceMeters, p.engineState
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fakeGps.fermaSimulazione();
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Column(
        children: [
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
            Text("Punti Traccia: ${_trackManager.ottieniRoutePoints().length}"),
          ],
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
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _ottieniColoreStato(p.engineState, avviso?.tipo),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(id.toUpperCase()),
              subtitle: Text(avviso?.messaggio ?? (msg ?? "In marcia...")),
              trailing: (p.engineState == EngineState.offRoute)
                  ? IconButton(icon: const Icon(Icons.navigation, color: Colors.blue), onPressed: _navigaAlLeader)
                  : Text("${p.routeProgress.round()}m"),
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
