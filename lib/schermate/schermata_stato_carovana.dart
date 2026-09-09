import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/configurazione_gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../servizi/servizio_posizione_fake.dart';
import '../servizi/route_tracker.dart';
import '../servizi/formation_manager.dart';
import '../servizi/waypoint_manager.dart';

/// Schermata per monitorare lo stato della carovana e la navigazione.
/// Sostituisce la precedente schermata di debug.
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
  final _tracker = RouteTracker();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo();

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
      if (mounted) {
        setState(() {
          _ultimePosizioni = posizioni;
          _processaMotore();
        });
      }
    });
    _fakeGps.avviaSimulazione();
  }

  void _processaMotore() {
    final leader = _ultimePosizioni['leader'];
    final scopa = _ultimePosizioni['scopa'];

    if (leader != null) {
      _tracker.processaPosizioneLeader(
        idGruppo: "ride_group",
        idLeader: "leader",
        lat: leader.latitudine,
        lon: leader.longitudine,
        bearingAttuale: leader.direzione,
        turnThreshold: _config.turnThresholdAngle,
      );

      for (var wp in _tracker.waypointAttivi) {
        _waypointManager.aggiungiWaypoint(wp);
      }
    }

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

    _waypointManager.aggiornaProgresso(_ultimePosizioni, _statiMembri);
    _ultimoMembroCarovana = _waypointManager.identificaUltimoMembro(_ultimePosizioni);

    _ultimePosizioni.forEach((id, pos) {
      final stato = _statiMembri[id]!;
      _avvisiAttivi[id] = _formation.generaAvviso(id, stato);

      final wpMsg = _waypointManager.ottieniIstruzioneNavigazione(id, pos, _config.triggerDistanceMeters, stato);

      String? msg;
      if (stato == StatoCarovana.offRoute) {
        msg = _avvisiAttivi[id]?.messaggio;
      } else if (stato == StatoCarovana.behindSweeper || stato == StatoCarovana.groupBroken) {
        msg = "${_avvisiAttivi[id]?.messaggio ?? ''} ${wpMsg ?? ''}".trim();
      } else if (stato == StatoCarovana.aheadOfLeader) {
        msg = _avvisiAttivi[id]?.messaggio;
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

  /// Apre l'app di navigazione esterna verso la posizione del Leader.
  Future<void> _navigaAlLeader() async {
    final leader = _ultimePosizioni['leader'];
    if (leader == null) return;

    final lat = leader.latitudine;
    final lon = leader.longitudine;

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
      // Fallback su browser se l'app non è installata
      final fallbackUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool eLeaderOScopa = widget.mioRuolo == RuoloGruppo.leader || widget.mioRuolo == RuoloGruppo.scopa;

    return Scaffold(
      appBar: AppBar(
        title: Text("📍 ${l10n.caravanStatus}"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _costruisciPannelloInfo(),
          const Divider(thickness: 2),
          _costruisciSezioneWaypoints(eLeaderOScopa),
          const Divider(thickness: 2),
          _costruisciSezioneMembri(eLeaderOScopa),
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
              Text("Coda: ${_ultimoMembroCarovana?.toUpperCase() ?? '...'}", 
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Bearing: ${leader?.direzione.toStringAsFixed(1)}°"),
              Text("Vel: ${(leader?.velocita ?? 0 * 3.6).round()} km/h"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _costruisciSezioneWaypoints(bool visibilitaCompleta) {
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
                  _listaWaypoints(attivi, visibilitaCompleta),
                  _listaWaypoints(completati, visibilitaCompleta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaWaypoints(List<ManagedWaypoint> list, bool visibilitaCompleta) {
    final membriInCarovana = _ultimePosizioni.keys.where((id) {
      final stato = _statiMembri[id];
      return stato != StatoCarovana.aheadOfLeader && stato != StatoCarovana.offRoute;
    }).toList();

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final mw = list[i];
        final ev = mw.evento;

        var entries = membriInCarovana.map((id) {
          final pos = _ultimePosizioni[id]!;
          final dist = _formation.locationEvaluator.distanzaTraDuePunti(
            pos.latitudine, pos.longitudine,
            ev.latitudine, ev.longitudine,
          );
          final passato = mw.partecipantiPassati.contains(id);
          return _MembroInfo(id: id, distanza: dist, passato: passato);
        }).toList();

        // 1. Il Leader non viene mai mostrato (è il riferimento iniziale)
        entries.removeWhere((e) => e.id == "leader");

        // 2. Chi ha già superato la svolta scompare dal waypoint (regola di pulizia)
        entries.removeWhere((e) => e.passato);

        // ORDINAMENTO: per distanza crescente dal waypoint (chi è più vicino in cima)
        entries.sort((a, b) => a.distanza.compareTo(b.distanza));

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: mw.status == WaypointStatus.completato ? Colors.green.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ev.tipoEvento.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("${mw.partecipantiPassati.length} / ${membriInCarovana.length}"),
                  ],
                ),
                if (entries.isNotEmpty) ...[
                  const Divider(),
                  ...entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${e.id.toUpperCase()}: ${e.distanza.round()}m", 
                             style: const TextStyle(fontSize: 12)),
                        const Text("IN ARRIVO", style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                ] else if (mw.status == WaypointStatus.attivo) ...[
                  const Divider(),
                  const Center(
                    child: Text("Tutti i membri hanno svoltato", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.green)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _costruisciSezioneMembri(bool visibilitaCompleta) {
    // Se non sono leader/scopa, mostro solo il mio stato
    final listaId = visibilitaCompleta ? _ultimePosizioni.keys.toList() : [widget.mioUid];

    return Expanded(
      flex: 2,
      child: ListView(
        children: listaId.map((id) {
          final pos = _ultimePosizioni[id];
          final stato = _statiMembri[id];
          final msg = _messaggiNavigazione[id];
          
          if (pos == null) return const SizedBox.shrink();

          final bool isAhead = stato == StatoCarovana.aheadOfLeader;
          final bool isOffRoute = stato == StatoCarovana.offRoute;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _ottieniColoreStato(stato),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text("${id.toUpperCase()} - ${stato?.name.toUpperCase()}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg ?? "In attesa...", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  if (isAhead || isOffRoute)
                    ElevatedButton.icon(
                      onPressed: _navigaAlLeader,
                      icon: const Icon(Icons.navigation, size: 14),
                      label: const Text("NAVIGA AL LEADER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
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

class _MembroInfo {
  final String id;
  final double distanza;
  final bool passato;
  _MembroInfo({required this.id, required this.distanza, required this.passato});
}
