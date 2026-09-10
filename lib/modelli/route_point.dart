import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta un punto immutabile della traccia generata dal Leader.
class RoutePoint {
  final String id;
  final double latitudine;
  final double longitudine;
  final DateTime timestamp;
  final double bearing;
  final double distanzaDalPrecedente;
  final double distanzaProgressiva;

  RoutePoint({
    required this.id,
    required this.latitudine,
    required this.longitudine,
    required this.timestamp,
    this.bearing = 0.0,
    this.distanzaDalPrecedente = 0.0,
    this.distanzaProgressiva = 0.0,
  });

  /// Crea un oggetto [RoutePoint] da una mappa (es. Firestore).
  factory RoutePoint.daMappa(Map<String, dynamic> mappa, String documentoId) {
    return RoutePoint(
      id: documentoId,
      latitudine: (mappa['latitudine'] as num).toDouble(),
      longitudine: (mappa['longitudine'] as num).toDouble(),
      timestamp: (mappa['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bearing: (mappa['bearing'] as num?)?.toDouble() ?? 0.0,
      distanzaDalPrecedente: (mappa['distanzaDalPrecedente'] as num?)?.toDouble() ?? 0.0,
      distanzaProgressiva: (mappa['distanzaProgressiva'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converte l'oggetto [RoutePoint] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'latitudine': latitudine,
      'longitudine': longitudine,
      'timestamp': Timestamp.fromDate(timestamp),
      'bearing': bearing,
      'distanzaDalPrecedente': distanzaDalPrecedente,
      'distanzaProgressiva': distanzaProgressiva,
    };
  }

  /// Crea una copia del punto con alcuni campi modificati.
  RoutePoint copiaCon({
    String? id,
    double? latitudine,
    double? longitudine,
    DateTime? timestamp,
    double? bearing,
    double? distanzaDalPrecedente,
    double? distanzaProgressiva,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      timestamp: timestamp ?? this.timestamp,
      bearing: bearing ?? this.bearing,
      distanzaDalPrecedente: distanzaDalPrecedente ?? this.distanzaDalPrecedente,
      distanzaProgressiva: distanzaProgressiva ?? this.distanzaProgressiva,
    );
  }
}
