/// Rappresenta la configurazione e lo stato della carovana di motociclisti.
class FormazioneGruppo {
  final String idLeader;
  final String idScopa;
  final double distanzaMassimaGruppo; // metri tra leader e ultimo membro
  final double distanzaMassimaScopa; // metri tra leader e scopa
  final bool gruppoCompatto;

  FormazioneGruppo({
    required this.idLeader,
    required this.idScopa,
    this.distanzaMassimaGruppo = 500.0,
    this.distanzaMassimaScopa = 1000.0,
    this.gruppoCompatto = true,
  });

  /// Crea un oggetto [FormazioneGruppo] da una mappa Firestore.
  factory FormazioneGruppo.daMappa(Map<String, dynamic> mappa) {
    return FormazioneGruppo(
      idLeader: mappa['idLeader'] ?? '',
      idScopa: mappa['idScopa'] ?? '',
      distanzaMassimaGruppo: (mappa['distanzaMassimaGruppo'] as num?)?.toDouble() ?? 500.0,
      distanzaMassimaScopa: (mappa['distanzaMassimaScopa'] as num?)?.toDouble() ?? 1000.0,
      gruppoCompatto: mappa['gruppoCompatto'] ?? true,
    );
  }

  /// Converte l'oggetto [FormazioneGruppo] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'idLeader': idLeader,
      'idScopa': idScopa,
      'distanzaMassimaGruppo': distanzaMassimaGruppo,
      'distanzaMassimaScopa': distanzaMassimaScopa,
      'gruppoCompatto': gruppoCompatto,
    };
  }

  /// Crea una copia della formazione con alcuni campi modificati.
  FormazioneGruppo copiaCon({
    String? idLeader,
    String? idScopa,
    double? distanzaMassimaGruppo,
    double? distanzaMassimaScopa,
    bool? gruppoCompatto,
  }) {
    return FormazioneGruppo(
      idLeader: idLeader ?? this.idLeader,
      idScopa: idScopa ?? this.idScopa,
      distanzaMassimaGruppo: distanzaMassimaGruppo ?? this.distanzaMassimaGruppo,
      distanzaMassimaScopa: distanzaMassimaScopa ?? this.distanzaMassimaScopa,
      gruppoCompatto: gruppoCompatto ?? this.gruppoCompatto,
    );
  }
}
