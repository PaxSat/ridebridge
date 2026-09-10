import 'package:uuid/uuid.dart';
import '../modelli/route_point.dart';
import '../modelli/posizione_gps.dart';
import 'location_evaluator.dart';

/// Gestisce la generazione e il mantenimento della traccia del Leader (GeoRef V2).
class RouteTrackManager {
  final _evaluator = LocationEvaluator();
  final _uuid = const Uuid();
  
  final List<RoutePoint> _track = [];
  
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
  }

  /// Analizza una nuova posizione del leader e decide se generare un nuovo RoutePoint.
  /// Ritorna il nuovo [RoutePoint] se creato, altrimenti null.
  RoutePoint? aggiungiPosizioneLeader(PosizioneGps pos) {
    if (_track.isEmpty) {
      final primoPunto = RoutePoint(
        id: _uuid.v4(),
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

    // Verifichiamo se le soglie sono state superate
    if (distanza >= sogliaDistanzaMeters || tempoTrascorso >= sogliaTempo) {
      // Calcolo bearing reale del segmento (P-1 -> P)
      final bearingSegmento = _evaluator.calcolaBearing(
        ultimo.latitudine, ultimo.longitudine,
        pos.latitudine, pos.longitudine,
      );

      final nuovoPunto = RoutePoint(
        id: _uuid.v4(),
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

  /// Esegue la Garbage Collection della traccia.
  /// Rimuove i punti superati da tutta la carovana oltre una distanza di buffer.
  void pulisciPuntiSuperati(int tailIndex, {double bufferMeters = 1000.0}) {
    if (_track.isEmpty || tailIndex <= 0) return;

    // Troviamo il punto corrispondente alla coda tecnica
    final safeTailIndex = tailIndex.clamp(0, _track.length - 1);
    final progressivoCoda = _track[safeTailIndex].distanzaProgressiva;

    // Rimuoviamo i punti che sono:
    // 1. Dietro l'indice della coda (index < tailIndex)
    // 2. Più lontani del buffer rispetto al progresso della coda
    _track.removeWhere((p) {
      final indexPunto = _track.indexOf(p);
      if (indexPunto >= safeTailIndex) return false;

      final distacco = progressivoCoda - p.distanzaProgressiva;
      return distacco > bufferMeters;
    });
  }
}
