import 'dart:math' as math;

/// Servizio responsabile dell'analisi spaziale delle posizioni GPS.
class LocationEvaluator {
  
  /// Calcola la distanza tra due punti GPS in metri usando la formula di Haversine.
  double distanzaTraDuePunti(double lat1, double lon1, double lat2, double lon2) {
    const raggioTerra = 6371000.0; // metri
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return raggioTerra * c;
  }

  /// Calcola la distanza di un utente dal Leader del gruppo.
  double distanzaDalLeader(double latUtente, double lonUtente, double latLeader, double lonLeader) {
    return distanzaTraDuePunti(latUtente, lonUtente, latLeader, lonLeader);
  }

  /// Calcola la distanza di un utente dalla Scopa del gruppo.
  double distanzaDallaScopa(double latUtente, double lonUtente, double latScopa, double lonScopa) {
    return distanzaTraDuePunti(latUtente, lonUtente, latScopa, lonScopa);
  }

  /// Verifica se un utente è uscito dal percorso stabilito (placeholder).
  bool eFuoriPercorso(double lat, double lon) {
    // Implementazione futura con polyline
    return false;
  }

  /// Verifica se un utente ha superato il Leader (placeholder).
  bool eAvantiAlLeader(double latUtente, double lonUtente, double latLeader, double lonLeader, double direzioneLeader) {
    return false;
  }

  /// Verifica se un utente è rimasto troppo indietro rispetto alla Scopa (placeholder).
  bool eDietroLaScopa(double latUtente, double lonUtente, double latScopa, double lonScopa, double direzioneScopa) {
    return false;
  }
}
