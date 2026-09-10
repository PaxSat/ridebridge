import '../modelli/route_point.dart';
import '../modelli/route_progress.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/tail_state.dart';
import '../modelli/engine_state.dart';
import '../modelli/stato_carovana.dart';
import '../servizi/location_evaluator.dart';

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

  /// Calcola il TailState attuale della carovana basato esclusivamente sulla progressione.
  TailState calcolaTailState() {
    if (_progressi.isEmpty) return TailState.iniziale();

    final ora = DateTime.now();
    
    // Identifichiamo i membri affidabili (recenti e con stato valido)
    final membriAffidabili = _progressi.values.where((p) {
      final isRecent = ora.difference(p.ultimoAggiornamento) < _reliabilityTimeout;
      return isRecent && p.engineState != EngineState.invalid && p.lastValidatedIndex != -1;
    }).toList();

    if (membriAffidabili.isEmpty) return TailState.iniziale();

    // Il TailState è definito dal membro più arretrato tra quelli affidabili.
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
    required int leaderSequenceId,
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
      return _gestisciRaggancio(uid, pos, traccia, leaderSequenceId, progressAttuale);
    }

    // 2. LOGICA "WALKING ON THE SNAKE" (Validazione Atomica)
    int nextTargetSeqId = progressAttuale.nextTargetIndex;
    
    // Troviamo l'indice reale del target nella lista
    int targetListIndex = traccia.indexWhere((p) => p.sequenceId == nextTargetSeqId);
    
    if (targetListIndex == -1) {
       return progressAttuale.copiaCon(
         ultimoAggiornamento: DateTime.now(), 
         ultimaPosizioneGps: pos
       );
    }

    int maxSearch = (targetListIndex + _lookAheadWindow).clamp(0, traccia.length - 1);
    
    int? nuovoValidatoSeqId;
    double distDalPunto = 0.0;

    // Controlliamo in sequenza il target e i pochissimi punti successivi ammessi
    for (int i = targetListIndex; i <= maxSearch; i++) {
      final dist = _evaluator.distanzaTraDuePunti(
        pos.latitudine, pos.longitudine,
        traccia[i].latitudine, traccia[i].longitudine,
      );

      if (dist < _validationRadius) {
        nuovoValidatoSeqId = traccia[i].sequenceId;
        distDalPunto = dist;
      }
    }

    RouteProgress nuovoProgress;

    if (nuovoValidatoSeqId != null) {
      final p = traccia.firstWhere((pt) => pt.sequenceId == nuovoValidatoSeqId);
      nuovoProgress = progressAttuale.copiaCon(
        lastValidatedIndex: nuovoValidatoSeqId,
        lastValidatedId: p.id,
        nextTargetIndex: nuovoValidatoSeqId + 1,
        distanzaDalLastPoint: distDalPunto,
        routeProgress: p.distanzaProgressiva + distDalPunto,
        engineState: EngineState.normal,
        consecutiveMisses: 0,
        ultimoAggiornamento: DateTime.now(),
        ultimaPosizioneGps: pos,
      );
    } else {
      int misses = progressAttuale.consecutiveMisses + 1;
      EngineState nuovoStato = progressAttuale.engineState;

      final lastPointIndex = traccia.indexWhere((pt) => pt.sequenceId == progressAttuale.lastValidatedIndex);
      final refPoint = lastPointIndex != -1 ? traccia[lastPointIndex] : traccia.first;
      
      final distDalloSnake = _evaluator.distanzaTraDuePunti(
        pos.latitudine, pos.longitudine,
        refPoint.latitudine, refPoint.longitudine,
      );

      if (misses >= _maxConsecutiveMisses && distDalloSnake > _offRouteThreshold) {
        nuovoStato = EngineState.offRoute;
      }

      nuovoProgress = progressAttuale.copiaCon(
        distanzaDalLastPoint: distDalloSnake,
        routeProgress: refPoint.distanzaProgressiva + distDalloSnake,
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
  RouteProgress _gestisciRaggancio(String uid, PosizioneGps pos, List<RoutePoint> traccia, int leaderSeqId, RouteProgress attuale) {
    int bestSeqId = -1;
    double minDistance = double.infinity;

    int searchEndIndex = traccia.indexWhere((p) => p.sequenceId == leaderSeqId);
    if (searchEndIndex == -1) searchEndIndex = traccia.length - 1;

    int searchStartIndex = (searchEndIndex - 100).clamp(0, traccia.length - 1);

    for (int i = searchStartIndex; i <= searchEndIndex; i++) {
      final dist = _evaluator.distanzaTraDuePunti(
        pos.latitudine, pos.longitudine,
        traccia[i].latitudine, traccia[i].longitudine,
      );
      if (dist < minDistance) {
        minDistance = dist;
        bestSeqId = traccia[i].sequenceId;
      }
    }

    if (bestSeqId != -1 && minDistance < _validationRadius * 2) {
      final p = traccia.firstWhere((pt) => pt.sequenceId == bestSeqId);
      final nuovoProgress = RouteProgress(
        uid: uid,
        lastValidatedIndex: bestSeqId,
        lastValidatedId: p.id,
        nextTargetIndex: bestSeqId + 1,
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

    return attuale.copiaCon(
      engineState: EngineState.offRoute,
      ultimoAggiornamento: DateTime.now(),
      ultimaPosizioneGps: pos,
    );
  }

  /// Determina lo stato della carovana basandosi sulla progressione topologica V2.
  StatoCarovana determinaStato({
    required String uid,
    required double leaderProgress,
    required double? scopaProgress,
    required double maxGroupDistance,
  }) {
    final p = _progressi[uid];
    if (p == null) return StatoCarovana.inGroup;

    if (p.engineState == EngineState.offRoute) return StatoCarovana.offRoute;

    // 0. Verifica GROUP_BROKEN (Lunghezza reale della serpentina)
    if (leaderProgress - p.routeProgress > maxGroupDistance) {
      return StatoCarovana.groupBroken;
    }

    // 1. AHEAD_OF_LEADER (con Isteresi)
    if (p.routeProgress > leaderProgress + 20.0) {
      _aheadConfirmations[uid] = (_aheadConfirmations[uid] ?? 0) + 1;
      if (_aheadConfirmations[uid]! >= _aheadConfirmationRequired) {
        return StatoCarovana.aheadOfLeader;
      }
    } else if (p.routeProgress < leaderProgress - _aheadHysteresisMeters) {
      _aheadConfirmations[uid] = 0;
    }

    // 2. BEHIND_SWEEPER (Progressione relativa alla Scopa)
    if (scopaProgress != null && uid != 'scopa' && p.routeProgress < scopaProgress - 30.0) {
      return StatoCarovana.behindSweeper;
    }

    return StatoCarovana.inGroup;
  }

  void reset() {
    _progressi.clear();
    _aheadConfirmations.clear();
  }
}
