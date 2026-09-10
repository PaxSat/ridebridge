import 'dart:async';
import 'dart:math' as math;
import '../modelli/posizione_gps.dart';

/// Simulatore di movimento GPS per GeoRef V2.
class ServizioPosizioneFake {
  final _controller = StreamController<Map<String, PosizioneGps>>.broadcast();
  Timer? _timer;

  // Storico posizioni del leader per far sì che gli altri seguano lo stesso percorso
  final List<PosizioneGps> _bricioleLeader = [];

  // Stato iniziale (Roma, Colosseo circa)
  double _baseLat = 41.8902;
  double _baseLon = 12.4922;
  double _direzione = 0.0; // Nord
  final double _velocita = 13.8; // ~50 km/h in m/s

  /// Stream che emette le posizioni simulate per Leader, Scopa e un Partecipante.
  Stream<Map<String, PosizioneGps>> get streamPosizioni => _controller.stream;

  /// Avvia la simulazione di un tragitto.
  void avviaSimulazione() {
    _timer?.cancel();
    _bricioleLeader.clear();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 1. Il Leader si muove in avanti
      if (timer.tick % 20 == 0) {
        _direzione = (_direzione + 90) % 360; // Svolta a destra ogni 20 secondi
      } else {
        _direzione += (math.Random().nextDouble() - 0.5) * 0.5; // Micro correzioni stabili
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

      // 2. La Scopa segue le briciole (es. 20 secondi indietro -> ~276 metri)
      final indexScopa = _bricioleLeader.length > 20 ? _bricioleLeader.length - 20 : 0;
      final posScopa = _bricioleLeader[indexScopa];

      // 3. Un Partecipante che segue a metà strada tra leader e scopa
      final indexPart = _bricioleLeader.length > 10 ? _bricioleLeader.length - 10 : 0;

      // Simuliamo gli stati del partecipante_test
      PosizioneGps posPartecipante;
      if (timer.tick > 60 && timer.tick < 80) {
        // Avanti al leader (offset artificiale)
        posPartecipante = PosizioneGps(
          latitudine: _baseLat + 0.003,
          longitudine: _baseLon + 0.003,
          direzione: _direzione,
          velocita: _velocita,
          ultimoAggiornamento: DateTime.now(),
        );
      } else if (timer.tick >= 80) {
        // Fuori rotta
        posPartecipante = PosizioneGps(
          latitudine: _baseLat + 0.015,
          longitudine: _baseLon + 0.015,
          direzione: _direzione,
          velocita: _velocita,
          ultimoAggiornamento: DateTime.now(),
        );
      } else {
        // In gruppo (segue briciole)
        posPartecipante = _bricioleLeader[indexPart];
      }

      _controller.add({
        'leader': posLeader,
        'scopa': posScopa,
        'partecipante_test': posPartecipante,
      });
    });
  }

  /// Ferma la simulazione.
  void fermaSimulazione() {
    _timer?.cancel();
  }
}
