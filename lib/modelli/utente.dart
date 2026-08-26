import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta l'utente nel sistema RideBridge.
class Utente {
  final String id;
  final String nome;
  final String email;
  final String? fotoUrl;
  final DateTime? dataRegistrazione;
  final DateTime? ultimoAccesso;
  final bool attivo;
  final String? nickname;
  final String? moto;

  Utente({
    required this.id,
    required this.nome,
    required this.email,
    this.fotoUrl,
    this.dataRegistrazione,
    this.ultimoAccesso,
    this.attivo = true,
    this.nickname,
    this.moto,
  });

  /// Crea un oggetto [Utente] da una mappa Firestore.
  factory Utente.daMappa(Map<String, dynamic> mappa, String documentoId) {
    return Utente(
      id: documentoId,
      nome: mappa['nome'] ?? '',
      email: mappa['email'] ?? '',
      fotoUrl: mappa['fotoUrl'],
      dataRegistrazione: (mappa['dataRegistrazione'] as Timestamp?)?.toDate(),
      ultimoAccesso: (mappa['ultimoAccesso'] as Timestamp?)?.toDate(),
      attivo: mappa['attivo'] ?? false,
      nickname: mappa['nickname'],
      moto: mappa['moto'],
    );
  }

  /// Converte l'oggetto [Utente] in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'nome': nome,
      'email': email,
      'fotoUrl': fotoUrl,
      'dataRegistrazione': dataRegistrazione != null 
          ? Timestamp.fromDate(dataRegistrazione!) 
          : FieldValue.serverTimestamp(),
      'ultimoAccesso': ultimoAccesso != null 
          ? Timestamp.fromDate(ultimoAccesso!) 
          : FieldValue.serverTimestamp(),
      'attivo': attivo,
      'nickname': nickname,
      'moto': moto,
    };
  }

  /// Crea una copia dell'utente con alcuni campi modificati.
  Utente copiaCon({
    String? nome,
    String? fotoUrl,
    DateTime? ultimoAccesso,
    bool? attivo,
    String? nickname,
    String? moto,
  }) {
    return Utente(
      id: id,
      nome: nome ?? this.nome,
      email: email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      dataRegistrazione: dataRegistrazione,
      ultimoAccesso: ultimoAccesso ?? this.ultimoAccesso,
      attivo: attivo ?? this.attivo,
      nickname: nickname ?? this.nickname,
      moto: moto ?? this.moto,
    );
  }
}
