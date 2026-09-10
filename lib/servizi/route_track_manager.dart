import 'package:uuid/uuid.dart';
import '../modelli/route_point.dart';
import '../modelli/posizione_gps.dart';
import 'location_evaluator.dart';

/// Gestisce la generazione e il mantenimento della traccia del Leader (GeoRef V2).
class RouteTrackManager {
  final _evaluator = LocationEvaluator();
  final _uuid = const Uuid();
  
  final List<RoutePoint> _track = [];
  int _nextSequenceId = 0;
  
  // Configurazione soglie
  double sogliaDistanzaMeters;
  Duration sogliaTempo;

  RouteTrackManager({
    this.sogliaDistanzaMeters = 25.0,
    this.sogliaTempo = const Duration(seconds: 4),
  });

  /// Pulisce l'intera traccia corrente.
  void reset() {
    _track.clear();
    _nextSequenceId = 0;
  }

  /// Analizza una nuova posizione del leader e decide se generare un nuovo RoutePoint.
  /// Ritorna il nuovo [RoutePoint] se creato, altrimenti null.
  /// Logica V2: distanza >= 25m AND tempo >= 4s.
  RoutePoint? aggiungiPosizioneLeader(PosizioneGps pos) {
    if (_track.isEmpty) {
      final primoPunto = RoutePoint(
        id: _uuid.v4(),
        sequenceId: _nextSequenceId++,
        latitudine: pos.latitudine,
        longitudine: pos.longitudine,
        timestamp: pos.ultimoAggiornamento,
        bearing: pos.direzione,
        distanzaDalPrecedente: 0.0,
        distanzaProgressiva: 0.0,
      );
      _track.add(primoPunto);
      return primoPunto;
    }

    final ultimo = _track.last;
    
    // Calcolo distanza dall'ultimo punto registrato
    final distanza = _evaluator.distanzaTraDuePunti(
      pos.latitudine, pos.longitudine,
      ultimo.latitudine, ultimo.longitudine,
    );

    // Calcolo tempo trascorso dall'ultimo punto
    final tempoTrascorso = pos.ultimoAggiornamento.difference(ultimo.timestamp);

    // Verifichiamo se ENTRAMBE le soglie sono state superate (CONDIZIONE AND)
    if (distanza >= sogliaDistanzaMeters && tempoTrascorso >= sogliaTempo) {
      // Calcolo bearing reale del segmento (P-1 -> P)
      final bearingSegmento = _evaluator.calcolaBearing(
        ultimo.latitudine, ultimo.longitudine,
        pos.latitudine, pos.longitudine,
      );

      final nuovoPunto = RoutePoint(
        id: _uuid.v4(),
        sequenceId: _nextSequenceId++,
        latitudine: pos.latitudine,
        longitudine: pos.longitudine,
        timestamp: pos.ultimoAggiornamento,
        bearing: bearingSegmento,
        distanzaDalPrecedente: distanza,
        distanzaProgressiva: ultimo.distanzaProgressiva + distanza,
      );
      _track.add(nuovoPunto);
      return nuovoPunto;
    }

    return null;
  }

  /// Esegue la Garbage Collection della traccia (GeoRef V2).
  /// Regola 1: Rimuove i punti passati da tutti i partecipanti.
  /// Regola 2: Rimuove i punti che eccedono la lunghezza massima dello Snake (Finestra Mobile).
  Map<String, int> garbageCollection({
    required List<int> completedSequenceIds,
    double? maxSnakeLength,
  }) {
    if (_track.isEmpty) return {'passed': 0, 'distance': 0};

    final headProgress = _track.last.distanzaProgressiva;
    int countPassed = 0;
    int countDistance = 0;

    final toRemove = <RoutePoint>[];

    for (var p in _track) {
      bool passatiTutti = completedSequenceIds.contains(p.sequenceId);
      bool fuoriFinestra = false;
      
      if (maxSnakeLength != null) {
        fuoriFinestra = (headProgress - p.distanzaProgressiva) > maxSnakeLength;
      }

      if (passatiTutti || fuoriFinestra) {
        toRemove.add(p);
        if (passatiTutti) {
          countPassed++;
        } else {
          countDistance++;
        }
      }
    }

    for (var p in toRemove) {
      _track.remove(p);
    }

    return {
      'passed': countPassed,
      'distance': countDistance,
    };
  }

  /// Restituisce tutti i punti della traccia registrati finora.
  List<RoutePoint> ottieniRoutePoints() {
    return List.unmodifiable(_track);
  }

  /// Restituisce l'ultimo punto della traccia.
  RoutePoint? ultimoRoutePoint() {
    return _track.isNotEmpty ? _track.last : null;
  }

  /// Restituisce la lunghezza totale della traccia percorsa (odometro).
  double lunghezzaPercorso() {
    return _track.isNotEmpty ? _track.last.distanzaProgressiva : 0.0;
  }
}
