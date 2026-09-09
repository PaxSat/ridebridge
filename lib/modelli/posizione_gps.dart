import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta la posizione geografica e i dati di movimento di un rider.
class PosizioneGps {
  final double latitudine;
  final double longitudine;
  final double altitudine;
  final double velocita; // in m/s (verrà convertita in km/h nella UI)
  final double direzione; // in gradi (0-359)
  final DateTime ultimoAggiornamento;

  PosizioneGps({
    required this.latitudine,
    required this.longitudine,
    this.altitudine = 0.0,
    this.velocita = 0.0,
    this.direzione = 0.0,
    required this.ultimoAggiornamento,
  });

  /// Crea un oggetto [PosizioneGps] da una mappa Firestore.
  factory PosizioneGps.daMappa(Map<String, dynamic> mappa) {
    return PosizioneGps(
      latitudine: (mappa['latitudine'] as num).toDouble(),
      longitudine: (mappa['longitudine'] as num).toDouble(),
      altitudine: (mappa['altitudine'] as num?)?.toDouble() ?? 0.0,
      velocita: (mappa['velocita'] as num?)?.toDouble() ?? 0.0,
      direzione: (mappa['direzione'] as num?)?.toDouble() ?? 0.0,
      ultimoAggiornamento: (mappa['ultimoAggiornamento'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converte l'oggetto [PosizioneGps] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'latitudine': latitudine,
      'longitudine': longitudine,
      'altitudine': altitudine,
      'velocita': velocita,
      'direzione': direzione,
      'ultimoAggiornamento': Timestamp.fromDate(ultimoAggiornamento),
    };
  }

  /// Crea una copia della posizione con alcuni campi modificati.
  PosizioneGps copiaCon({
    double? latitudine,
    double? longitudine,
    double? altitudine,
    double? velocita,
    double? direzione,
    DateTime? ultimoAggiornamento,
  }) {
    return PosizioneGps(
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      altitudine: altitudine ?? this.altitudine,
      velocita: velocita ?? this.velocita,
      direzione: direzione ?? this.direzione,
      ultimoAggiornamento: ultimoAggiornamento ?? this.ultimoAggiornamento,
    );
  }
}
