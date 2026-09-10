import 'package:cloud_firestore/cloud_firestore.dart';
import 'posizione_gps.dart';
import '../servizi/snake_formation_manager.dart'; // Per EngineState

/// Rappresenta lo stato di progressione di un partecipante lungo la traccia del Leader.
/// Filosofia: "Walking on the Snake".
class RouteProgress {
  final String uid;
  
  // Stato progressione sequenziale
  final int lastValidatedIndex;
  final String? lastValidatedId;
  final int nextTargetIndex;
  final String? nextTargetId;

  final double distanzaDalLastPoint;
  final double routeProgress; // Metri totali lungo la traccia
  final EngineState engineState;
  final int consecutiveMisses;
  final DateTime ultimoAggiornamento;
  final PosizioneGps ultimaPosizioneGps;

  RouteProgress({
    required this.uid,
    required this.lastValidatedIndex,
    this.lastValidatedId,
    required this.nextTargetIndex,
    this.nextTargetId,
    this.distanzaDalLastPoint = 0.0,
    this.routeProgress = 0.0,
    this.engineState = EngineState.normal,
    this.consecutiveMisses = 0,
    required this.ultimoAggiornamento,
    required this.ultimaPosizioneGps,
  });

  /// Crea un oggetto [RouteProgress] da una mappa Firestore.
  factory RouteProgress.daMappa(Map<String, dynamic> mappa, String uid) {
    return RouteProgress(
      uid: uid,
      lastValidatedIndex: mappa['lastValidatedIndex'] ?? -1,
      lastValidatedId: mappa['lastValidatedId'],
      nextTargetIndex: mappa['nextTargetIndex'] ?? 0,
      nextTargetId: mappa['nextTargetId'],
      distanzaDalLastPoint: (mappa['distanzaDalLastPoint'] as num?)?.toDouble() ?? 0.0,
      routeProgress: (mappa['routeProgress'] as num?)?.toDouble() ?? 0.0,
      engineState: EngineState.values.firstWhere(
        (e) => e.name == mappa['engineState'],
        orElse: () => EngineState.normal,
      ),
      consecutiveMisses: mappa['consecutiveMisses'] ?? 0,
      ultimoAggiornamento: (mappa['ultimoAggiornamento'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ultimaPosizioneGps: PosizioneGps.daMappa(mappa['ultimaPosizioneGps'] as Map<String, dynamic>),
    );
  }

  /// Converte l'oggetto [RouteProgress] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'lastValidatedIndex': lastValidatedIndex,
      'lastValidatedId': lastValidatedId,
      'nextTargetIndex': nextTargetIndex,
      'nextTargetId': nextTargetId,
      'distanzaDalLastPoint': distanzaDalLastPoint,
      'routeProgress': routeProgress,
      'engineState': engineState.name,
      'consecutiveMisses': consecutiveMisses,
      'ultimoAggiornamento': Timestamp.fromDate(ultimoAggiornamento),
      'ultimaPosizioneGps': ultimaPosizioneGps.aMappa(),
    };
  }

  /// Crea una copia con campi modificati.
  RouteProgress copiaCon({
    String? uid,
    int? lastValidatedIndex,
    String? lastValidatedId,
    int? nextTargetIndex,
    String? nextTargetId,
    double? distanzaDalLastPoint,
    double? routeProgress,
    EngineState? engineState,
    int? consecutiveMisses,
    DateTime? ultimoAggiornamento,
    PosizioneGps? ultimaPosizioneGps,
  }) {
    return RouteProgress(
      uid: uid ?? this.uid,
      lastValidatedIndex: lastValidatedIndex ?? this.lastValidatedIndex,
      lastValidatedId: lastValidatedId ?? this.lastValidatedId,
      nextTargetIndex: nextTargetIndex ?? this.nextTargetIndex,
      nextTargetId: nextTargetId ?? this.nextTargetId,
      distanzaDalLastPoint: distanzaDalLastPoint ?? this.distanzaDalLastPoint,
      routeProgress: routeProgress ?? this.routeProgress,
      engineState: engineState ?? this.engineState,
      consecutiveMisses: consecutiveMisses ?? this.consecutiveMisses,
      ultimoAggiornamento: ultimoAggiornamento ?? this.ultimoAggiornamento,
      ultimaPosizioneGps: ultimaPosizioneGps ?? this.ultimaPosizioneGps,
    );
  }
}
