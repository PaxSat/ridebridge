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

  /// Calcola l'angolo di direzione (bearing) tra due punti (0-359 gradi).
  double calcolaBearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * math.pi / 180.0;
    final lat2Rad = lat2 * math.pi / 180.0;
    final deltaLon = (lon2 - lon1) * math.pi / 180.0;

    final y = math.sin(deltaLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
              math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLon);
    
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  /// Calcola la distanza di un utente dal Leader del gruppo.
  double distanzaDalLeader(double latUtente, double lonUtente, double latLeader, double lonLeader) {
    return distanzaTraDuePunti(latUtente, lonUtente, latLeader, lonLeader);
  }

  /// Calcola la distanza di un utente dalla Scopa del gruppo.
  double distanzaDallaScopa(double latUtente, double lonUtente, double latScopa, double lonScopa) {
    return distanzaTraDuePunti(latUtente, lonUtente, latScopa, lonScopa);
  }

  /// Verifica se un utente è uscito dal percorso stabilito (rispetto alla distanza dal leader/scopa o polyline).
  bool eFuoriPercorso(double distanzaDalPercorso, double soglia) {
    return distanzaDalPercorso > soglia;
  }

  /// Verifica se un utente ha superato il Leader.
  /// Utilizza il bearing tra leader e utente confrontato con la direzione del leader.
  bool eAvantiAlLeader(double latUtente, double lonUtente, double latLeader, double lonLeader, double direzioneLeader) {
    final bearingLeaderUtente = calcolaBearing(latLeader, lonLeader, latUtente, lonUtente);
    final diff = (bearingLeaderUtente - direzioneLeader + 180 + 360) % 360 - 180;
    // Se la differenza è tra -90 e 90 gradi, l'utente è "davanti" (nel semicerchio frontale)
    return diff.abs() < 90;
  }

  /// Verifica se un utente è rimasto troppo indietro rispetto alla Scopa.
  bool eDietroLaScopa(double latUtente, double lonUtente, double latScopa, double lonScopa, double direzioneScopa) {
    final bearingScopaUtente = calcolaBearing(latScopa, lonScopa, latUtente, lonUtente);
    final diff = (bearingScopaUtente - direzioneScopa + 180 + 360) % 360 - 180;
    // Se la differenza è maggiore di 90 o minore di -90, l'utente è "dietro"
    return diff.abs() > 90;
  }
}
