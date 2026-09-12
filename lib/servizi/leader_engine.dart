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

  /// Riceve ed elabora la nuova posizione fisica o simulata del Leader.
  /// Se Ghost è disattivato, blocca la generazione se non ci sono altri partecipanti attivi.
  RoutePoint? processaPosizioneLeader(PosizioneGps pos, int numeroPartecipantiAttivi) {
    if (!ghostSnake && numeroPartecipantiAttivi <= 1) {
      return null;
    }
    return _trackManager.aggiungiPosizioneLeader(pos);
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
}
