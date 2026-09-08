import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta lo stato audio in tempo reale di un partecipante.
class StatoAudio {
  final bool connesso;
  final bool microfonoAttivo;
  final bool audioAttivo;
  final bool emergenzaAttiva;
  final bool prioritaAudio;
  final bool staParlando;
  final DateTime ultimoAggiornamento;

  StatoAudio({
    this.connesso = false,
    this.microfonoAttivo = false,
    this.audioAttivo = true,
    this.emergenzaAttiva = false,
    this.prioritaAudio = false,
    this.staParlando = false,
    required this.ultimoAggiornamento,
  });

  /// Crea un oggetto [StatoAudio] da una mappa Firestore.
  factory StatoAudio.daMappa(Map<String, dynamic> mappa) {
    return StatoAudio(
      connesso: mappa['connesso'] ?? false,
      microfonoAttivo: mappa['microfonoAttivo'] ?? false,
      audioAttivo: mappa['audioAttivo'] ?? true,
      emergenzaAttiva: mappa['emergenzaAttiva'] ?? false,
      prioritaAudio: mappa['prioritaAudio'] ?? false,
      staParlando: mappa['staParlando'] ?? false,
      ultimoAggiornamento: (mappa['ultimoAggiornamento'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converte l'oggetto [StatoAudio] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'connesso': connesso,
      'microfonoAttivo': microfonoAttivo,
      'audioAttivo': audioAttivo,
      'emergenzaAttiva': emergenzaAttiva,
      'prioritaAudio': prioritaAudio,
      'staParlando': staParlando,
      'ultimoAggiornamento': Timestamp.fromDate(ultimoAggiornamento),
    };
  }

  /// Crea una copia dello stato con alcuni campi modificati.
  StatoAudio copiaCon({
    bool? connesso,
    bool? microfonoAttivo,
    bool? audioAttivo,
    bool? emergenzaAttiva,
    bool? prioritaAudio,
    bool? staParlando,
    DateTime? ultimoAggiornamento,
  }) {
    return StatoAudio(
      connesso: connesso ?? this.connesso,
      microfonoAttivo: microfonoAttivo ?? this.microfonoAttivo,
      audioAttivo: audioAttivo ?? this.audioAttivo,
      emergenzaAttiva: emergenzaAttiva ?? this.emergenzaAttiva,
      prioritaAudio: prioritaAudio ?? this.prioritaAudio,
      staParlando: staParlando ?? this.staParlando,
      ultimoAggiornamento: ultimoAggiornamento ?? this.ultimoAggiornamento,
    );
  }
}
