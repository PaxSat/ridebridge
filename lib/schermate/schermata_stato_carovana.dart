import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
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
  String _riderSelezionato = 'leader';
  double _metriSpostamento = 25.0;

  // Cache per i nomi dei rider nel pannello debug
  final Map<String, String> _nomiCache = {};
  
  late final TextEditingController _latController;
  late final TextEditingController _lonController;

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
    final l10n = AppLocalizations.of(context)!;
    final controller = GeoRefController();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Risoluzione pigra dei nomi per il pannello debug
        for (var uid in controller.snapshotRidersCompleti.keys) {
          if (!_nomiCache.containsKey(uid)) {
            _nomiCache[uid] = "..."; // Placeholder caricamento
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

            return Scaffold(
              appBar: AppBar(
                title: Text("📍 ${l10n.caravanStatus}"),
                centerTitle: true,
                actions: [
                  if (controller.isAttivo)
                    TextButton(
                      onPressed: () => _confermaAbbandona(context, controller),
                      child: const Text("ABBANDONA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              body: Column(
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
        // Torniamo indietro alla schermata del Gruppo (uscendo sia dalla Carovana che dalla Conversazione)
        Navigator.of(context).pop(); // Esce dalla Carovana
        Navigator.of(context).pop(); // Esce dalla Conversazione
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
          const Text("Coordinate Iniziali Fake (Brescia default):", style: TextStyle(fontSize: 12)),
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

    listaId.sort((a, b) {
      final progA = controller.progressi[a]?.routeProgress ?? 0.0;
      final progB = controller.progressi[b]?.routeProgress ?? 0.0;
      return progB.compareTo(progA);
    });

    // Identificazione sicura del Leader
    String? leaderId; 
    for (var id in listaId) {
      if (controller.snapshotRidersCompleti[id]?.ruolo == RuoloGruppo.leader) {
        leaderId = id;
        break;
      }
    }
    
    // Se il leader non è ancora arrivato, usiamo il primo della lista per non crashare
    final leaderProg = (leaderId != null) ? (controller.progressi[leaderId]?.routeProgress ?? 0.0) : 0.0;

    return listaId.map((id) {
      final p = controller.progressi[id];
      final riderInfo = controller.snapshotRidersCompleti[id];
      if (riderInfo == null) return const SizedBox.shrink();

      final msg = controller.messaggiNavigazione[id];
      final avviso = controller.avvisiAttivi[id];

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: FutureBuilder<Utente?>(
          future: _servizioDatabase.leggiUtente(id),
          builder: (context, uSnapshot) {
            final utente = uSnapshot.data;
            final String nomeDisplay = utente?.nickname?.isNotEmpty == true
                ? utente!.nickname!
                : (utente?.nome ?? id.toUpperCase());

            final ruolo = riderInfo.ruolo;

            Color avatarColor;
            if (ruolo == RuoloGruppo.leader) {
              avatarColor = Colors.orange;
            } else if (ruolo == RuoloGruppo.scopa) {
              avatarColor = Colors.blue;
            } else {
              avatarColor = (p?.engineState.name == 'offRoute') ? Colors.purple : Colors.green;
            }

            final traccia = controller.leaderEngine.ottieniRoutePoints();
            double distProssimoPunto = 0.0;
            if (p != null && p.nextTargetIndex < traccia.length) {
              final target = traccia[p.nextTargetIndex];
              final miaPos = controller.ultimePosizioni[id];
              if (miaPos != null) {
                distProssimoPunto = LocationEvaluator().distanzaTraDuePunti(
                  miaPos.latitudine, miaPos.longitudine,
                  target.latitudine, target.longitudine
                );
              }
            }

            return ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: avatarColor,
                child: Icon(
                  ruolo == RuoloGruppo.leader ? Icons.star : (ruolo == RuoloGruppo.scopa ? Icons.shield : Icons.person),
                  color: Colors.white,
                ),
              ),
              title: Text(nomeDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(traccia.length >= 2 
                  ? (avviso?.messaggio ?? msg ?? "In marcia...") 
                  : "IN ATTESA DI SNAKE"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${p?.routeProgress.round() ?? 0}m", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("progresso", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              children: [
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _rigaDettaglio("Punto percorso (ID)", "${p.lastValidatedIndex}"),
                        _rigaDettaglio("Prossimo obiettivo", "${p.nextTargetIndex}"),
                        _rigaDettaglio("Distanza dal prossimo punto", "${distProssimoPunto.round()} m"),
                        _rigaDettaglio("Distanza dal Leader", "${(leaderProg - p.routeProgress).round()} m"),
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
                  value: controller.tuttiIMembriGruppo.any((m) => m.idUtente == _riderSelezionato) 
                      ? _riderSelezionato 
                      : (controller.tuttiIMembriGruppo.isNotEmpty 
                          ? controller.tuttiIMembriGruppo.first.idUtente 
                          : _riderSelezionato),
                  items: controller.tuttiIMembriGruppo.map((m) {
                    final uid = m.idUtente;
                    final ruoloEmoji = m.ruolo == RuoloGruppo.leader ? "👑 " : (m.ruolo == RuoloGruppo.scopa ? "🏍️ " : "");
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
                  onPressed: () => controller.forzaIngressoRider(_riderSelezionato),
                  child: const Text("ENTRA RIDER"),
                ),
                ElevatedButton(
                  onPressed: () => controller.forzaUscitaRider(_riderSelezionato),
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
        onPressed: () => controller.muoviRiderFake(_riderSelezionato, dir, _metriSpostamento),
        child: Text(dir, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }
}
