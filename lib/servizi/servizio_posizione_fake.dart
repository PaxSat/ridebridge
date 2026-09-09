import 'dart:async';
import 'dart:math' as math;
import '../modelli/posizione_gps.dart';

/// Simulatore di movimento GPS per testare il motore di georeferenziazione.
class ServizioPosizioneFake {
  final _controller = StreamController<Map<String, PosizioneGps>>.broadcast();
  Timer? _timer;

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
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // 1. Il Leader si muove in avanti
      // Simuliamo una leggera oscillazione di direzione e una svolta ogni tanto
      if (timer.tick % 15 == 0) {
        _direzione = (_direzione + 90) % 360; // Svolta a destra ogni 30 secondi
      } else {
        _direzione += (math.Random().nextDouble() - 0.5) * 2; // Micro correzioni
      }

      // Calcolo spostamento (distanza = velocità * tempo)
      const tempo = 2.0; // secondi
      final distanza = _velocita * tempo;
      
      // Conversione approssimativa metri -> gradi (1 grado lat ~ 111km)
      final deltaLat = (distanza * math.cos(_direzione * math.pi / 180.0)) / 111320.0;
      final deltaLon = (distanza * math.sin(_direzione * math.pi / 180.0)) / (111320.0 * math.cos(_baseLat * math.pi / 180.0));

      _baseLat += deltaLat;
      _baseLon += deltaLon;

      final ora = DateTime.now();

      final posLeader = PosizioneGps(
        latitudine: _baseLat,
        longitudine: _baseLon,
        direzione: _direzione,
        velocita: _velocita,
        ultimoAggiornamento: ora,
      );

      // 2. La Scopa segue a distanza (es. 500 metri indietro)
      final distScopa = 500.0;
      final latScopa = _baseLat - (distScopa * math.cos(_direzione * math.pi / 180.0)) / 111320.0;
      final lonScopa = _baseLon - (distScopa * math.sin(_direzione * math.pi / 180.0)) / (111320.0 * math.cos(_baseLat * math.pi / 180.0));

      final posScopa = PosizioneGps(
        latitudine: latScopa,
        longitudine: lonScopa,
        direzione: _direzione,
        velocita: _velocita,
        ultimoAggiornamento: ora,
      );

      // 3. Un Partecipante che cambia stato
      double latPart = _baseLat;
      double lonPart = _baseLon;
      
      if (timer.tick < 10) {
        // In gruppo (tra leader e scopa)
        latPart = (_baseLat + latScopa) / 2;
        lonPart = (_baseLon + lonScopa) / 2;
      } else if (timer.tick < 20) {
        // Avanti al leader
        latPart = _baseLat + (200 * math.cos(_direzione * math.pi / 180.0)) / 111320.0;
        lonPart = _baseLon + (200 * math.sin(_direzione * math.pi / 180.0)) / (111320.0 * math.cos(_baseLat * math.pi / 180.0));
      } else {
        // Fuori rotta (spostato lateralmente di 2km)
        latPart = _baseLat + 0.02;
        lonPart = _baseLon + 0.02;
      }

      final posPartecipante = PosizioneGps(
        latitudine: latPart,
        longitudine: lonPart,
        direzione: _direzione,
        velocita: _velocita,
        ultimoAggiornamento: ora,
      );

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
