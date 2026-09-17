import '../modelli/posizione_gps.dart';
import '../modelli/route_point.dart';
import 'route_track_manager.dart';

/// Componente logico per il Leader (GeoRef V3).
/// Gestisce la creazione dello Snake in modo totalmente autonomo.
class LeaderEngine {
  final RouteTrackManager _trackManager;
  bool ghostSnake = false;
  bool autoGhostActive = false; // Indica se il Ghost è scattato per solitudine (Emergenza)
  double distanzaMassimaGhost = 15000.0;

  LeaderEngine(this._trackManager);

  /// [ignoreTimeThreshold] permette di saltare il controllo temporale (es. per simulatore Fake).
  RoutePoint? processaPosizioneLeader(PosizioneGps pos, int numeroPartecipantiAttivi, {bool ignoreTimeThreshold = false}) {
    // Il leader crea sempre punti se in modalità Ghost (Manuale o Auto)
    // o se ci sono almeno 2 persone.
    if (!ghostSnake && !autoGhostActive && numeroPartecipantiAttivi <= 1) {
      return null;
    }
    return _trackManager.aggiungiPosizioneLeader(pos, ignoreTimeThreshold: ignoreTimeThreshold);
  }

  /// Esegue i cicli di Garbage Collection (GC) in base allo stato del GhostSnake.
  Map<String, int> eseguiGarbageCollection({
    required List<int> completedSequenceIds,
    required double distanzaMassimaGruppo,
    required bool codaInAreaNormal, // true se l'ultimo rider è rientrato nel buffer normale
  }) {
    // Se eravamo in Auto-Ghost (Emergenza) ma ora il gruppo è ricompattato,
    // torniamo automaticamente alla lunghezza normale.
    if (autoGhostActive && codaInAreaNormal) {
      autoGhostActive = false; 
    }

    double maxLen = (ghostSnake || autoGhostActive) ? distanzaMassimaGhost : distanzaMassimaGruppo;

    return _trackManager.garbageCollection(
      completedSequenceIds: (ghostSnake || autoGhostActive) ? const [] : completedSequenceIds,
      maxSnakeLength: maxLen,
    );
  }

  List<RoutePoint> ottieniRoutePoints() => _trackManager.ottieniRoutePoints();
  RoutePoint? ultimoRoutePoint() => _trackManager.ultimoRoutePoint();
  double lunghezzaPercorso() => _trackManager.lunghezzaPercorso();
  void reset() {
    _trackManager.reset();
    autoGhostActive = false;
  }

  /// Ripristina lo stato del motore da uno snapshot esistente (Recovery).
  void ripristinaStato(List<RoutePoint> punti, int ultimoSequenceId) {
    _trackManager.ripristinaStato(punti, ultimoSequenceId);
  }
}
