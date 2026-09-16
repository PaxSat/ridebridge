import 'package:flutter/foundation.dart';
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
  
  // Buffer circolare per la scia GPS (Rider's Diary)
  final Map<String, List<PosizioneGps>> _breadcrumbs = {};
  
  // Contatori per conferma multipla AheadOfLeader
  final Map<String, int> _aheadConfirmations = {};
  
  // Parametri di configurazione
  static const int _lookAheadWindow = 3; // Finestra stretta per progressione sequenziale
  static const int _recoveryWindow = 20; // Finestra ampia per rientro da zone ombra
  static const double _validationRadius = 35.0; // Raggio per validare il passaggio
  static const double _maxBearingDifference = 60.0; // Tolleranza direzione per snapping (tornanti)
  static const double _offRouteThreshold = 150.0;
  static const int _maxConsecutiveMisses = 5; // N. campionamenti prima di OFF_ROUTE
  static const int _maxBreadcrumbs = 200; // Dimensione massima del diario (circa 15-20 min di guida)
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
    // 0. AGGIORNAMENTO DIARIO (Breadcrumbs)
    _registraPosizioneNelDiario(uid, pos);

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

    // 1b. RILEVAMENTO GAP (Sincronizzazione Retroattiva)
    // Se lo Snake è scappato molto avanti E abbiamo perso dei campionamenti (buio),
    // proviamo a usare il diario per ragganciare.
    if (progressAttuale.consecutiveMisses > 2 && _rilevaGapSincronizzazione(progressAttuale, traccia)) {
      final progressSincronizzato = _eseguiSincronizzazioneRetroattiva(uid, traccia, progressAttuale);
      if (progressSincronizzato != null) {
        _progressi[uid] = progressSincronizzato;
        return progressSincronizzato;
      }
    }

    // 2. LOGICA "WALKING ON THE SNAKE" (Snapping Geometrico su Segmenti)
    int? nuovoValidatoSeqId;
    double distDalPunto = 0.0;

    // Troviamo da dove iniziare la ricerca (l'ultimo punto validato o l'inizio della traccia)
    int currentIndex = traccia.indexWhere((p) => p.sequenceId == progressAttuale.lastValidatedIndex);
    int startIndex = (currentIndex == -1) ? 0 : currentIndex;

    // SCELTA FINESTRA DI RICERCA: 
    // Se siamo stati in "ombra" (misses > 2), usiamo la finestra di recovery ampia.
    // Altrimenti restiamo sulla finestra stretta per evitare salti (tornanti).
    int searchRadius = (progressAttuale.consecutiveMisses > 2) ? _recoveryWindow : _lookAheadWindow;
    int maxSearch = (startIndex + searchRadius).clamp(0, traccia.length - 1);
    
    for (int i = startIndex; i < maxSearch; i++) {
      final pA = traccia[i];
      final pB = traccia[i + 1];

      final distSegmento = _evaluator.distanzaPuntoSegmento(
        pos.latitudine, pos.longitudine,
        pA.latitudine, pA.longitudine,
        pB.latitudine, pB.longitudine,
      );

      if (distSegmento < _validationRadius) {
        final bearingSegmento = _evaluator.calcolaBearing(
          pA.latitudine, pA.longitudine, 
          pB.latitudine, pB.longitudine
        );
        
        double diffBearing = (pos.direzione - bearingSegmento).abs();
        if (diffBearing > 180) diffBearing = 360 - diffBearing;

        bool direzioneValida = (pos.velocita < 1.0) || (diffBearing < _maxBearingDifference);

        if (direzioneValida) {
          final distDaA = _evaluator.distanzaTraDuePunti(pos.latitudine, pos.longitudine, pA.latitudine, pA.longitudine);
          final distDaB = _evaluator.distanzaTraDuePunti(pos.latitudine, pos.longitudine, pB.latitudine, pB.longitudine);
          
          int idPuntoSegmento;
          double distPunto;
          
          // Se siamo molto vicini ad A (entro 5m), restiamo su A per stabilità iniziale
          if (distDaA < 5.0) {
            idPuntoSegmento = pA.sequenceId;
            distPunto = distDaA;
          } else if (distDaB < distDaA) {
            idPuntoSegmento = pB.sequenceId;
            distPunto = distDaB;
          } else {
            idPuntoSegmento = pA.sequenceId;
            distPunto = distDaA;
          }

          if (nuovoValidatoSeqId == null || idPuntoSegmento > nuovoValidatoSeqId) {
            nuovoValidatoSeqId = idPuntoSegmento;
            distDalPunto = distPunto;
          }
        }
      }
    }

    debugPrint('[GEOREF] Snapping uid=$uid startIndex=$startIndex nuovoValidatoSeqId=$nuovoValidatoSeqId distDalPunto=$distDalPunto');

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

    for (int i = searchStartIndex; i < searchEndIndex; i++) {
      final pA = traccia[i];
      final pB = traccia[i + 1];
      
      final dist = _evaluator.distanzaPuntoSegmento(
        pos.latitudine, pos.longitudine,
        pA.latitudine, pA.longitudine,
        pB.latitudine, pB.longitudine,
      );

      if (dist < minDistance || (dist < _validationRadius && pA.sequenceId > bestSeqId)) {
        minDistance = dist;
        
        // Stessa logica di precisione: se siamo vicini a B e più vicini a B che ad A, validiamo B
        final distDaA = _evaluator.distanzaTraDuePunti(pos.latitudine, pos.longitudine, pA.latitudine, pA.longitudine);
        final distDaB = _evaluator.distanzaTraDuePunti(pos.latitudine, pos.longitudine, pB.latitudine, pB.longitudine);
        if (distDaB < _validationRadius && distDaB < distDaA) {
          bestSeqId = pB.sequenceId;
        } else {
          bestSeqId = pA.sequenceId;
        }
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

  /// Ripristina l'avanzamento dei rider usando i dati forniti dalla Scopa (Recovery del Leader).
  void ripristinaAvanzamentiRider(Map<String, int> avanzamenti, List<RoutePoint> traccia) {
    avanzamenti.forEach((uid, lastIdx) {
      if (lastIdx >= 0) {
        RoutePoint? point;
        for (var pt in traccia) {
          if (pt.sequenceId == lastIdx) {
            point = pt;
            break;
          }
        }
        final baseProgress = point?.distanzaProgressiva ?? 0.0;
        final id = point?.id;
        
        _progressi[uid] = RouteProgress(
          uid: uid,
          lastValidatedIndex: lastIdx,
          lastValidatedId: id,
          nextTargetIndex: lastIdx + 1,
          routeProgress: baseProgress,
          ultimoAggiornamento: DateTime.now(),
          ultimaPosizioneGps: PosizioneGps(
            latitudine: point?.latitudine ?? 0.0,
            longitudine: point?.longitudine ?? 0.0,
            ultimoAggiornamento: DateTime.now(),
          ),
        );
      }
    });
  }

  void reset() {
    _progressi.clear();
    _breadcrumbs.clear();
    _aheadConfirmations.clear();
  }

  /// Registra una posizione nel diario locale del Rider.
  void _registraPosizioneNelDiario(String uid, PosizioneGps pos) {
    final diario = _breadcrumbs.putIfAbsent(uid, () => []);
    
    // Evitiamo di registrare posizioni identiche o troppo vicine per non sprecare buffer
    if (diario.isNotEmpty) {
      final ultima = diario.last;
      final dist = _evaluator.distanzaTraDuePunti(
        pos.latitudine, pos.longitudine,
        ultima.latitudine, ultima.longitudine
      );
      if (dist < 25.0) return; // Non registriamo se spostamento < 25m (minimo direttiva)
    }

    diario.add(pos);

    // Manteniamo il buffer entro il limite
    if (diario.length > _maxBreadcrumbs) {
      diario.removeAt(0);
    }
  }

  /// Verifica se esiste un divario significativo tra il Rider e lo Snake.
  bool _rilevaGapSincronizzazione(RouteProgress progress, List<RoutePoint> traccia) {
    if (traccia.isEmpty) return false;
    final ultimoSnakeId = traccia.last.sequenceId;
    
    // Se lo Snake è avanti di più di 5 punti rispetto al nostro target, c'è un gap
    return (ultimoSnakeId - progress.lastValidatedIndex) > 5;
  }

  /// Esegue un confronto geometrico tra il diario delle posizioni del Rider (breadcrumbs)
  /// e i segmenti dello Snake per recuperare il progresso perduto durante un blackout.
  RouteProgress? _eseguiSincronizzazioneRetroattiva(String uid, List<RoutePoint> traccia, RouteProgress attuale) {
    final diario = _breadcrumbs[uid];
    if (diario == null || diario.isEmpty) return null;

    // Troviamo da dove iniziare la ricerca (nuovi segmenti)
    int lastListIdx = traccia.indexWhere((p) => p.sequenceId == attuale.lastValidatedIndex);
    if (lastListIdx == -1) lastListIdx = 0;

    // OTTIMIZZAZIONE: Scansioniamo a ritroso dallo Snake più recente verso l'ultimo punto validato.
    // L'obiettivo è trovare il punto "più avanti" che abbiamo percorso fisicamente.
    for (int i = traccia.length - 2; i >= lastListIdx; i--) {
      final pA = traccia[i];
      final pB = traccia[i + 1];

      final bearingSegmento = _evaluator.calcolaBearing(
        pA.latitudine, pA.longitudine,
        pB.latitudine, pB.longitudine,
      );

      // Verifichiamo se una qualsiasi "briciola" del diario tocca questo segmento.
      // Scansioniamo a ritroso anche il diario (posizioni più recenti prima).
      for (var briciola in diario.reversed) {
        final dist = _evaluator.distanzaPuntoSegmento(
          briciola.latitudine, briciola.longitudine,
          pA.latitudine, pA.longitudine,
          pB.latitudine, pB.longitudine,
        );

        if (dist < _validationRadius) {
          // 4b. VINCOLO DI DIREZIONE ANCHE NELLA SINCRO RETROATTIVA
          double diffBearing = (briciola.direzione - bearingSegmento).abs();
          if (diffBearing > 180) diffBearing = 360 - diffBearing;

          // Ignoriamo il bearing solo se la velocità registrata era bassissima
          if (briciola.velocita < 1.0 || diffBearing < _maxBearingDifference) {
            // Precisione snapping
            final distDaA = _evaluator.distanzaTraDuePunti(briciola.latitudine, briciola.longitudine, pA.latitudine, pA.longitudine);
            final distDaB = _evaluator.distanzaTraDuePunti(briciola.latitudine, briciola.longitudine, pB.latitudine, pB.longitudine);

            final targetPoint = (distDaB < _validationRadius && distDaB < distDaA) ? pB : pA;

            // CRITICO: La sincronizzazione retroattiva deve portarci AVANTI.
            // Se troviamo un match per un punto già passato o uguale, continuiamo a cercare.
            if (targetPoint.sequenceId <= attuale.lastValidatedIndex) continue;

            debugPrint('[GEOREF] Sincro Retroattiva OK: uid=$uid ha ragganciato lo Snake a seq=${targetPoint.sequenceId}');

            return attuale.copiaCon(
              lastValidatedIndex: targetPoint.sequenceId,
              lastValidatedId: targetPoint.id,
              nextTargetIndex: targetPoint.sequenceId + 1,
              distanzaDalLastPoint: (targetPoint == pB) ? distDaB : dist,
              routeProgress: targetPoint.distanzaProgressiva + ((targetPoint == pB) ? 0 : dist),
              engineState: EngineState.normal,
              consecutiveMisses: 0,
              ultimoAggiornamento: DateTime.now(),
              ultimaPosizioneGps: briciola, 
            );
          }
        }
      }
    }

    return null;
  }
}
