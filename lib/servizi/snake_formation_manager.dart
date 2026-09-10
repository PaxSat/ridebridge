import '../modelli/route_point.dart';
import '../modelli/route_progress.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/tail_state.dart';
import '../servizi/location_evaluator.dart';
import '../servizi/formation_manager.dart'; // Per StatoCarovana enum

/// Stati interni della logica di progressione sulla traccia.
enum EngineState {
  normal,    // Il rider sta seguendo lo Snake sequenzialmente
  offRoute,  // Il rider è fuori dalla traccia o non riesce a validare i punti
  rejoin,    // Il rider è appena rientrato sulla traccia (stato transitorio)
  invalid,   // Dati GPS inaffidabili o segnale perso
}

/// Motore di progressione e gestione della formazione a serpentina (Snake Formation).
/// Filosofia: "Walking on the Snake".
class SnakeFormationManager {
  final _evaluator = LocationEvaluator();
  
  // Mappa degli stati di progressione per ogni partecipante
  final Map<String, RouteProgress> _progressi = {};
  
  // Contatori per conferma multipla AheadOfLeader
  final Map<String, int> _aheadConfirmations = {};
  
  // Parametri di configurazione
  static const int _lookAheadWindow = 3; // Finestra stretta per "camminare"
  static const double _validationRadius = 35.0; // Raggio per validare il passaggio
  static const double _offRouteThreshold = 150.0;
  static const int _maxConsecutiveMisses = 5; // N. campionamenti prima di OFF_ROUTE
  static const int _aheadConfirmationRequired = 3;
  static const double _aheadHysteresisMeters = 50.0;
  static const Duration _reliabilityTimeout = Duration(seconds: 30);

  /// Calcola il TailState attuale della carovana.
  TailState calcolaTailState(String? idScopa) {
    if (_progressi.isEmpty) return TailState.iniziale();

    final ora = DateTime.now();
    
    final membriAffidabili = _progressi.values.where((p) {
      final isRecent = ora.difference(p.ultimoAggiornamento) < _reliabilityTimeout;
      return isRecent && p.engineState != EngineState.invalid && p.lastValidatedIndex != -1;
    }).toList();

    if (membriAffidabili.isEmpty) return TailState.iniziale();

    if (idScopa != null && _progressi.containsKey(idScopa)) {
      final pScopa = _progressi[idScopa]!;
      final scopaRecent = ora.difference(pScopa.ultimoAggiornamento) < _reliabilityTimeout;
      if (scopaRecent && pScopa.engineState != EngineState.invalid && pScopa.lastValidatedIndex != -1) {
        return TailState(
          tailIndex: pScopa.lastValidatedIndex,
          tailUid: idScopa,
          isScopaReliable: true,
          timestamp: ora,
        );
      }
    }

    membriAffidabili.sort((a, b) => a.lastValidatedIndex.compareTo(b.lastValidatedIndex));
    final peggiore = membriAffidabili.first;

    return TailState(
      tailIndex: peggiore.lastValidatedIndex,
      tailUid: peggiore.uid,
      isScopaReliable: false,
      timestamp: ora,
    );
  }

  /// Restituisce la progressione di un utente specifico.
  RouteProgress? ottieniProgress(String uid) => _progressi[uid];

  /// Aggiorna la posizione di un partecipante e calcola la sua progressione sullo Snake.
  RouteProgress aggiornaPosizionePartecipante({
    required String uid,
    required PosizioneGps pos,
    required List<RoutePoint> traccia,
    required int leaderIndex,
  }) {
    final progressAttuale = _progressi[uid] ?? RouteProgress(
      uid: uid,
      lastValidatedIndex: -1,
      nextTargetIndex: 0,
      ultimoAggiornamento: DateTime.now(),
      ultimaPosizioneGps: pos,
    );

    if (traccia.isEmpty) return progressAttuale;

    // 1. Gestione raggancio (Se OFF_ROUTE o non ancora agganciato)
    if (progressAttuale.lastValidatedIndex == -1 || progressAttuale.engineState == EngineState.offRoute) {
      return _gestisciRaggancio(uid, pos, traccia, leaderIndex, progressAttuale);
    }

    // 2. LOGICA "WALKING ON THE SNAKE" (Sequenziale)
    int nextTarget = progressAttuale.nextTargetIndex;
    int maxSearch = (nextTarget + _lookAheadWindow).clamp(0, traccia.length - 1);
    
    int? nuovoValidato;
    double distDalPunto = 0.0;

    // Controlliamo in sequenza il target e i pochissimi punti successivi ammessi
    for (int i = nextTarget; i <= maxSearch; i++) {
      final dist = _evaluator.distanzaTraDuePunti(
        pos.latitudine, pos.longitudine,
        traccia[i].latitudine, traccia[i].longitudine,
      );

      if (dist < _validationRadius) {
        nuovoValidato = i;
        distDalPunto = dist;
      }
    }

    // 3. Transizioni di Stato e Progression
    RouteProgress nuovoProgress;

    if (nuovoValidato != null) {
      // Avanzamento riuscito
      final p = traccia[nuovoValidato];
      nuovoProgress = progressAttuale.copiaCon(
        lastValidatedIndex: nuovoValidato,
        lastValidatedId: p.id,
        nextTargetIndex: nuovoValidato + 1,
        distanzaDalLastPoint: distDalPunto,
        routeProgress: p.distanzaProgressiva + distDalPunto,
        engineState: EngineState.normal,
        consecutiveMisses: 0,
        ultimoAggiornamento: DateTime.now(),
        ultimaPosizioneGps: pos,
      );
    } else {
      // Target non raggiunto in questo campionamento
      int misses = progressAttuale.consecutiveMisses + 1;
      EngineState nuovoStato = progressAttuale.engineState;

      // Se superiamo la soglia di fallimenti, verifichiamo se siamo realmente OFF_ROUTE
      if (misses >= _maxConsecutiveMisses) {
        final lastPoint = traccia[progressAttuale.lastValidatedIndex.clamp(0, traccia.length - 1)];
        final distDallaTraccia = _evaluator.distanzaTraDuePunti(
          pos.latitudine, pos.longitudine,
          lastPoint.latitudine, lastPoint.longitudine,
        );

        if (distDallaTraccia > _offRouteThreshold) {
          nuovoStato = EngineState.offRoute;
        }
      }

      nuovoProgress = progressAttuale.copiaCon(
        consecutiveMisses: misses,
        engineState: nuovoStato,
        ultimoAggiornamento: DateTime.now(),
        ultimaPosizioneGps: pos,
      );
    }

    _progressi[uid] = nuovoProgress;
    return nuovoProgress;
  }

  /// Cerca il punto della traccia più vicino per riagganciare un utente fuori rotta.
  RouteProgress _gestisciRaggancio(String uid, PosizioneGps pos, List<RoutePoint> traccia, int leaderIndex, RouteProgress attuale) {
    int bestIndex = -1;
    double minDistance = double.infinity;

    // Raggancio limitato: cerchiamo nell'intorno del leader o dell'ultima posizione nota
    int searchCenter = attuale.lastValidatedIndex != -1 ? attuale.lastValidatedIndex : leaderIndex;
    int searchStart = (searchCenter - 100).clamp(0, traccia.length - 1);
    int searchEnd = (searchCenter + 100).clamp(0, traccia.length - 1);

    for (int i = searchStart; i <= searchEnd; i++) {
      final dist = _evaluator.distanzaTraDuePunti(
        pos.latitudine, pos.longitudine,
        traccia[i].latitudine, traccia[i].longitudine,
      );
      if (dist < minDistance) {
        minDistance = dist;
        bestIndex = i;
      }
    }

    if (bestIndex != -1 && minDistance < _validationRadius * 2) {
      final p = traccia[bestIndex];
      final nuovoProgress = RouteProgress(
        uid: uid,
        lastValidatedIndex: bestIndex,
        lastValidatedId: p.id,
        nextTargetIndex: bestIndex + 1,
        distanzaDalLastPoint: minDistance,
        routeProgress: p.distanzaProgressiva + minDistance,
        engineState: EngineState.rejoin,
        consecutiveMisses: 0,
        ultimoAggiornamento: DateTime.now(),
        ultimaPosizioneGps: pos,
      );
      _progressi[uid] = nuovoProgress;
      return nuovoProgress;
    }

    // Se non troviamo un punto vicino, rimaniamo in OFF_ROUTE
    return attuale.copiaCon(
      engineState: EngineState.offRoute,
      ultimoAggiornamento: DateTime.now(),
      ultimaPosizioneGps: pos,
    );
  }

  /// Determina lo stato della carovana (V1 compatibile) basandosi sulla progressione V2.
  StatoCarovana determinaStato({
    required String uid,
    required double leaderProgress,
  }) {
    final p = _progressi[uid];
    if (p == null) return StatoCarovana.inGroup;

    if (p.engineState == EngineState.offRoute) {
      return StatoCarovana.offRoute;
    }

    // AHEAD_OF_LEADER (con Isteresi)
    if (p.routeProgress > leaderProgress + 20.0) {
      _aheadConfirmations[uid] = (_aheadConfirmations[uid] ?? 0) + 1;
      if (_aheadConfirmations[uid]! >= _aheadConfirmationRequired) {
        return StatoCarovana.aheadOfLeader;
      }
    } else if (p.routeProgress < leaderProgress - _aheadHysteresisMeters) {
      _aheadConfirmations[uid] = 0;
    }

    return StatoCarovana.inGroup;
  }

  /// Ordina gli UID per progressione reale sulla traccia.
  List<String> ordinaCarovana() {
    final list = _progressi.values.toList();
    list.sort((a, b) => b.routeProgress.compareTo(a.routeProgress));
    return list.map((p) => p.uid).toList();
  }

  void reset() {
    _progressi.clear();
    _aheadConfirmations.clear();
  }
}
