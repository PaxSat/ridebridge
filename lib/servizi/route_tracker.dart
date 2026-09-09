import '../modelli/evento_percorso.dart';

/// Servizio per il monitoraggio e la registrazione del tragitto del gruppo.
class RouteTracker {
  
  /// Aggiorna il riferimento della posizione del Leader per il calcolo del percorso.
  void aggiornaPosizioneLeader(double lat, double lon) {
    // Logica di tracciamento
  }

  /// Calcola l'angolo di direzione tra due punti (bearing).
  double calcolaBearing(double lat1, double lon1, double lat2, double lon2) {
    // Implementazione geometrica futura
    return 0.0;
  }

  /// Rileva se è stata effettuata una svolta significativa.
  TipoEventoPercorso? rilevaSvolta(double bearingPrecedente, double bearingAttuale) {
    return null;
  }

  /// Registra un punto di passaggio (waypoint) su Firestore.
  Future<void> registraWaypoint(String idGruppo, TipoEventoPercorso tipo, double lat, double lon) async {
    // Salvataggio evento percorso
  }
}
