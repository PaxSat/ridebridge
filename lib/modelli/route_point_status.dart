import 'package:cloud_firestore/cloud_firestore.dart';

/// Definisce gli stati del ciclo di vita di un punto della traccia per la carovana.
enum RoutePointLifecycle {
  active,             // Punto appena creato, obiettivo per i partecipanti
  completed,          // Superato da tutti i membri della carovana
  eligibleForRemoval, // Completato e superato anche dal buffer di sicurezza
}

/// Rappresenta lo stato dinamico di un [RoutePoint].
class RoutePointStatus {
  final String routePointId; // UUID tecnico
  final int sequenceId; // Riferimento topologico primario
  final Map<String, DateTime> passaggiUtenti; // Mappa UID -> Timestamp passaggio
  final RoutePointLifecycle lifecycle;

  RoutePointStatus({
    required this.routePointId,
    required this.sequenceId,
    this.passaggiUtenti = const {},
    this.lifecycle = RoutePointLifecycle.active,
  });

  /// Verifica se un insieme di utenti ha superato il punto.
  bool sonoTuttiPassati(List<String> activeUids) {
    if (activeUids.isEmpty) return false;
    return activeUids.every((uid) => passaggiUtenti.containsKey(uid));
  }

  /// Crea un oggetto [RoutePointStatus] da una mappa.
  factory RoutePointStatus.daMappa(Map<String, dynamic> mappa) {
    final passaggiMappa = mappa['passaggiUtenti'] as Map<String, dynamic>? ?? {};
    final passaggiConvertiti = passaggiMappa.map(
      (key, value) => MapEntry(key, (value as Timestamp).toDate()),
    );

    return RoutePointStatus(
      routePointId: mappa['routePointId'] ?? '',
      sequenceId: mappa['sequenceId'] ?? 0,
      passaggiUtenti: passaggiConvertiti,
      lifecycle: RoutePointLifecycle.values.firstWhere(
        (e) => e.name == mappa['lifecycle'],
        orElse: () => RoutePointLifecycle.active,
      ),
    );
  }

  /// Converte l'oggetto [RoutePointStatus] in una mappa.
  Map<String, dynamic> aMappa() {
    final passaggiFirestore = passaggiUtenti.map(
      (key, value) => MapEntry(key, Timestamp.fromDate(value)),
    );

    return {
      'routePointId': routePointId,
      'sequenceId': sequenceId,
      'passaggiUtenti': passaggiFirestore,
      'lifecycle': lifecycle.name,
    };
  }

  /// Crea una copia dello stato con campi modificati.
  RoutePointStatus copiaCon({
    String? routePointId,
    int? sequenceId,
    Map<String, DateTime>? passaggiUtenti,
    RoutePointLifecycle? lifecycle,
  }) {
    return RoutePointStatus(
      routePointId: routePointId ?? this.routePointId,
      sequenceId: sequenceId ?? this.sequenceId,
      passaggiUtenti: passaggiUtenti ?? this.passaggiUtenti,
      lifecycle: lifecycle ?? this.lifecycle,
    );
  }
}
