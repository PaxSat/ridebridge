import 'package:cloud_firestore/cloud_firestore.dart';

/// Modello che rappresenta un gruppo di motociclisti.
class Gruppo {
  final String id;
  final String nome;
  final String codiceAccesso;
  final String idCreatore;
  final DateTime dataCreazione;
  final bool attivo;

  Gruppo({
    required this.id,
    required this.nome,
    required this.codiceAccesso,
    required this.idCreatore,
    required this.dataCreazione,
    this.attivo = true,
  });

  /// Crea un oggetto [Gruppo] da una mappa Firestore.
  factory Gruppo.daMappa(Map<String, dynamic> mappa, String documentoId) {
    return Gruppo(
      id: documentoId,
      nome: mappa['nome'] ?? '',
      codiceAccesso: mappa['codiceAccesso'] ?? '',
      idCreatore: mappa['idCreatore'] ?? '',
      dataCreazione: (mappa['dataCreazione'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attivo: mappa['attivo'] ?? true,
    );
  }

  /// Converte l'oggetto [Gruppo] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'nome': nome,
      'codiceAccesso': codiceAccesso,
      'idCreatore': idCreatore,
      'dataCreazione': Timestamp.fromDate(dataCreazione),
      'attivo': attivo,
    };
  }

  /// Crea una copia del gruppo con alcuni campi modificati.
  Gruppo copiaCon({
    String? nome,
    String? codiceAccesso,
    String? idCreatore,
    DateTime? dataCreazione,
    bool? attivo,
  }) {
    return Gruppo(
      id: id,
      nome: nome ?? this.nome,
      codiceAccesso: codiceAccesso ?? this.codiceAccesso,
      idCreatore: idCreatore ?? this.idCreatore,
      dataCreazione: dataCreazione ?? this.dataCreazione,
      attivo: attivo ?? this.attivo,
    );
  }
}
