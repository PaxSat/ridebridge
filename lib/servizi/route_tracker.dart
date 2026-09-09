import '../modelli/evento_percorso.dart';
import 'location_evaluator.dart';

/// Servizio per il monitoraggio e la registrazione del tragitto del gruppo.
class RouteTracker {
  final _evaluator = LocationEvaluator();
  
  // Elenco dei waypoint (svolte) che la carovana deve ancora completare.
  final List<EventoPercorso> _waypointAttivi = [];
  double? _ultimoBearingLeader;

  List<EventoPercorso> get waypointAttivi => List.unmodifiable(_waypointAttivi);

  /// Processa la posizione del leader per rilevare nuove svolte.
  void processaPosizioneLeader({
    required String idGruppo,
    required String idLeader,
    required double lat,
    required double lon,
    required double bearingAttuale,
    required double turnThreshold,
  }) {
    if (_ultimoBearingLeader != null) {
      final tipoSvolta = rilevaSvolta(_ultimoBearingLeader!, bearingAttuale, turnThreshold);
      
      if (tipoSvolta != null) {
        final nuovoEvento = EventoPercorso(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          idGruppo: idGruppo,
          idLeader: idLeader,
          tipoEvento: tipoSvolta,
          latitudine: lat,
          longitudine: lon,
          timestamp: DateTime.now(),
        );
        _waypointAttivi.add(nuovoEvento);
      }
    }
    _ultimoBearingLeader = bearingAttuale;
  }

  /// Verifica se i waypoint attivi sono stati superati dall'ultimo membro (Scopa).
  /// Rimuove i waypoint passati.
  void aggiornaWaypointsPassati(double latScopa, double lonScopa, double sogliaDistanza) {
    _waypointAttivi.removeWhere((wp) {
      final distanza = _evaluator.distanzaTraDuePunti(latScopa, lonScopa, wp.latitudine, wp.longitudine);
      // Se la scopa è molto vicina o ha superato il punto (approssimazione)
      return distanza < sogliaDistanza;
    });
  }

  /// Calcola l'angolo di direzione tra due punti (bearing).
  double calcolaBearing(double lat1, double lon1, double lat2, double lon2) {
    return _evaluator.calcolaBearing(lat1, lon1, lat2, lon2);
  }

  /// Rileva se è stata effettuata una svolta significativa.
  TipoEventoPercorso? rilevaSvolta(double bearingPrecedente, double bearingAttuale, double turnThreshold) {
    double diff = (bearingAttuale - bearingPrecedente + 180 + 360) % 360 - 180;

    if (diff.abs() > 160) {
      return TipoEventoPercorso.inversione;
    } else if (diff > turnThreshold) {
      return TipoEventoPercorso.svoltaDestra;
    } else if (diff < -turnThreshold) {
      return TipoEventoPercorso.svoltaSinistra;
    }

    return null;
  }

  /// Pulisce lo stato (es. fine uscita).
  void reset() {
    _waypointAttivi.clear();
    _ultimoBearingLeader = null;
  }
}
