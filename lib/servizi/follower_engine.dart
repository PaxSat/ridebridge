import '../modelli/posizione_gps.dart';
import '../modelli/route_point.dart';
import '../modelli/route_progress.dart';
import 'snake_formation_manager.dart';

/// Macchina a stati esplicita del Follower Engine per GeoRef V3.
enum FollowerStateV3 {
  waitingSnake,
  following,
  offRoute,
  rejoin,
}

/// Componente logico per i partecipanti inseguitori (GeoRef V3).
/// Interfaccia pulita verso SnakeFormationManager.
class FollowerEngine {
  final SnakeFormationManager _formationManager;

  FollowerEngine(this._formationManager);

  /// Determina lo stato del Follower controllando la dimensione minima dello Snake.
  FollowerStateV3 determinaStatoV3(List<RoutePoint> traccia, RouteProgress? progress) {
    if (traccia.length < 2) {
      return FollowerStateV3.waitingSnake;
    }
    if (progress == null) {
      return FollowerStateV3.waitingSnake;
    }
    
    // Mappatura concettuale dallo stato computato inferiore
    if (progress.lastValidatedIndex == -1) {
      return FollowerStateV3.offRoute;
    }
    
    // Per retrocompatibilità leggiamo il manager interno
    return FollowerStateV3.following;
  }

  /// Aggiorna la posizione e processa il cammino topologico del rider
  RouteProgress aggiornaPosizionePartecipante({
    required String uid,
    required PosizioneGps pos,
    required List<RoutePoint> traccia,
    required int leaderSequenceId,
  }) {
    return _formationManager.aggiornaPosizionePartecipante(
      uid: uid,
      pos: pos,
      traccia: traccia,
      leaderSequenceId: leaderSequenceId,
    );
  }

  RouteProgress? ottieniProgress(String uid) => _formationManager.ottieniProgress(uid);
  void reset() => _formationManager.reset();
}
