import 'posizione_gps.dart';

/// Rappresenta i dati dinamici trasmessi in streaming da un rider durante il tour.
/// Questi dati sono volatili e separati dalle informazioni anagrafiche del gruppo.
class RiderStreamData {
  final String uid;
  final PosizioneGps posizioneGps;
  final int? lastValidatedIndex;
  final DateTime timestamp;

  RiderStreamData({
    required this.uid,
    required this.posizioneGps,
    this.lastValidatedIndex,
    required this.timestamp,
  });

  /// Crea un oggetto da una mappa (standard Dart).
  factory RiderStreamData.daMappa(Map<String, dynamic> mappa, String uid) {
    return RiderStreamData(
      uid: uid,
      posizioneGps: PosizioneGps.daMappa(mappa['posizioneGps'] as Map<String, dynamic>),
      lastValidatedIndex: mappa['lastValidatedIndex'] as int?,
      timestamp: mappa['timestamp'] as DateTime? ?? DateTime.now(),
    );
  }

  /// Converte l'oggetto in una mappa (standard Dart).
  Map<String, dynamic> aMappa() {
    return {
      'posizioneGps': posizioneGps.aMappa(),
      'lastValidatedIndex': lastValidatedIndex,
      'timestamp': timestamp,
    };
  }

  /// Crea una copia con campi modificati.
  RiderStreamData copiaCon({
    String? uid,
    PosizioneGps? posizioneGps,
    int? lastValidatedIndex,
    DateTime? timestamp,
  }) {
    return RiderStreamData(
      uid: uid ?? this.uid,
      posizioneGps: posizioneGps ?? this.posizioneGps,
      lastValidatedIndex: lastValidatedIndex ?? this.lastValidatedIndex,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
