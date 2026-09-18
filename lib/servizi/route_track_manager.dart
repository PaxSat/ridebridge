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
  
  // Buffer locale per analisi geometrica (Step 8: Apex Algorithm)
  final List<PosizioneGps> _rawBuffer = [];
  PosizioneGps? _lastBufferedPos;

  // Configurazione soglie
  double sogliaDistanzaMeters;
  Duration sogliaTempo;
  double sogliaSvoltaGradi;
  double minTurnDistance;
  
  // Parametri Deep Tuning (Apex)
  int bufferSize;
  double samplingInterval;
  double straightDistance;

  RouteTrackManager({
    this.sogliaDistanzaMeters = 50.0,
    this.sogliaTempo = const Duration(seconds: 15),
    this.sogliaSvoltaGradi = 20.0,
    this.minTurnDistance = 15.0,
    this.bufferSize = 11,
    this.samplingInterval = 5.0,
    this.straightDistance = 1000.0,
  });

  /// Aggiorna le soglie operative dalla configurazione del gruppo.
  void aggiornaSoglie({
    required double distanza, 
    required double secondi, 
    required double gradi, 
    required double minTurnDist,
    int? bSize,
    double? sInterval,
    double? sDist,
  }) {
    sogliaDistanzaMeters = distanza;
    sogliaTempo = Duration(seconds: secondi.round());
    sogliaSvoltaGradi = gradi;
    minTurnDistance = minTurnDist;
    if (bSize != null) bufferSize = bSize;
    if (sInterval != null) samplingInterval = sInterval;
    if (sDist != null) straightDistance = sDist;
  }

  /// Pulisce l'intera traccia corrente.
  void reset() {
    _track.clear();
    _rawBuffer.clear();
    _lastBufferedPos = null;
    _nextSequenceId = 0;
  }

  /// Ripristina lo stato della traccia da una sorgente esterna (Recovery).
  void ripristinaStato(List<RoutePoint> punti, int ultimoSequenceId) {
    _track.clear();
    _track.addAll(punti);
    _nextSequenceId = ultimoSequenceId + 1;
  }

  /// Analizza una nuova posizione del leader e decide se generare un nuovo RoutePoint.
  /// Ritorna il nuovo [RoutePoint] se creato, altrimenti null.
  /// Logica V3.5 (Step 8): Algoritmo Apex con sliding window.
  RoutePoint? aggiungiPosizioneLeader(PosizioneGps pos, {bool ignoreTimeThreshold = false}) {
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
        triggerReason: PointTriggerReason.manual,
      );
      _track.add(primoPunto);
      _lastBufferedPos = pos;
      _rawBuffer.add(pos);
      return primoPunto;
    }

    final ultimoRegistrato = _track.last;
    
    // 1. GESTIONE BUFFER LOCALE (Campionamento ad alta frequenza)
    final distDalLastBuffered = _lastBufferedPos == null ? 0.0 : _evaluator.distanzaTraDuePunti(
      pos.latitudine, pos.longitudine,
      _lastBufferedPos!.latitudine, _lastBufferedPos!.longitudine,
    );

    if (distDalLastBuffered >= samplingInterval) {
      _rawBuffer.add(pos);
      _lastBufferedPos = pos;
      
      // Manteniamo la dimensione della finestra
      if (_rawBuffer.length > bufferSize) {
        _rawBuffer.removeAt(0);
      }
    }

    // Se il buffer non è ancora pieno, non possiamo fare analisi geometrica complessa,
    // ma controlliamo comunque la soppressione rettilinea per sicurezza (fallback).
    if (_rawBuffer.length < 3) return null;

    // 2. ANALISI SVOLTA (Cumulative Deviation)
    final primoBuffer = _rawBuffer.first;
    final ultimoBuffer = _rawBuffer.last;
    
    // Calcoliamo il bearing tra inizio e fine buffer
    final bearingFinestra = _evaluator.calcolaBearing(
      primoBuffer.latitudine, primoBuffer.longitudine,
      ultimoBuffer.latitudine, ultimoBuffer.longitudine,
    );

    // Differenza rispetto all'ultimo punto registrato
    double diffBearing = bearingFinestra - ultimoRegistrato.bearing;
    while (diffBearing < -180) {
      diffBearing += 360;
    }
    while (diffBearing > 180) {
      diffBearing -= 360;
    }

    final distDallultimoRegistrato = _evaluator.distanzaTraDuePunti(
      pos.latitudine, pos.longitudine,
      ultimoRegistrato.latitudine, ultimoRegistrato.longitudine,
    );

    // Condizione Svolta: deviazione finestra > soglia AND ci siamo mossi dal minimo
    bool triggerTurn = diffBearing.abs() >= sogliaSvoltaGradi && distDallultimoRegistrato >= minTurnDistance;

    if (triggerTurn) {
      // IDENTIFICAZIONE APEX: cerchiamo il punto nel buffer con la massima variazione locale
      // o semplicemente quello centrale per stabilità se il buffer è piccolo.
      // Implementiamo una ricerca del punto che massimizza la distanza dalla corda (primo-ultimo).
      int apexIdx = _rawBuffer.length ~/ 2;
      double maxDistDallaCorda = -1.0;

      for (int i = 1; i < _rawBuffer.length - 1; i++) {
        final d = _evaluator.distanzaPuntoSegmento(
          _rawBuffer[i].latitudine, _rawBuffer[i].longitudine,
          primoBuffer.latitudine, primoBuffer.longitudine,
          ultimoBuffer.latitudine, ultimoBuffer.longitudine,
        );
        if (d > maxDistDallaCorda) {
          maxDistDallaCorda = d;
          apexIdx = i;
        }
      }

      final apexPos = _rawBuffer[apexIdx];
      
      // Creiamo il punto di svolta
      final nuovoPunto = RoutePoint(
        id: _uuid.v4(),
        sequenceId: _nextSequenceId++,
        latitudine: apexPos.latitudine,
        longitudine: apexPos.longitudine,
        timestamp: apexPos.ultimoAggiornamento,
        bearing: bearingFinestra, // Usiamo il bearing della finestra per continuità
        distanzaDalPrecedente: _evaluator.distanzaTraDuePunti(apexPos.latitudine, apexPos.longitudine, ultimoRegistrato.latitudine, ultimoRegistrato.longitudine),
        distanzaProgressiva: ultimoRegistrato.distanzaProgressiva + _evaluator.distanzaTraDuePunti(apexPos.latitudine, apexPos.longitudine, ultimoRegistrato.latitudine, ultimoRegistrato.longitudine),
        triggerReason: PointTriggerReason.turn,
        turnAngle: diffBearing,
        turnDirection: diffBearing > 0 ? PointTurnDirection.right : PointTurnDirection.left,
      );

      _track.add(nuovoPunto);
      _rawBuffer.clear(); // Reset dopo commit svolta
      return nuovoPunto;
    }

    // 3. SOPPRESSIONE RETTILINEI (Commit per distanza massima)
    // Se non abbiamo svoltato, controlliamo se è il momento di mettere un punto "di pane"
    if (distDallultimoRegistrato >= straightDistance) {
      final nuovoPunto = RoutePoint(
        id: _uuid.v4(),
        sequenceId: _nextSequenceId++,
        latitudine: pos.latitudine,
        longitudine: pos.longitudine,
        timestamp: pos.ultimoAggiornamento,
        bearing: bearingFinestra,
        distanzaDalPrecedente: distDallultimoRegistrato,
        distanzaProgressiva: ultimoRegistrato.distanzaProgressiva + distDallultimoRegistrato,
        triggerReason: PointTriggerReason.distance,
      );
      _track.add(nuovoPunto);
      _rawBuffer.clear();
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
