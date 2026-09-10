import 'package:cloud_firestore/cloud_firestore.dart';

/// Definisce gli stati del ciclo di vita di un punto della traccia per la carovana.
enum RoutePointLifecycle {
  active,             // Punto appena creato, obiettivo per i partecipanti
  completed,          // Superato da tutti i membri della carovana
  eligibleForRemoval, // Completato e superato anche dal buffer di sicurezza
}

/// Rappresenta lo stato dinamico di un [RoutePoint].
class RoutePointStatus {
  final String routePointId;
  final Set<String> utentiPassati;
  final Map<String, DateTime> passaggiUtenti; // Mappa UID -> Timestamp passaggio
  final bool tuttiPassati;
  final DateTime? timestampUltimoPassaggio;
  final RoutePointLifecycle lifecycle;

  RoutePointStatus({
    required this.routePointId,
    this.utentiPassati = const {},
    this.passaggiUtenti = const {},
    this.tuttiPassati = false,
    this.timestampUltimoPassaggio,
    this.lifecycle = RoutePointLifecycle.active,
  });

  /// Crea un oggetto [RoutePointStatus] da una mappa.
  factory RoutePointStatus.daMappa(Map<String, dynamic> mappa) {
    final passaggiMappa = mappa['passaggiUtenti'] as Map<String, dynamic>? ?? {};
    final passaggiConvertiti = passaggiMappa.map(
      (key, value) => MapEntry(key, (value as Timestamp).toDate()),
    );

    return RoutePointStatus(
      routePointId: mappa['routePointId'] ?? '',
      utentiPassati: Set<String>.from(mappa['utentiPassati'] ?? []),
      passaggiUtenti: passaggiConvertiti,
      tuttiPassati: mappa['tuttiPassati'] ?? false,
      timestampUltimoPassaggio: (mappa['timestampUltimoPassaggio'] as Timestamp?)?.toDate(),
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
      'utentiPassati': utentiPassati.toList(),
      'passaggiUtenti': passaggiFirestore,
      'tuttiPassati': tuttiPassati,
      'timestampUltimoPassaggio': timestampUltimoPassaggio != null 
          ? Timestamp.fromDate(timestampUltimoPassaggio!) 
          : null,
      'lifecycle': lifecycle.name,
    };
  }

  /// Crea una copia dello stato con campi modificati.
  RoutePointStatus copiaCon({
    String? routePointId,
    Set<String>? utentiPassati,
    Map<String, DateTime>? passaggiUtenti,
    bool? tuttiPassati,
    DateTime? timestampUltimoPassaggio,
    RoutePointLifecycle? lifecycle,
  }) {
    return RoutePointStatus(
      routePointId: routePointId ?? this.routePointId,
      utentiPassati: utentiPassati ?? this.utentiPassati,
      passaggiUtenti: passaggiUtenti ?? this.passaggiUtenti,
      tuttiPassati: tuttiPassati ?? this.tuttiPassati,
      timestampUltimoPassaggio: timestampUltimoPassaggio ?? this.timestampUltimoPassaggio,
      lifecycle: lifecycle ?? this.lifecycle,
    );
  }
}
