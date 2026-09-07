import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';

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

      // Crea il documento del gruppo
      final docGruppo = await _gruppiRef.add({
        'nome': nome,
        'codiceAccesso': codice,
        'idCreatore': idCreatore,
        'dataCreazione': FieldValue.serverTimestamp(),
        'attivo': true,
        'partecipanti': [idCreatore], // Manteniamo l'array per query veloci
      });

      // Aggiunge il creatore come Leader nella sottocollezione partecipanti
      final partecipanteLeader = PartecipanteGruppo(
        idUtente: idCreatore,
        ruolo: RuoloGruppo.leader,
      );

      await docGruppo
          .collection('partecipanti')
          .doc(idCreatore)
          .set(partecipanteLeader.aMappa());

      return codice;
    } catch (e) {
      debugPrint('Errore durante la creazione del gruppo: $e');
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
      final dati = doc.data() as Map<String, dynamic>;
      final partecipantiArray = List<String>.from(dati['partecipanti'] ?? []);

      if (partecipantiArray.contains(idUtente)) {
        return; // Utente già presente
      }

      // Aggiorna l'array nel documento principale
      await _gruppiRef.doc(doc.id).update({
        'partecipanti': FieldValue.arrayUnion([idUtente])
      });

      // Aggiunge l'utente nella sottocollezione partecipanti come partecipante base
      final nuovoPartecipante = PartecipanteGruppo(
        idUtente: idUtente,
        ruolo: RuoloGruppo.partecipante,
      );

      await _gruppiRef
          .doc(doc.id)
          .collection('partecipanti')
          .doc(idUtente)
          .set(nuovoPartecipante.aMappa());
    } catch (e) {
      debugPrint('Errore durante l\'ingresso nel gruppo: $e');
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
      debugPrint('Errore durante il recupero dei gruppi: $e');
      rethrow;
    }
  }

  /// Rimuove un utente dai partecipanti di un gruppo.
  Future<void> esciDalGruppo(String idGruppo, String idUtente) async {
    try {
      // Rimuove dalla sottocollezione
      await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .delete();

      // Rimuove dall'array
      await _gruppiRef.doc(idGruppo).update({
        'partecipanti': FieldValue.arrayRemove([idUtente])
      });
    } catch (e) {
      debugPrint('Errore durante l\'uscita dal gruppo: $e');
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
      debugPrint('Errore durante l\'eliminazione del gruppo: $e');
      rethrow;
    }
  }

  // --- LOGICA RUOLI E PERMESSI ---

  /// Verifica se l'utente è il leader del gruppo.
  Future<bool> _eLeader(String idGruppo, String idUtente) async {
    final doc = await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idUtente)
        .get();
    
    if (!doc.exists) return false;
    return doc.data()?['ruolo'] == RuoloGruppo.leader.name;
  }

  /// Assegna il ruolo di "scopa" a un partecipante. Solo il leader può farlo.
  Future<void> assegnaScopa(String idGruppo, String idLeader, String idDestinatario) async {
    if (!await _eLeader(idGruppo, idLeader)) {
      throw Exception('Solo il leader può assegnare il ruolo di scopa.');
    }
    await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idDestinatario)
        .update({'ruolo': RuoloGruppo.scopa.name});
  }

  /// Rimuove il ruolo di "scopa", riportandolo a partecipante. Solo il leader può farlo.
  Future<void> rimuoviScopa(String idGruppo, String idLeader, String idDestinatario) async {
    if (!await _eLeader(idGruppo, idLeader)) {
      throw Exception('Solo il leader può rimuovere il ruolo di scopa.');
    }
    await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idDestinatario)
        .update({'ruolo': RuoloGruppo.partecipante.name});
  }

  /// Trasferisce il ruolo di leader a un altro utente.
  Future<void> cambiaLeader(String idGruppo, String idLeaderAttuale, String idNuovoLeader) async {
    if (!await _eLeader(idGruppo, idLeaderAttuale)) {
      throw Exception('Solo il leader può trasferire il proprio ruolo.');
    }

    final batch = _firestore.batch();
    
    // Vecchio leader diventa partecipante
    batch.update(
      _gruppiRef.doc(idGruppo).collection('partecipanti').doc(idLeaderAttuale),
      {'ruolo': RuoloGruppo.partecipante.name},
    );

    // Nuovo leader
    batch.update(
      _gruppiRef.doc(idGruppo).collection('partecipanti').doc(idNuovoLeader),
      {'ruolo': RuoloGruppo.leader.name},
    );

    // Aggiorna anche idCreatore nel documento principale per coerenza
    batch.update(_gruppiRef.doc(idGruppo), {'idCreatore': idNuovoLeader});

    await batch.commit();
  }

  /// Abilita il microfono per un partecipante.
  Future<void> abilitaMicrofonoPartecipante(String idGruppo, String idLeader, String idPartecipante) async {
    if (!await _eLeader(idGruppo, idLeader)) {
      throw Exception('Solo il leader può gestire i permessi del microfono.');
    }
    await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idPartecipante)
        .update({'microfonoConsentito': true});
  }

  /// Disabilita il microfono per un partecipante.
  Future<void> disabilitaMicrofonoPartecipante(String idGruppo, String idLeader, String idPartecipante) async {
    if (!await _eLeader(idGruppo, idLeader)) {
      throw Exception('Solo il leader può gestire i permessi del microfono.');
    }
    await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idPartecipante)
        .update({'microfonoConsentito': false});
  }

  /// Abilita l'audio per un partecipante.
  Future<void> abilitaAudioPartecipante(String idGruppo, String idLeader, String idPartecipante) async {
    if (!await _eLeader(idGruppo, idLeader)) {
      throw Exception('Solo il leader può gestire i permessi audio.');
    }
    await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idPartecipante)
        .update({'audioConsentito': true});
  }

  /// Disabilita l'audio per un partecipante.
  Future<void> disabilitaAudioPartecipante(String idGruppo, String idLeader, String idPartecipante) async {
    if (!await _eLeader(idGruppo, idLeader)) {
      throw Exception('Solo il leader può gestire i permessi audio.');
    }
    await _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .doc(idPartecipante)
        .update({'audioConsentito': false});
  }
}
