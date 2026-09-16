import 'dart:math' as math;

/// Servizio responsabile dell'analisi spaziale delle posizioni GPS per GeoRef V2.
/// Si occupa esclusivamente di calcoli geometrici atomici.
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

  /// Calcola la distanza minima tra un punto P e un segmento definito dai punti A e B.
  /// Ritorna la distanza in metri.
  double distanzaPuntoSegmento(
    double pLat, double pLon,
    double aLat, double aLon,
    double bLat, double bLon,
  ) {
    // 1. Calcoliamo la lunghezza del segmento (approssimazione piana locale per il fattore di proiezione)
    final dx = bLon - aLon;
    final dy = bLat - aLat;
    final l2 = dx * dx + dy * dy;

    if (l2 == 0) return distanzaTraDuePunti(pLat, pLon, aLat, aLon);

    // 2. Calcoliamo il fattore di proiezione t (clamped tra 0 e 1)
    // t = [(P-A) . (B-A)] / |B-A|^2
    var t = ((pLon - aLon) * dx + (pLat - aLat) * dy) / l2;
    t = math.max(0, math.min(1, t));

    // 3. Il punto più vicino C sul segmento è A + t*(B-A)
    final cLat = aLat + t * dy;
    final cLon = aLon + t * dx;

    // 4. Restituiamo la distanza reale (Haversine) tra P e il punto proiettato C
    return distanzaTraDuePunti(pLat, pLon, cLat, cLon);
  }
}
