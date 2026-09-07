/// Enum che definisce i ruoli possibili all'interno di un gruppo.
enum RuoloGruppo {
  leader,
  scopa,
  partecipante,
}

/// Modello che rappresenta un partecipante all'interno di un gruppo,
/// con i relativi permessi per il sistema audio e le segnalazioni.
class PartecipanteGruppo {
  final String idUtente;
  final RuoloGruppo ruolo;
  final bool microfonoConsentito;
  final bool audioConsentito;
  final bool emergenzaAbilitata;

  PartecipanteGruppo({
    required this.idUtente,
    required this.ruolo,
    this.microfonoConsentito = true,
    this.audioConsentito = true,
    this.emergenzaAbilitata = true,
  });

  /// Crea un oggetto [PartecipanteGruppo] da una mappa Firestore.
  factory PartecipanteGruppo.daMappa(Map<String, dynamic> mappa, String idUtente) {
    return PartecipanteGruppo(
      idUtente: idUtente,
      ruolo: RuoloGruppo.values.firstWhere(
        (e) => e.name == mappa['ruolo'],
        orElse: () => RuoloGruppo.partecipante,
      ),
      microfonoConsentito: mappa['microfonoConsentito'] ?? true,
      audioConsentito: mappa['audioConsentito'] ?? true,
      emergenzaAbilitata: mappa['emergenzaAbilitata'] ?? true,
    );
  }

  /// Converte l'oggetto [PartecipanteGruppo] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'ruolo': ruolo.name,
      'microfonoConsentito': microfonoConsentito,
      'audioConsentito': audioConsentito,
      'emergenzaAbilitata': emergenzaAbilitata,
    };
  }

  /// Crea una copia del partecipante con alcuni campi modificati.
  PartecipanteGruppo copiaCon({
    RuoloGruppo? ruolo,
    bool? microfonoConsentito,
    bool? audioConsentito,
    bool? emergenzaAbilitata,
  }) {
    return PartecipanteGruppo(
      idUtente: idUtente,
      ruolo: ruolo ?? this.ruolo,
      microfonoConsentito: microfonoConsentito ?? this.microfonoConsentito,
      audioConsentito: audioConsentito ?? this.audioConsentito,
      emergenzaAbilitata: emergenzaAbilitata ?? this.emergenzaAbilitata,
    );
  }
}
