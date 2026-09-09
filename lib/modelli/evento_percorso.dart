import 'package:cloud_firestore/cloud_firestore.dart';

/// Definisce i tipi di eventi che possono verificarsi lungo il percorso.
enum TipoEventoPercorso {
  svoltaDestra,
  svoltaSinistra,
  rotatoria,
  inversione,
  sos,
}

/// Rappresenta un evento specifico registrato durante il tragitto del gruppo.
class EventoPercorso {
  final String idGruppo;
  final String idLeader;
  final TipoEventoPercorso tipoEvento;
  final double latitudine;
  final double longitudine;
  final DateTime timestamp;

  EventoPercorso({
    required this.idGruppo,
    required this.idLeader,
    required this.tipoEvento,
    required this.latitudine,
    required this.longitudine,
    required this.timestamp,
  });

  /// Crea un oggetto [EventoPercorso] da una mappa Firestore.
  factory EventoPercorso.daMappa(Map<String, dynamic> mappa) {
    return EventoPercorso(
      idGruppo: mappa['idGruppo'] ?? '',
      idLeader: mappa['idLeader'] ?? '',
      tipoEvento: TipoEventoPercorso.values.firstWhere(
        (e) => e.name == mappa['tipoEvento'],
        orElse: () => TipoEventoPercorso.sos,
      ),
      latitudine: (mappa['latitudine'] as num).toDouble(),
      longitudine: (mappa['longitudine'] as num).toDouble(),
      timestamp: (mappa['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converte l'oggetto [EventoPercorso] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'idGruppo': idGruppo,
      'idLeader': idLeader,
      'tipoEvento': tipoEvento.name,
      'latitudine': latitudine,
      'longitudine': longitudine,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Crea una copia dell'evento con alcuni campi modificati.
  EventoPercorso copiaCon({
    String? idGruppo,
    String? idLeader,
    TipoEventoPercorso? tipoEvento,
    double? latitudine,
    double? longitudine,
    DateTime? timestamp,
  }) {
    return EventoPercorso(
      idGruppo: idGruppo ?? this.idGruppo,
      idLeader: idLeader ?? this.idLeader,
      tipoEvento: tipoEvento ?? this.tipoEvento,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
