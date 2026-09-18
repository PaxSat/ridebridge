import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
import '../modelli/route_point.dart';
import '../servizi/georef_controller.dart';
import '../servizi/servizio_database.dart';
import '../servizi/debug_manager.dart';
import '../servizi/location_evaluator.dart';

/// Schermata passiva per il monitoraggio della carovana (GeoRef V3).
/// Osserva il GeoRefController persistente. Se debug attivo, permette input al simulatore.
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
  final ServizioDatabase _servizioDatabase = ServizioDatabase();
  String? _riderSelezionato; // Inizializzato dinamicamente al leader reale
  double _metriSpostamento = 25.0;

  // Cache per i nomi dei rider nel pannello debug
  final Map<String, String> _nomiCache = {};
  
  late final TextEditingController _latController;
  late final TextEditingController _lonController;

  String _formattaDistanza(double metri) {
    if (metri < 1000) {
      return "${metri.round()} m";
    } else {
      return "${(metri / 1000).toStringAsFixed(1)} km";
    }
  }

  @override
  void initState() {
    super.initState();
    final dm = DebugManager();
    _latController = TextEditingController(text: dm.latFake.toString());
    _lonController = TextEditingController(text: dm.lonFake.toString());
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final controller = GeoRefController();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Risoluzione nomi per il pannello debug
        for (var m in controller.tuttiIMembriGruppo) {
          final uid = m.idUtente;
          if (!_nomiCache.containsKey(uid) || _nomiCache[uid] == "...") {
            _nomiCache[uid] = "..."; 
            _servizioDatabase.leggiUtente(uid).then((utente) {
              if (mounted) {
                setState(() {
                  _nomiCache[uid] = utente?.nickname?.isNotEmpty == true
                      ? utente!.nickname!
                      : (utente?.nome ?? uid.substring(0, math.min(uid.length, 6)));
                });
              }
            });
          }
        }

        return ListenableBuilder(
          listenable: DebugManager(),
          builder: (context, _) {
            final bool debugAttivo = DebugManager().debugMode;
            final bool visibilitaCompleta = widget.mioRuolo == RuoloGruppo.leader || widget.mioRuolo == RuoloGruppo.scopa;

            // FIX: Impostiamo il leader reale come rider selezionato di default nel simulatore
            if (_riderSelezionato == null && controller.riderPartecipanti.isNotEmpty) {
              final leader = controller.riderPartecipanti.firstWhereOrNull((p) => p.ruolo == RuoloGruppo.leader);
              if (leader != null) {
                _riderSelezionato = leader.idUtente;
              } else {
                _riderSelezionato = controller.riderPartecipanti.first.idUtente;
              }
            }

            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: true,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "STATO CAROVANA",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (debugAttivo)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Center(
                        child: Text(
                          "[CRV_STAT]",
                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (controller.isAttivo)
                    TextButton(
                      onPressed: () => _confermaAbbandona(context, controller),
                      child: const Text("ABBANDONA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              body: OrientationBuilder(
                builder: (context, orientation) {
                  final bool isLandscape = orientation == Orientation.landscape;

                  if (isLandscape) {
                    return Row(
                      children: [
                        // SINISTRA: Lista Membri
                        Expanded(
                          flex: 3,
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 20),
                            children: _costruisciListaMembriWidget(controller, visibilitaCompleta).toList(),
                          ),
                        ),
                        // DESTRA: Pannello Debug / Simulatore
                        if (debugAttivo)
                          Expanded(
                            flex: 2,
                            child: Container(
                              color: Colors.grey.shade50,
                              child: ListView(
                                padding: const EdgeInsets.all(8),
                                children: [
                                  _costruisciPannelloDebugInformazioni(controller),
                                  const Divider(),
                                  _costruisciPannelloSimulatoreFake(controller),
                                  const Divider(),
                                  _costruisciPannelloImpostazioniDebug(controller),
                                ],
                              ),
                            ),
                          )
                      ],
                    );
                  }

                  return Column(
                    children: [
                      if (controller.gpsDisabilitato)
                        Container(
                          width: double.infinity,
                          color: Colors.red,
                          padding: const EdgeInsets.all(8),
                          child: const Text("GPS DISABILITATO!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 100), // Spazio extra per il fondo
                          children: [
                            ..._costruisciListaMembriWidget(controller, visibilitaCompleta),
                            if (debugAttivo) ...[
                              const Divider(thickness: 3, color: Colors.deepPurple),
                              _costruisciPannelloDebugInformazioni(controller),
                              const Divider(),
                              _costruisciPannelloSimulatoreFake(controller),
                              const Divider(),
                              _costruisciPannelloImpostazioniDebug(controller),
                            ]
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      }
    );
  }

  void _confermaAbbandona(BuildContext context, GeoRefController controller) async {
    final procedi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Abbandona Carovana"),
        content: const Text("Sei sicuro di voler fermare il GeoRef e uscire dalla formazione attiva?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULLA")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("FERMA TUTTO")
          ),
        ],
      ),
    );

    if (procedi == true) {
      await controller.stop();
      if (context.mounted) {
        Navigator.of(context).pop(); 
        Navigator.of(context).pop(); 
      }
    }
  }

  Widget _costruisciPannelloImpostazioniDebug(GeoRefController controller) {
    final dm = DebugManager();
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.red.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("⚙️ IMPOSTAZIONI DEBUG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ElevatedButton(
                onPressed: () {
                  dm.debugMode = false;
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("ESCI DEBUG"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("👻 GHOST SNAKE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    Text("Genera traccia anche se sei solo", style: TextStyle(fontSize: 10)),
                  ],
                ),
                Switch(
                  value: dm.ghostSnake,
                  activeThumbColor: Colors.orange,
                  onChanged: (val) {
                    controller.impostaGhostSnake(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("Coordinate Iniziali Fake (", style: TextStyle(fontSize: 12)),
              GestureDetector(
                onTap: () {
                  final dm = DebugManager();
                  _latController.text = "45.5422";
                  _lonController.text = "10.2118";
                  dm.impostaCoordinateFake(45.5422, 10.2118);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reset su Brescia!"), duration: Duration(seconds: 1)),
                  );
                },
                child: const Text("Brescia", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue, decoration: TextDecoration.underline)),
              ),
              const Text(" default):", style: TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: const InputDecoration(labelText: "Latitudine"),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _lonController,
                  decoration: const InputDecoration(labelText: "Longitudine"),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final lat = double.tryParse(_latController.text);
                final lon = double.tryParse(_lonController.text);
                if (lat != null && lon != null) {
                  dm.impostaCoordinateFake(lat, lon);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Coordinate Fake Aggiornate!"), duration: Duration(seconds: 1)),
                  );
                }
              },
              child: const Text("SALVA COORDINATE FAKE"),
            ),
          ),
        ],
      ),
    );
  }

  Iterable<Widget> _costruisciListaMembriWidget(GeoRefController controller, bool visibilitaCompleta) {
    final listaId = controller.snapshotRidersCompleti.keys
        .where((id) => controller.snapshotRidersCompleti[id]?.partecipando ?? false)
        .toList();
    
    if (listaId.isEmpty) return [];

    // ORDINAMENTO LEADER IN CIMA (Step 4b)
    listaId.sort((a, b) {
      final ruoloA = controller.snapshotRidersCompleti[a]?.ruolo;
      final ruoloB = controller.snapshotRidersCompleti[b]?.ruolo;
      
      if (ruoloA == RuoloGruppo.leader) return -1;
      if (ruoloB == RuoloGruppo.leader) return 1;
      
      final progA = controller.progressi[a]?.routeProgress ?? 0.0;
      final progB = controller.progressi[b]?.routeProgress ?? 0.0;
      return progB.compareTo(progA);
    });

    String? leaderId; 
    for (var id in listaId) {
      if (controller.snapshotRidersCompleti[id]?.ruolo == RuoloGruppo.leader) {
        leaderId = id;
        break;
      }
    }
    
    final leaderProg = (leaderId != null) ? (controller.progressi[leaderId]?.routeProgress ?? 0.0) : 0.0;

    return listaId.map((id) {
      final p = controller.progressi[id];
      final riderInfo = controller.snapshotRidersCompleti[id];
      if (riderInfo == null) return const SizedBox.shrink();

      final msg = controller.messaggiNavigazione[id];
      final avviso = controller.avvisiAttivi[id];

      final traccia = controller.leaderEngine.ottieniRoutePoints();
      final lastPoint = traccia.isNotEmpty ? traccia.last : null;
      
      double distProssimoPunto = 0.0;
      final target = traccia.firstWhereOrNull((pt) => pt.sequenceId == (p?.nextTargetIndex ?? -1));

      if (p != null && target != null) {
        final miaPos = controller.ultimePosizioni[id];
        if (miaPos != null) {
          distProssimoPunto = LocationEvaluator().distanzaTraDuePunti(
            miaPos.latitudine, miaPos.longitudine,
            target.latitudine, target.longitudine
          );
        }
      }

      Widget? triggerIcon;
      if (riderInfo.ruolo == RuoloGruppo.leader && lastPoint != null) {
        String label = "";
        Color color = Colors.grey;
        switch (lastPoint.triggerReason) {
          case PointTriggerReason.time: label = "T"; color = Colors.blue; break;
          case PointTriggerReason.distance: label = "D"; color = Colors.green; break;
          case PointTriggerReason.turn: label = "S"; color = Colors.red; break; // Rosso per visibilità su fondo arancio
          case PointTriggerReason.manual: label = "M"; color = Colors.purple; break;
          default: break;
        }
        if (label.isNotEmpty) {
          triggerIcon = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          );
        }
      }

      final avatarColor = (riderInfo.ruolo == RuoloGruppo.leader) ? Colors.orange : (riderInfo.ruolo == RuoloGruppo.scopa ? Colors.blue : ((p?.engineState.name == 'offRoute') ? Colors.purple : Colors.green));

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: FutureBuilder<Utente?>(
          future: _servizioDatabase.leggiUtente(id),
          builder: (context, uSnapshot) {
            final utente = uSnapshot.data;
            final String nomeDisplay = utente?.nickname?.isNotEmpty == true ? utente!.nickname! : (utente?.nome ?? id.toUpperCase());

            return ExpansionTile(
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    backgroundColor: avatarColor,
                    child: Icon(
                      riderInfo.ruolo == RuoloGruppo.leader ? Icons.star : (riderInfo.ruolo == RuoloGruppo.scopa ? Icons.cleaning_services : Icons.person),
                      color: Colors.white,
                    ),
                  ),
                  triggerIcon,
                ].whereType<Widget>().toList(),
              ),
              title: Text(nomeDisplay, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              subtitle: Text(traccia.length >= 2 ? (avviso?.messaggio ?? msg ?? "In marcia...") : "IN ATTESA DI SNAKE", maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formattaDistanza(p?.routeProgress ?? 0.0), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("progresso", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
      children: [
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (widget.mioRuolo == RuoloGruppo.leader && id == widget.mioUid) ...[
                          // VISUALIZZAZIONE SPECIFICA PER IL LEADER (MOTIVI CREAZIONE)
                          _rigaDettaglio("Punto Corrente (ID)", "${p.lastValidatedIndex}"),
                          if (lastPoint != null) ...[
                            _rigaDettaglio("Motivo Creazione", lastPoint.triggerReason.name.toUpperCase()),
                            if (lastPoint.turnAngle != null)
                              _rigaDettaglio("Angolo Svolta", "${lastPoint.turnAngle! > 0 ? '+' : ''}${lastPoint.turnAngle!.round()}° (${lastPoint.turnDirection?.name.toUpperCase()})"),
                          ],
                        ] else ...[
                          // VISUALIZZAZIONE STANDARD PER GLI ALTRI
                          _rigaDettaglio("Punto percorso (ID)", "${p.lastValidatedIndex}"),
                          _rigaDettaglio("Prossimo obiettivo", "${p.nextTargetIndex}"),
                          _rigaDettaglio("Distanza dal prossimo punto", _formattaDistanza(distProssimoPunto)),
                          _rigaDettaglio("Distanza dal Leader", _formattaDistanza(leaderProg - p.routeProgress)),
                        ],
                        
                        // NUOVO: Visualizzazione Coordinate con tasto VAI
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text("Lat:", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Text(p.ultimaPosizioneGps.latitudine.toStringAsFixed(6), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text("Lon:", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      Text(p.ultimaPosizioneGps.longitudine.toStringAsFixed(6), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final lat = p.ultimaPosizioneGps.latitudine;
                                final lon = p.ultimaPosizioneGps.longitudine;
                                final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.navigation, size: 16),
                              label: const Text("VAI", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),

                        if (p.engineState.name == 'offRoute')
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text("⚠️ FUORI ROTTA - Snake interrotto per questo rider", 
                              style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Dati telemetrici in fase di inizializzazione...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  )
              ],
            );
          },
        ),
      );
    });
  }

  Widget _rigaDettaglio(String etichetta, String valore) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etichetta, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
          Text(valore, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _costruisciPannelloDebugInformazioni(GeoRefController controller) {
    final traccia = controller.leaderEngine.ottieniRoutePoints();
    final debugGpsFake = DebugManager().gpsFake;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.deepPurple.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("A) DEBUG INFORMAZIONI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 8),
          Text("• GPS: ${!debugGpsFake ? 'REAL (Geolocator)' : 'FAKE (Simulatore)'}"),
          Text("• RoutePoints generati: ${traccia.length}"),
          Text("• Tail Index: ${controller.tailState?.tailIndex ?? -1}"),
          Text("• Engine Attivo: ${controller.isAttivo}"),
          Text("• Rider Selezionato: ${_nomiCache[_riderSelezionato] ?? _riderSelezionato}"),
        ],
      ),
    );
  }

  Widget _costruisciPannelloSimulatoreFake(GeoRefController controller) {
    final isFake = DebugManager().gpsFake;
    
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
                    value: isFake,
                    onChanged: (val) {
                      setState(() => DebugManager().gpsFake = val);
                      controller.ricaricaSorgenteGps();
                    },
                  ),
                ],
              )
            ],
          ),
          if (isFake) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Rider: "),
                DropdownButton<String>(
                  value: _riderSelezionato,
                  items: controller.tuttiIMembriGruppo.map((m) {
                    final uid = m.idUtente;
                    final ruoloEmoji = m.ruolo == RuoloGruppo.leader ? "👑 " : (m.ruolo == RuoloGruppo.scopa ? "🧹 " : "");
                    final nomeRider = _nomiCache[uid] ?? uid.substring(0, math.min(uid.length, 6));
                    return DropdownMenuItem<String>(
                      value: uid, 
                      child: Text("$ruoloEmoji$nomeRider")
                    );
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
            _costruisciGrigliaJoystick(controller),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _riderSelezionato == null ? null : () => controller.forzaIngressoRider(_riderSelezionato!),
                  child: const Text("ENTRA RIDER"),
                ),
                ElevatedButton(
                  onPressed: _riderSelezionato == null ? null : () => controller.forzaUscitaRider(_riderSelezionato!),
                  child: const Text("ESCI RIDER"),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _costruisciGrigliaJoystick(GeoRefController controller) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_joyButton(controller, "NW"), _joyButton(controller, "N"), _joyButton(controller, "NE")]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_joyButton(controller, "W"), const SizedBox(width: 50, height: 50, child: Icon(Icons.motorcycle, color: Colors.blue)), _joyButton(controller, "E")]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_joyButton(controller, "SW"), _joyButton(controller, "S"), _joyButton(controller, "SE")]),
      ],
    );
  }

  Widget _joyButton(GeoRefController controller, String dir) {
    return Container(
      margin: const EdgeInsets.all(4),
      width: 50,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: Colors.blue.shade100),
        onPressed: _riderSelezionato == null ? null : () => controller.muoviRiderFake(_riderSelezionato!, dir, _metriSpostamento),
        child: Text(dir, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }
}
