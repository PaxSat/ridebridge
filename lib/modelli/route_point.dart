
/// Motivo per cui è stato generato un punto della traccia.
enum PointTriggerReason {
  time,     // Intervallo temporale raggiunto
  distance, // Distanza minima percorsa
  turn,     // Svolta rilevata
  manual,   // Forzato manualmente (es. avvio)
  unknown,
}

/// Direzione della svolta relativa al percorso.
enum PointTurnDirection {
  left,
  right,
}

/// Rappresenta un punto immutabile della traccia generata dal Leader.
class RoutePoint {
  final String id; // UUID tecnico
  final int sequenceId; // Identificativo topologico progressivo
  final double latitudine;
  final double longitudine;
  final DateTime timestamp;
  final double bearing;
  final double distanzaDalPrecedente;
  final double distanzaProgressiva;
  final PointTriggerReason triggerReason;
  final double? turnAngle; // Differenza relativa in gradi (+ destra, - sinistra)
  final PointTurnDirection? turnDirection; // null se non è una svolta

  RoutePoint({
    required this.id,
    required this.sequenceId,
    required this.latitudine,
    required this.longitudine,
    required this.timestamp,
    this.bearing = 0.0,
    this.distanzaDalPrecedente = 0.0,
    this.distanzaProgressiva = 0.0,
    this.triggerReason = PointTriggerReason.unknown,
    this.turnAngle,
    this.turnDirection,
  });

  /// Crea un oggetto [RoutePoint] da una mappa (es. Firestore).
  factory RoutePoint.daMappa(Map<String, dynamic> mappa, String documentoId) {
    DateTime convertiData(dynamic data) {
      if (data == null) return DateTime.now();
      if (data is DateTime) return data;
      try {
        return data.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    return RoutePoint(
      id: documentoId,
      sequenceId: mappa['sequenceId'] ?? 0,
      latitudine: (mappa['latitudine'] as num).toDouble(),
      longitudine: (mappa['longitudine'] as num).toDouble(),
      timestamp: convertiData(mappa['timestamp']),
      bearing: (mappa['bearing'] as num?)?.toDouble() ?? 0.0,
      distanzaDalPrecedente: (mappa['distanzaDalPrecedente'] as num?)?.toDouble() ?? 0.0,
      distanzaProgressiva: (mappa['distanzaProgressiva'] as num?)?.toDouble() ?? 0.0,
      triggerReason: PointTriggerReason.values.firstWhere(
        (e) => e.name == mappa['triggerReason'],
        orElse: () => PointTriggerReason.unknown,
      ),
      turnAngle: (mappa['turnAngle'] as num?)?.toDouble(),
      turnDirection: mappa['turnDirection'] != null
          ? PointTurnDirection.values.firstWhere((e) => e.name == mappa['turnDirection'])
          : null,
    );
  }

  /// Converte l'oggetto [RoutePoint] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'sequenceId': sequenceId,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'timestamp': timestamp,
      'bearing': bearing,
      'distanzaDalPrecedente': distanzaDalPrecedente,
      'distanzaProgressiva': distanzaProgressiva,
      'triggerReason': triggerReason.name,
      'turnAngle': turnAngle,
      'turnDirection': turnDirection?.name,
    };
  }

  /// Crea una copia del punto con alcuni campi modificati.
  RoutePoint copiaCon({
    String? id,
    int? sequenceId,
    double? latitudine,
    double? longitudine,
    DateTime? timestamp,
    double? bearing,
    double? distanzaDalPrecedente,
    double? distanzaProgressiva,
    PointTriggerReason? triggerReason,
    double? turnAngle,
    PointTurnDirection? turnDirection,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      sequenceId: sequenceId ?? this.sequenceId,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      timestamp: timestamp ?? this.timestamp,
      bearing: bearing ?? this.bearing,
      distanzaDalPrecedente: distanzaDalPrecedente ?? this.distanzaDalPrecedente,
      distanzaProgressiva: distanzaProgressiva ?? this.distanzaProgressiva,
      triggerReason: triggerReason ?? this.triggerReason,
      turnAngle: turnAngle ?? this.turnAngle,
      turnDirection: turnDirection ?? this.turnDirection,
    );
  }
}
