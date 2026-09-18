/// Rappresenta la configurazione tecnica del gruppo per il tracciamento GPS e la navigazione.
class ConfigurazioneGruppo {
  final double turnThresholdAngle; // Angolo minimo per rilevare una svolta
  final double triggerDistanceMeters; // Distanza minima per registrare un waypoint
  final double distanzaMassimaGruppo; // Soglia per stato carovana non compatta
  final double distanzaMassimaScopa; // Soglia per perdita della scopa
  final double offRouteThreshold; // Distanza massima dalla polyline prima di OFF_ROUTE
  final double snakeDistanceMeters; // Distanza minima tra punti Snake
  final double snakeTimeSeconds; // Tempo minimo tra punti Snake
  final double distanzaMassimaGhost; // Lunghezza massima dello Snake in modalità Ghost
  final double minTurnDistance; // Distanza minima per triggerare una svolta
  final double validationRadius; // Raggio di aggancio ai punti dello Snake
  final double reliabilityTimeoutSeconds; // Tempo dopo il quale un rider è considerato offline

  ConfigurazioneGruppo({
    this.turnThresholdAngle = 35.0,
    this.triggerDistanceMeters = 100.0,
    this.distanzaMassimaGruppo = 1500.0,
    this.distanzaMassimaScopa = 2000.0,
    this.offRouteThreshold = 150.0,
    this.snakeDistanceMeters = 50.0,
    this.snakeTimeSeconds = 15.0,
    this.distanzaMassimaGhost = 15000.0,
    this.minTurnDistance = 15.0,
    this.validationRadius = 35.0,
    this.reliabilityTimeoutSeconds = 30.0,
  });

  /// Preset per carovana turistica (Bilanciato).
  factory ConfigurazioneGruppo.touring() => ConfigurazioneGruppo();

  /// Preset per guida sportiva (Soglie incrementate per velocità elevate e distanziamento).
  factory ConfigurazioneGruppo.sportivo() {
    return ConfigurazioneGruppo(
      turnThresholdAngle: 45.0,
      triggerDistanceMeters: 250.0,
      distanzaMassimaGruppo: 3000.0,
      distanzaMassimaScopa: 5000.0,
      offRouteThreshold: 300.0,
    );
  }

  /// Preset per guida fuoristrada (Soglie diminuite per massima precisione tecnica).
  factory ConfigurazioneGruppo.offroad() {
    return ConfigurazioneGruppo(
      turnThresholdAngle: 15.0,
      triggerDistanceMeters: 25.0,
      distanzaMassimaGruppo: 300.0,
      distanzaMassimaScopa: 600.0,
      offRouteThreshold: 40.0,
    );
  }

  /// Crea un oggetto [ConfigurazioneGruppo] da una mappa Firestore.
  factory ConfigurazioneGruppo.daMappa(Map<String, dynamic> mappa) {
    return ConfigurazioneGruppo(
      turnThresholdAngle: (mappa['turnThresholdAngle'] as num?)?.toDouble() ?? 35.0,
      triggerDistanceMeters: (mappa['triggerDistanceMeters'] as num?)?.toDouble() ?? 100.0,
      distanzaMassimaGruppo: (mappa['distanzaMassimaGruppo'] as num?)?.toDouble() ?? 1500.0,
      distanzaMassimaScopa: (mappa['distanzaMassimaScopa'] as num?)?.toDouble() ?? 2000.0,
      offRouteThreshold: (mappa['offRouteThreshold'] as num?)?.toDouble() ?? 150.0,
      snakeDistanceMeters: (mappa['snakeDistanceMeters'] as num?)?.toDouble() ?? 50.0,
      snakeTimeSeconds: (mappa['snakeTimeSeconds'] as num?)?.toDouble() ?? 15.0,
      distanzaMassimaGhost: (mappa['distanzaMassimaGhost'] as num?)?.toDouble() ?? 15000.0,
      minTurnDistance: (mappa['minTurnDistance'] as num?)?.toDouble() ?? 15.0,
      validationRadius: (mappa['validationRadius'] as num?)?.toDouble() ?? 35.0,
      reliabilityTimeoutSeconds: (mappa['reliabilityTimeoutSeconds'] as num?)?.toDouble() ?? 30.0,
    );
  }

  /// Converte l'oggetto [ConfigurazioneGruppo] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'turnThresholdAngle': turnThresholdAngle,
      'triggerDistanceMeters': triggerDistanceMeters,
      'distanzaMassimaGruppo': distanzaMassimaGruppo,
      'distanzaMassimaScopa': distanzaMassimaScopa,
      'offRouteThreshold': offRouteThreshold,
      'snakeDistanceMeters': snakeDistanceMeters,
      'snakeTimeSeconds': snakeTimeSeconds,
      'distanzaMassimaGhost': distanzaMassimaGhost,
      'minTurnDistance': minTurnDistance,
      'validationRadius': validationRadius,
      'reliabilityTimeoutSeconds': reliabilityTimeoutSeconds,
    };
  }

  /// Crea una copia della configurazione con alcuni campi modificati.
  ConfigurazioneGruppo copiaCon({
    double? turnThresholdAngle,
    double? triggerDistanceMeters,
    double? distanzaMassimaGruppo,
    double? distanzaMassimaScopa,
    double? offRouteThreshold,
    double? snakeDistanceMeters,
    double? snakeTimeSeconds,
    double? distanzaMassimaGhost,
    double? minTurnDistance,
    double? validationRadius,
    double? reliabilityTimeoutSeconds,
  }) {
    return ConfigurazioneGruppo(
      turnThresholdAngle: turnThresholdAngle ?? this.turnThresholdAngle,
      triggerDistanceMeters: triggerDistanceMeters ?? this.triggerDistanceMeters,
      distanzaMassimaGruppo: distanzaMassimaGruppo ?? this.distanzaMassimaGruppo,
      distanzaMassimaScopa: distanzaMassimaScopa ?? this.distanzaMassimaScopa,
      offRouteThreshold: offRouteThreshold ?? this.offRouteThreshold,
      snakeDistanceMeters: snakeDistanceMeters ?? this.snakeDistanceMeters,
      snakeTimeSeconds: snakeTimeSeconds ?? this.snakeTimeSeconds,
      distanzaMassimaGhost: distanzaMassimaGhost ?? this.distanzaMassimaGhost,
      minTurnDistance: minTurnDistance ?? this.minTurnDistance,
      validationRadius: validationRadius ?? this.validationRadius,
      reliabilityTimeoutSeconds: reliabilityTimeoutSeconds ?? this.reliabilityTimeoutSeconds,
    );
  }
}
