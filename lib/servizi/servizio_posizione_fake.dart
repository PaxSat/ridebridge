import 'dart:async'; // re-trigger analysis
import 'dart:math' as math;
import '../modelli/posizione_gps.dart';
import '../modelli/partecipante_gruppo.dart';

/// Simulatore di movimento GPS per GeoRef V3.
/// Utilizza i membri reali del gruppo per una simulazione fedele.
class ServizioPosizioneFake {
  ServizioPosizioneFake();

  final _controller = StreamController<Map<String, PosizioneGps>>.broadcast();
  Timer? _timer;

  // Storico posizioni del leader per far sì che gli altri seguano lo stesso percorso
  final List<PosizioneGps> _bricioleLeader = [];

  // Stato iniziale (Brescia default)
  double _baseLat = 45.5416;
  double _baseLon = 10.2118;
  double _direzione = 0.0; // Nord
  final double _velocita = 13.8; // ~50 km/h in m/s

  List<PartecipanteGruppo> _membriCorrenti = [];
  
  // Posizioni manuali per UID (sovrascrivono il calcolo automatico)
  final Map<String, PosizioneGps> _posizioniManuali = {};

  void impostaPuntoPartenza(double lat, double lon) {
    _baseLat = lat;
    _baseLon = lon;
    _bricioleLeader.clear(); // Resetta lo snake quando cambia il punto di partenza
  }

  void aggiornaPosizioneManuale(String uid, PosizioneGps pos) {
    _posizioniManuali[uid] = pos;
    // Se è il leader a muoversi manualmente, aggiorniamo la base del generatore
    final leader = _membriCorrenti.firstWhere((p) => p.ruolo == RuoloGruppo.leader, orElse: () => _membriCorrenti.isNotEmpty ? _membriCorrenti.first : PartecipanteGruppo(idUtente: 'none', ruolo: RuoloGruppo.partecipante));
    if (uid == leader.idUtente) {
      _baseLat = pos.latitudine;
      _baseLon = pos.longitudine;
      _direzione = pos.direzione;
    }
  }

  void aggiornaMembriSimulazione(List<PartecipanteGruppo> membri) {
    _membriCorrenti = List.from(membri);
  }

  List<PartecipanteGruppo> getMembriCorrenti() => _membriCorrenti;

  /// Stream che emette le posizioni simulate.
  Stream<Map<String, PosizioneGps>> get streamPosizioni => _controller.stream;

  /// Avvia la simulazione (Timer di generazione).
  void avviaSimulazione() {
    _timer?.cancel();
    _bricioleLeader.clear();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 1. Il Leader si muove in avanti
      if (timer.tick % 20 == 0) {
        _direzione = (_direzione + 90) % 360; 
      } else {
        _direzione += (math.Random().nextDouble() - 0.5) * 0.5;
      }

      const tempo = 1.0;
      final distanza = _velocita * tempo;

      final deltaLat = (distanza * math.cos(_direzione * math.pi / 180.0)) / 111320.0;
      final deltaLon = (distanza * math.sin(_direzione * math.pi / 180.0)) / (111320.0 * math.cos(_baseLat * math.pi / 180.0));

      _baseLat += deltaLat;
      _baseLon += deltaLon;

      final posLeader = PosizioneGps(
        latitudine: _baseLat,
        longitudine: _baseLon,
        direzione: _direzione,
        velocita: _velocita,
        ultimoAggiornamento: DateTime.now(),
      );

      _bricioleLeader.add(posLeader);
      if (_bricioleLeader.length > 200) _bricioleLeader.removeAt(0);

      final Map<String, PosizioneGps> posizioni = {};
      
      if (_membriCorrenti.isEmpty) return;

      // Troviamo Leader e Scopa reali
      final leader = _membriCorrenti.firstWhere((p) => p.ruolo == RuoloGruppo.leader, orElse: () => _membriCorrenti.first);
      final scopa = _membriCorrenti.firstWhere((p) => p.ruolo == RuoloGruppo.scopa, orElse: () => _membriCorrenti.last);

      for (int i = 0; i < _membriCorrenti.length; i++) {
        final p = _membriCorrenti[i];
        
        // Se c'è una posizione manuale (joystick), usiamo quella
        if (_posizioniManuali.containsKey(p.idUtente)) {
          posizioni[p.idUtente] = _posizioniManuali[p.idUtente]!;
          
          // Se è il leader, aggiorniamo comunque le briciole per far seguire gli altri
          if (p.idUtente == leader.idUtente) {
            _bricioleLeader.add(posizioni[p.idUtente]!);
            if (_bricioleLeader.length > 200) _bricioleLeader.removeAt(0);
          }
        } else {
          // Altrimenti usiamo il calcolo automatico
          if (p.idUtente == leader.idUtente) {
            posizioni[p.idUtente] = posLeader;
            _bricioleLeader.add(posLeader);
            if (_bricioleLeader.length > 200) _bricioleLeader.removeAt(0);
          } else if (p.idUtente == scopa.idUtente) {
            final indexScopa = _bricioleLeader.length > 20 ? _bricioleLeader.length - 20 : 0;
            posizioni[p.idUtente] = _bricioleLeader.isNotEmpty ? _bricioleLeader[indexScopa] : posLeader;
          } else {
            final offset = (i + 1) * 3;
            final index = _bricioleLeader.length > offset ? _bricioleLeader.length - offset : 0;
            posizioni[p.idUtente] = _bricioleLeader.isNotEmpty ? _bricioleLeader[index] : posLeader;
          }
        }
      }

      _controller.add(posizioni);
    });
  }

  /// Ferma la simulazione.
  void fermaSimulazione() {
    _timer?.cancel();
  }
}
