import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelli/utente.dart';

/// Gestisce le operazioni di persistenza su Cloud Firestore.
class ServizioDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Riferimento alla collezione degli utenti.
  CollectionReference get _utentiRef => _firestore.collection('utenti');

  /// Salva o aggiorna i dati dell'utente su Firestore.
  Future<void> salvaUtente(Utente utente) async {
    try {
      await _utentiRef.doc(utente.id).set(
        utente.aMappa(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Errore durante il salvataggio utente: $e');
      rethrow;
    }
  }

  /// Legge i dati di un utente specifico dal database.
  Future<Utente?> leggiUtente(String idUtente) async {
    try {
      DocumentSnapshot doc = await _utentiRef.doc(idUtente).get();
      if (doc.exists) {
        return Utente.daMappa(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Errore durante la lettura utente: $e');
      rethrow;
    }
  }

  /// Verifica se un utente esiste già nel database.
  Future<bool> esisteUtente(String idUtente) async {
    try {
      DocumentSnapshot doc = await _utentiRef.doc(idUtente).get();
      return doc.exists;
    } catch (e) {
      print('Errore verifica esistenza utente: $e');
      return false;
    }
  }

  /// Aggiorna solo l'ultimo accesso e lo stato attivo dell'utente.
  Future<void> aggiornaUltimoAccesso(String idUtente) async {
    try {
      await _utentiRef.doc(idUtente).update({
        'ultimoAccesso': FieldValue.serverTimestamp(),
        'attivo': true,
      });
    } catch (e) {
      print('Errore aggiornamento ultimo accesso: $e');
    }
  }
}
