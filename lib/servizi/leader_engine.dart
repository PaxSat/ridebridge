import '../modelli/posizione_gps.dart';
import '../modelli/route_point.dart';
import 'route_track_manager.dart';

/// Componente logico per il Leader (GeoRef V3).
/// Gestisce la creazione dello Snake in modo totalmente autonomo.
class LeaderEngine {
  final RouteTrackManager _trackManager;
  bool ghostSnake = false;
  double lunghezzaMassimaGhost = 1500.0;

  LeaderEngine(this._trackManager);

  /// [ignoreTimeThreshold] permette di saltare il controllo temporale (es. per simulatore Fake).
  RoutePoint? processaPosizioneLeader(PosizioneGps pos, int numeroPartecipantiAttivi, {bool ignoreTimeThreshold = false}) {
    if (!ghostSnake && numeroPartecipantiAttivi <= 1) {
      return null;
    }
    return _trackManager.aggiungiPosizioneLeader(pos, ignoreTimeThreshold: ignoreTimeThreshold);
  }

  /// Esegue i cicli di Garbage Collection (GC) in base allo stato del GhostSnake.
  Map<String, int> eseguiGarbageCollection({
    required List<int> completedSequenceIds,
    required double distanzaMassimaGruppo,
  }) {
    if (ghostSnake) {
      // GC basata solo sulla lunghezza massima spaziale del Ghost
      return _trackManager.garbageCollection(
        completedSequenceIds: const [],
        maxSnakeLength: lunghezzaMassimaGhost,
      );
    } else {
      // GC ordinaria protetta
      return _trackManager.garbageCollection(
        completedSequenceIds: completedSequenceIds,
        maxSnakeLength: distanzaMassimaGruppo,
      );
    }
  }

  List<RoutePoint> ottieniRoutePoints() => _trackManager.ottieniRoutePoints();
  RoutePoint? ultimoRoutePoint() => _trackManager.ultimoRoutePoint();
  double lunghezzaPercorso() => _trackManager.lunghezzaPercorso();
  void reset() => _trackManager.reset();

  /// Ripristina lo stato del motore da uno snapshot esistente (Recovery).
  void ripristinaStato(List<RoutePoint> punti, int ultimoSequenceId) {
    _trackManager.ripristinaStato(punti, ultimoSequenceId);
  }
}
