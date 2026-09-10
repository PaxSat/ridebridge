import '../modelli/route_point.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/engine_state.dart';
import 'location_evaluator.dart';

/// Gestore delle istruzioni di navigazione basato sullo Snake (GeoRef V2).
class WaypointManager {
  final _evaluator = LocationEvaluator();

  /// Restituisce l'istruzione di navigazione per il prossimo punto target.
  /// Implementa 3 livelli di avviso.
  String? ottieniIstruzioneNavigazione(
    PosizioneGps posAttuale,
    RoutePoint? targetPoint,
    double triggerDistance,
    EngineState engineState,
  ) {
    // REGOLE DI DISABILITAZIONE
    if (engineState == EngineState.offRoute || targetPoint == null) {
      return null;
    }

    final distanza = _evaluator.distanzaTraDuePunti(
      posAttuale.latitudine,
      posAttuale.longitudine,
      targetPoint.latitudine,
      targetPoint.longitudine,
    );

    // Identificazione direzione (Semplificata, in futuro basata su eventi semantici)
    // Per ora usiamo il bearing del punto come suggerimento se implementato
    String direzione = "prossimo punto";

    // LIVELLO 3: Svolta (15 metri)
    if (distanza < 15) {
      return "Passaggio a $direzione";
    }
    // LIVELLO 2: Preparazione (40 metri)
    else if (distanza < 40) {
      return "Preparati al $direzione";
    }
    // LIVELLO 1: Pre-avviso (triggerDistanceConfig)
    else if (distanza < triggerDistance) {
      return "Tra ${distanza.round()} metri $direzione";
    }

    return null;
  }
}
