import 'dart:async';
import 'package:flutter/material.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/configurazione_gruppo.dart';
import '../modelli/evento_percorso.dart';
import '../modelli/avviso_carovana.dart';
import '../servizi/servizio_posizione_fake.dart';
import '../servizi/route_tracker.dart';
import '../servizi/formation_manager.dart';
import '../servizi/waypoint_manager.dart';

class SchermataDebugGeoref extends StatefulWidget {
  const SchermataDebugGeoref({super.key});

  @override
  State<SchermataDebugGeoref> createState() => _SchermataDebugGeorefState();
}

class _SchermataDebugGeorefState extends State<SchermataDebugGeoref> {
  final _fakeGps = ServizioPosizioneFake();
  final _tracker = RouteTracker();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo(); // Touring di default

  Map<String, PosizioneGps> _ultimePosizioni = {};
  final Map<String, StatoCarovana> _statiMembri = {};
  final Map<String, String?> _messaggiNavigazione = {};
  final Map<String, AvvisoCarovana?> _avvisiAttivi = {};
  String? _ultimoMembroCarovana;
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
      // 1. Rilevamento Svolte (Leader)
      _tracker.processaPosizioneLeader(
        idGruppo: "debug_group",
        idLeader: "leader_uid",
        lat: leader.latitudine,
        lon: leader.longitudine,
        bearingAttuale: leader.direzione,
        turnThreshold: _config.turnThresholdAngle,
      );

      // Sincronizziamo i nuovi waypoint con il WaypointManager
      for (var wp in _tracker.waypointAttivi) {
        _waypointManager.aggiungiWaypoint(wp);
      }
    }

    // 2. Aggiornamento progresso carovana sui waypoint
    _waypointManager.aggiornaProgresso(_ultimePosizioni);
    _ultimoMembroCarovana = _waypointManager.identificaUltimoMembro(_ultimePosizioni);

    // 3. Verifica Formazione e Messaggi per tutti
    _ultimePosizioni.forEach((id, pos) {
      final stato = _formation.verificaFormazione(
        idUtente: id,
        idLeader: "leader",
        idScopa: "scopa",
        posizioneUtente: pos,
        posizioneLeader: leader,
        posizioneScopa: scopa,
        config: _config,
      );
      
      _statiMembri[id] = stato;
      _avvisiAttivi[id] = _formation.generaAvviso(id, stato);

      // ORDINE DI PRIORITÀ MESSAGGI (Prompt 017)
      // 1. OFF_ROUTE
      // 2. BEHIND_SWEEPER (With Waypoints)
      // 3. AHEAD_OF_LEADER (Waypoints Disabled)
      // 4. Waypoint
      
      String? msg;
      final avviso = _avvisiAttivi[id];
      final wpMsg = _waypointManager.ottieniIstruzioneNavigazione(id, pos, _config.triggerDistanceMeters);

      if (stato == StatoCarovana.offRoute) {
        msg = avviso?.messaggio;
      } else if (stato == StatoCarovana.behindSweeper) {
        msg = "${avviso?.messaggio ?? ''} ${wpMsg ?? ''}".trim();
      } else if (stato == StatoCarovana.aheadOfLeader) {
        msg = avviso?.messaggio;
      } else if (stato == StatoCarovana.groupBroken) {
        msg = avviso?.messaggio;
      } else {
        msg = wpMsg ?? "In formazione...";
      }
      
      _messaggiNavigazione[id] = msg;
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
              Text("Ultimo: ${_ultimoMembroCarovana ?? '...'}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Lat: ${leader?.latitudine.toStringAsFixed(6)}"),
              Text("Bearing: ${leader?.direzione.toStringAsFixed(1)}°"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _costruisciSezioneWaypoints() {
    final attivi = _waypointManager.waypointsAttivi;
    final completati = _waypointManager.waypointsCompletati;

    return Expanded(
      flex: 2,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: "ATTIVI"),
                Tab(text: "COMPLETATI"),
              ],
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _listaManagedWaypoints(attivi),
                  _listaManagedWaypoints(completati),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaManagedWaypoints(List<ManagedWaypoint> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final mw = list[i];
        return ListTile(
          dense: true,
          leading: Icon(_ottieniIconaSvolta(mw.evento.tipoEvento), 
                color: mw.status == WaypointStatus.attivo ? Colors.blue : Colors.green),
          title: Text("${mw.evento.tipoEvento.name} (ID: ${mw.evento.id.substring(mw.evento.id.length - 4)})"),
          subtitle: Text("Passati: ${mw.partecipantiPassati.length} / ${_ultimePosizioni.length}"),
          trailing: mw.status == WaypointStatus.completato 
              ? const Icon(Icons.check_circle, color: Colors.green) 
              : null,
        );
      },
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
                final pos = _ultimePosizioni[id]!;
                final stato = _statiMembri[id];
                final eUltimo = id == _ultimoMembroCarovana;
                final istruzione = _messaggiNavigazione[id];
                final avviso = _avvisiAttivi[id];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _ottieniColoreStato(stato),
                      child: Text(id[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text("${id.toUpperCase()} ${eUltimo ? '(ULTIMO)' : ''}"),
                    subtitle: Text(avviso?.messaggio ?? (istruzione ?? "In formazione...")),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Stato: ${stato?.name}"),
                            Text("Nav: ${istruzione ?? 'nessuna'}"),
                            Text("Avviso: ${avviso?.messaggio ?? 'nessuno'}"),
                            Text("Coord: ${pos.latitudine.toStringAsFixed(5)}, ${pos.longitudine.toStringAsFixed(5)}"),
                          ],
                        ),
                      )
                    ],
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
