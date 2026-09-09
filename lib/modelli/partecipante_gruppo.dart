import 'package:cloud_firestore/cloud_firestore.dart';
import 'stato_audio.dart';
import 'posizione_gps.dart';

/// Enum che definisce i ruoli possibili all'interno di un gruppo.
enum RuoloGruppo {
  leader,
  scopa,
  partecipante,
}

/// Modello che rappresenta un partecipante all'interno di un gruppo,
/// con i relativi permessi per il sistema audio e lo stato in tempo reale.
class PartecipanteGruppo {
  final String idUtente;
  final RuoloGruppo ruolo;
  final bool microfonoConsentito;
  final bool audioConsentito;
  final bool emergenzaAbilitata;
  final bool online;
  final DateTime? ultimoAccesso;
  final StatoAudio? statoAudio;
  final PosizioneGps? posizioneGps;

  PartecipanteGruppo({
    required this.idUtente,
    required this.ruolo,
    this.microfonoConsentito = true,
    this.audioConsentito = true,
    this.emergenzaAbilitata = true,
    this.online = false,
    this.ultimoAccesso,
    this.statoAudio,
    this.posizioneGps,
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
      online: mappa['online'] ?? false,
      ultimoAccesso: (mappa['ultimoAccesso'] as Timestamp?)?.toDate(),
      statoAudio: mappa['statoAudio'] != null 
          ? StatoAudio.daMappa(mappa['statoAudio'] as Map<String, dynamic>) 
          : null,
      posizioneGps: mappa['posizioneGps'] != null
          ? PosizioneGps.daMappa(mappa['posizioneGps'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converte l'oggetto [PartecipanteGruppo] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'ruolo': ruolo.name,
      'microfonoConsentito': microfonoConsentito,
      'audioConsentito': audioConsentito,
      'emergenzaAbilitata': emergenzaAbilitata,
      'online': online,
      'ultimoAccesso': ultimoAccesso != null ? Timestamp.fromDate(ultimoAccesso!) : null,
      'statoAudio': statoAudio?.aMappa(),
      'posizioneGps': posizioneGps?.aMappa(),
    };
  }

  /// Crea una copia del partecipante con alcuni campi modificati.
  PartecipanteGruppo copiaCon({
    RuoloGruppo? ruolo,
    bool? microfonoConsentito,
    bool? audioConsentito,
    bool? emergenzaAbilitata,
    bool? online,
    DateTime? ultimoAccesso,
    StatoAudio? statoAudio,
    PosizioneGps? posizioneGps,
  }) {
    return PartecipanteGruppo(
      idUtente: idUtente,
      ruolo: ruolo ?? this.ruolo,
      microfonoConsentito: microfonoConsentito ?? this.microfonoConsentito,
      audioConsentito: audioConsentito ?? this.audioConsentito,
      emergenzaAbilitata: emergenzaAbilitata ?? this.emergenzaAbilitata,
      online: online ?? this.online,
      ultimoAccesso: ultimoAccesso ?? this.ultimoAccesso,
      statoAudio: statoAudio ?? this.statoAudio,
      posizioneGps: posizioneGps ?? this.posizioneGps,
    );
  }
}
