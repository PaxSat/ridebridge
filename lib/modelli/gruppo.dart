import 'configurazione_gruppo.dart';

/// Modello che rappresenta un gruppo di motociclisti.
class Gruppo {
  final String id;
  final String nome;
  final String codiceAccesso;
  final String idCreatore;
  final DateTime dataCreazione;
  final bool attivo;
  final List<String> idPartecipanti;
  final ConfigurazioneGruppo configurazione;

  Gruppo({
    required this.id,
    required this.nome,
    required this.codiceAccesso,
    required this.idCreatore,
    required this.dataCreazione,
    this.attivo = true,
    this.idPartecipanti = const [],
    ConfigurazioneGruppo? configurazione,
  }) : configurazione = configurazione ?? ConfigurazioneGruppo();

  /// Crea un oggetto [Gruppo] da una mappa Firestore.
  factory Gruppo.daMappa(Map<String, dynamic> mappa, String documentoId) {
    DateTime convertiData(dynamic data) {
      if (data is DateTime) return data;
      try {
        return data.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    return Gruppo(
      id: documentoId,
      nome: mappa['nome'] ?? '',
      codiceAccesso: mappa['codiceAccesso'] ?? '',
      idCreatore: mappa['idCreatore'] ?? '',
      dataCreazione: convertiData(mappa['dataCreazione']),
      attivo: mappa['attivo'] ?? true,
      idPartecipanti: List<String>.from(mappa['partecipanti'] ?? []),
      configurazione: mappa['configurazione'] != null
          ? ConfigurazioneGruppo.daMappa(mappa['configurazione'] as Map<String, dynamic>)
          : ConfigurazioneGruppo(),
    );
  }

  /// Converte l'oggetto [Gruppo] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'nome': nome,
      'codiceAccesso': codiceAccesso,
      'idCreatore': idCreatore,
      'dataCreazione': dataCreazione,
      'attivo': attivo,
      'partecipanti': idPartecipanti,
      'configurazione': configurazione.aMappa(),
    };
  }

  /// Crea una copia del gruppo con alcuni campi modificati.
  Gruppo copiaCon({
    String? nome,
    String? codiceAccesso,
    String? idCreatore,
    DateTime? dataCreazione,
    bool? attivo,
    ConfigurazioneGruppo? configurazione,
  }) {
    return Gruppo(
      id: id,
      nome: nome ?? this.nome,
      codiceAccesso: codiceAccesso ?? this.codiceAccesso,
      idCreatore: idCreatore ?? this.idCreatore,
      dataCreazione: dataCreazione ?? this.dataCreazione,
      attivo: attivo ?? this.attivo,
      configurazione: configurazione ?? this.configurazione,
    );
  }
}
