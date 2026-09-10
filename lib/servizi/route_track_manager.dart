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

  /// Esegue la Garbage Collection della traccia basata sulla progressione topologica.
  /// Rimuove i punti che hanno completato il ciclo di vita (superati da tutti).
  void garbageCollection({
    required List<int> completedSequenceIds,
    int? tailSequenceId,
    double? minSafetyBufferMeters,
  }) {
    if (_track.isEmpty) return;

    _track.removeWhere((p) {
      // Regola primaria: deve essere completato (tutti passati) basato sul sequenceId
      if (!completedSequenceIds.contains(p.sequenceId)) return false;

      // Regola secondaria (opzionale): deve essere strettamente dietro la coda tecnica attuale
      if (tailSequenceId != null && p.sequenceId >= tailSequenceId) return false;

      // Regola terziaria (opzionale): buffer metrico rispetto alla testa della carovana
      if (minSafetyBufferMeters != null) {
        final distaccoDallaTesta = _track.last.distanzaProgressiva - p.distanzaProgressiva;
        if (distaccoDallaTesta < minSafetyBufferMeters) return false;
      }

      return true;
    });
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
