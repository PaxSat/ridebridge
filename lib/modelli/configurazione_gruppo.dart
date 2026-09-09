/// Rappresenta la configurazione tecnica del gruppo per il tracciamento GPS e la navigazione.
/// Valori ottimizzati per una carovana motociclistica turistica.
/// 
/// TODO: Implementare preset futuri:
/// - Touring (Valori attuali)
/// - Sport (Soglie più strette)
/// - Offroad (Tracciamento più frequente)
class ConfigurazioneGruppo {
  final double turnThresholdAngle; // Angolo minimo per rilevare una svolta
  final double triggerDistanceMeters; // Distanza minima per registrare un waypoint
  final double distanzaMassimaGruppo; // Soglia per stato carovana non compatta
  final double distanzaMassimaScopa; // Soglia per perdita della scopa
  final double offRouteThreshold; // Distanza massima dalla polyline prima di OFF_ROUTE

  ConfigurazioneGruppo({
    this.turnThresholdAngle = 35.0,
    this.triggerDistanceMeters = 100.0,
    this.distanzaMassimaGruppo = 1500.0,
    this.distanzaMassimaScopa = 2000.0,
    this.offRouteThreshold = 150.0,
  });

  /// Crea un oggetto [ConfigurazioneGruppo] da una mappa Firestore.
  factory ConfigurazioneGruppo.daMappa(Map<String, dynamic> mappa) {
    return ConfigurazioneGruppo(
      turnThresholdAngle: (mappa['turnThresholdAngle'] as num?)?.toDouble() ?? 35.0,
      triggerDistanceMeters: (mappa['triggerDistanceMeters'] as num?)?.toDouble() ?? 100.0,
      distanzaMassimaGruppo: (mappa['distanzaMassimaGruppo'] as num?)?.toDouble() ?? 1500.0,
      distanzaMassimaScopa: (mappa['distanzaMassimaScopa'] as num?)?.toDouble() ?? 2000.0,
      offRouteThreshold: (mappa['offRouteThreshold'] as num?)?.toDouble() ?? 150.0,
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
    };
  }

  /// Crea una copia della configurazione con alcuni campi modificati.
  ConfigurazioneGruppo copiaCon({
    double? turnThresholdAngle,
    double? triggerDistanceMeters,
    double? distanzaMassimaGruppo,
    double? distanzaMassimaScopa,
    double? offRouteThreshold,
  }) {
    return ConfigurazioneGruppo(
      turnThresholdAngle: turnThresholdAngle ?? this.turnThresholdAngle,
      triggerDistanceMeters: triggerDistanceMeters ?? this.triggerDistanceMeters,
      distanzaMassimaGruppo: distanzaMassimaGruppo ?? this.distanzaMassimaGruppo,
      distanzaMassimaScopa: distanzaMassimaScopa ?? this.distanzaMassimaScopa,
      offRouteThreshold: offRouteThreshold ?? this.offRouteThreshold,
    );
  }
}
