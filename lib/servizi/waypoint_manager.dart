import '../modelli/route_point.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/engine_state.dart';
import '../modelli/configurazione_gruppo.dart';
import 'location_evaluator.dart';
import 'package:collection/collection.dart';

/// Gestore delle istruzioni di navigazione basato sullo Snake (GeoRef V3).
/// Implementa l'Instruction Resolver con logica di priorità.
class WaypointManager {
  final _evaluator = LocationEvaluator();

  /// Restituisce l'istruzione di navigazione "smart" basata sulla priorità degli eventi.
  String? ottieniIstruzioneSmart({
    required PosizioneGps posAttuale,
    required List<RoutePoint> traccia,
    required int lastValidatedIdx,
    required ConfigurazioneGruppo config,
    required EngineState engineState,
  }) {
    if (engineState == EngineState.offRoute || traccia.isEmpty) return null;

    // 1. Identifichiamo i punti davanti all'utente (dall'ultimo validato in poi)
    final puntiDavanti = traccia.where((p) => p.sequenceId > lastValidatedIdx).toList();
    if (puntiDavanti.isEmpty) return null;

    // 2. CERCA SVOLTA PRIORITARIA (entro la finestra di anticipo)
    final prossimaSvolta = puntiDavanti.firstWhereOrNull((p) {
      if (p.turnDirection == null) return false;
      final dist = _evaluator.distanzaTraDuePunti(posAttuale.latitudine, posAttuale.longitudine, p.latitudine, p.longitudine);
      return dist <= config.turnInstructionDistance;
    });

    if (prossimaSvolta != null) {
      final dist = _evaluator.distanzaTraDuePunti(posAttuale.latitudine, posAttuale.longitudine, prossimaSvolta.latitudine, prossimaSvolta.longitudine);
      final dirLabel = prossimaSvolta.turnDirection == PointTurnDirection.left ? "SINISTRA" : "DESTRA";
      
      if (dist < 15) return "SVOLTA ORA A $dirLabel";
      if (dist < (config.turnInstructionDistance / 2)) {
        return "Tra ${dist.round()}m SVOLTA A $dirLabel";
      }
      return "Preparati a svoltare a $dirLabel";
    }

    // 3. CERCA PROSSIMO PUNTO DISTANZA (D)
    final prossimoD = puntiDavanti.firstWhereOrNull((p) => p.triggerReason == PointTriggerReason.distance);
    if (prossimoD != null) {
      final dist = _evaluator.distanzaTraDuePunti(posAttuale.latitudine, posAttuale.longitudine, prossimoD.latitudine, prossimoD.longitudine);
      if (dist <= config.triggerDistanceMeters) {
        if (dist < 15) return "Passaggio Punto D";
        return "Tra ${dist.round()}m Punto D";
      }
    }

    // 4. FALLBACK: Prossimo punto generico
    final prossimoQualsiasi = puntiDavanti.first;
    final dist = _evaluator.distanzaTraDuePunti(posAttuale.latitudine, posAttuale.longitudine, prossimoQualsiasi.latitudine, prossimoQualsiasi.longitudine);
    if (dist <= config.triggerDistanceMeters) {
      final typeLabel = prossimoQualsiasi.triggerReason == PointTriggerReason.time ? "T" : "M";
      if (dist < 10) return "Passaggio Punto $typeLabel";
      return "Tra ${dist.round()}m Punto $typeLabel";
    }

    return null;
  }

  /// Metodo legacy per retrocompatibilità (verrà rimosso dopo migrazione UI)
  String? ottieniIstruzioneNavigazione(
    PosizioneGps posAttuale,
    RoutePoint? targetPoint,
    double triggerDistance,
    EngineState engineState,
  ) {
    if (engineState == EngineState.offRoute || targetPoint == null) return null;

    final distanza = _evaluator.distanzaTraDuePunti(
      posAttuale.latitudine, posAttuale.longitudine,
      targetPoint.latitudine, targetPoint.longitudine,
    );

    if (distanza < triggerDistance) {
      return "Tra ${distanza.round()}m prossimo punto";
    }
    return null;
  }
}
