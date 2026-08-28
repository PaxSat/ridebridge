import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelli/gruppo.dart';

/// Gestisce le operazioni relative ai gruppi su Cloud Firestore.
class ServizioGruppi {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Riferimento alla collezione dei gruppi.
  CollectionReference get _gruppiRef => _firestore.collection('gruppi');

  /// Genera un codice alfanumerico casuale di 6 caratteri.
  String _generaCodice() {
    const caratteri = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => caratteri.codeUnitAt(random.nextInt(caratteri.length)),
      ),
    );
  }

  /// Crea un nuovo gruppo su Firestore e restituisce il codice di accesso generato.
  Future<String> creaGruppo(String nome, String idCreatore) async {
    try {
      final codice = _generaCodice();
      
      await _gruppiRef.add({
        'nome': nome,
        'codiceAccesso': codice,
        'idCreatore': idCreatore,
        'dataCreazione': FieldValue.serverTimestamp(),
        'attivo': true,
        'partecipanti': [idCreatore],
      });

      return codice;
    } catch (e) {
      print('Errore durante la creazione del gruppo: $e');
      rethrow;
    }
  }

  /// Permette a un utente di entrare in un gruppo tramite codice di accesso.
  Future<void> entraNelGruppo(String codiceAccesso, String idUtente) async {
    try {
      final query = await _gruppiRef
          .where('codiceAccesso', isEqualTo: codiceAccesso.toUpperCase())
          .where('attivo', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Codice gruppo non valido o gruppo non attivo.');
      }

      final doc = query.docs.first;
      
      await _gruppiRef.doc(doc.id).update({
        'partecipanti': FieldValue.arrayUnion([idUtente])
      });
    } catch (e) {
      print('Errore durante l\'ingresso nel gruppo: $e');
      rethrow;
    }
  }

  /// Recupera tutti i gruppi di cui l'utente fa parte.
  Future<List<Gruppo>> mieiGruppi(String idUtente) async {
    try {
      final query = await _gruppiRef
          .where('partecipanti', arrayContains: idUtente)
          .where('attivo', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => Gruppo.daMappa(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Errore durante il recupero dei gruppi: $e');
      rethrow;
    }
  }

  /// Rimuove un utente dai partecipanti di un gruppo.
  Future<void> esciDalGruppo(String idGruppo, String idUtente) async {
    try {
      await _gruppiRef.doc(idGruppo).update({
        'partecipanti': FieldValue.arrayRemove([idUtente])
      });
    } catch (e) {
      print('Errore durante l\'uscita dal gruppo: $e');
      rethrow;
    }
  }

  /// Disattiva un gruppo (soft delete) solo se l'utente è il creatore.
  Future<void> eliminaGruppo(String idGruppo, String idUtente) async {
    try {
      final doc = await _gruppiRef.doc(idGruppo).get();
      if (!doc.exists) return;

      final dati = doc.data() as Map<String, dynamic>;
      if (dati['idCreatore'] == idUtente) {
        await _gruppiRef.doc(idGruppo).update({'attivo': false});
      } else {
        throw Exception('Solo il creatore può eliminare il gruppo.');
      }
    } catch (e) {
      print('Errore durante l\'eliminazione del gruppo: $e');
      rethrow;
    }
  }
}
