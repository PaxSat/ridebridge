import 'dart:async';
import 'package:flutter/material.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/configurazione_gruppo.dart';
import '../modelli/evento_percorso.dart';
import '../servizi/servizio_posizione_fake.dart';
import '../servizi/route_tracker.dart';
import '../servizi/formation_manager.dart';

class SchermataDebugGeoref extends StatefulWidget {
  const SchermataDebugGeoref({super.key});

  @override
  State<SchermataDebugGeoref> createState() => _SchermataDebugGeorefState();
}

class _SchermataDebugGeorefState extends State<SchermataDebugGeoref> {
  final _fakeGps = ServizioPosizioneFake();
  final _tracker = RouteTracker();
  final _formation = FormationManager();
  final _config = ConfigurazioneGruppo(); // Touring di default

  Map<String, PosizioneGps> _ultimePosizioni = {};
  final Map<String, StatoCarovana> _statiMembri = {};
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _fakeGps.streamPosizioni.listen((posizioni) {
      setState(() {
        _ultimePosizioni = posizioni;
        _processaMotore();
      });
    });
    _fakeGps.avviaSimulazione();
  }

  void _processaMotore() {
    final leader = _ultimePosizioni['leader'];
    final scopa = _ultimePosizioni['scopa'];

    if (leader != null) {
      // 1. Tracciamento Waypoint (Leader)
      _tracker.processaPosizioneLeader(
        idGruppo: "debug_group",
        idLeader: "leader_uid",
        lat: leader.latitudine,
        lon: leader.longitudine,
        bearingAttuale: leader.direzione,
        turnThreshold: _config.turnThresholdAngle,
      );
    }

    if (scopa != null) {
      // 2. Rimozione Waypoint (Scopa)
      _tracker.aggiornaWaypointsPassati(scopa.latitudine, scopa.longitudine, 50.0);
    }

    // 3. Verifica Formazione per tutti
    _ultimePosizioni.forEach((id, pos) {
      _statiMembri[id] = _formation.verificaFormazione(
        idUtente: id,
        idLeader: "leader",
        idScopa: "scopa",
        posizioneUtente: pos,
        posizioneLeader: leader,
        posizioneScopa: scopa,
        config: _config,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fakeGps.fermaSimulazione();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Debug Georeferenziazione")),
      body: Column(
        children: [
          _costruisciPannelloInfo(),
          const Divider(thickness: 2),
          _costruisciSezioneWaypoints(),
          const Divider(thickness: 2),
          _costruisciSezionePartecipanti(),
        ],
      ),
    );
  }

  Widget _costruisciPannelloInfo() {
    final leader = _ultimePosizioni['leader'];
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("LEADER", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Bearing: ${leader?.direzione.toStringAsFixed(1)}°"),
            ],
          ),
          const SizedBox(height: 8),
          Text("Lat: ${leader?.latitudine.toStringAsFixed(6)}"),
          Text("Lon: ${leader?.longitudine.toStringAsFixed(6)}"),
        ],
      ),
    );
  }

  Widget _costruisciSezioneWaypoints() {
    final wps = _tracker.waypointAttivi;
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("WAYPOINT ATTIVI (${wps.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: wps.length,
              itemBuilder: (context, i) {
                final wp = wps[i];
                return ListTile(
                  dense: true,
                  leading: Icon(_ottieniIconaSvolta(wp.tipoEvento), color: Colors.blue),
                  title: Text(wp.tipoEvento.name),
                  subtitle: Text("Lat: ${wp.latitudine.toStringAsFixed(4)} Lon: ${wp.longitudine.toStringAsFixed(4)}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _costruisciSezionePartecipanti() {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("STATO CAROVANA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          Expanded(
            child: ListView(
              children: _ultimePosizioni.keys.map((id) {
                final stato = _statiMembri[id];
                return ListTile(
                  title: Text(id.toUpperCase()),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _ottieniColoreStato(stato),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      stato?.name ?? "unknown",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _ottieniIconaSvolta(TipoEventoPercorso tipo) {
    switch (tipo) {
      case TipoEventoPercorso.svoltaDestra: return Icons.turn_right;
      case TipoEventoPercorso.svoltaSinistra: return Icons.turn_left;
      case TipoEventoPercorso.inversione: return Icons.u_turn_left;
      default: return Icons.location_on;
    }
  }

  Color _ottieniColoreStato(StatoCarovana? stato) {
    switch (stato) {
      case StatoCarovana.inGroup: return Colors.green;
      case StatoCarovana.aheadOfLeader: return Colors.orange;
      case StatoCarovana.behindSweeper: return Colors.red;
      case StatoCarovana.offRoute: return Colors.purple;
      case StatoCarovana.groupBroken: return Colors.black;
      default: return Colors.grey;
    }
  }
}
