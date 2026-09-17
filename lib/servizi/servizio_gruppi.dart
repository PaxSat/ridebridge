import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/stato_audio.dart';


import '../modelli/configurazione_gruppo.dart';
import '../modelli/snake_state.dart';
import 'firestore_mapper.dart';

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
        online: true,
        ultimoAccesso: DateTime.now(),
        statoAudio: StatoAudio(
          ultimoAggiornamento: DateTime.now(),
          prioritaAudio: true,
        ),
      );

      await docGruppo
          .collection('partecipanti')
          .doc(idCreatore)
          .set(FirestoreMapper.dateTimeToTimestamp(partecipanteLeader.aMappa()));

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
        // Se è già presente, aggiorniamo solo la presenza
        await aggiornaPresenza(doc.id, idUtente, true);
        return;
      }

      // Aggiorna l'array nel documento principale
      await _gruppiRef.doc(doc.id).update({
        'partecipanti': FieldValue.arrayUnion([idUtente])
      });

      // Aggiunge l'utente nella sottocollezione partecipanti come partecipante base
      final nuovoPartecipante = PartecipanteGruppo(
        idUtente: idUtente,
        ruolo: RuoloGruppo.partecipante,
        online: true,
        ultimoAccesso: DateTime.now(),
        statoAudio: StatoAudio(
          ultimoAggiornamento: DateTime.now(),
          prioritaAudio: false,
        ),
      );

      await _gruppiRef
          .doc(doc.id)
          .collection('partecipanti')
          .doc(idUtente)
          .set(FirestoreMapper.dateTimeToTimestamp(nuovoPartecipante.aMappa()));
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
          .map((doc) => Gruppo.daMappa(FirestoreMapper.timestampToDateTime(doc.data() as Map<String, dynamic>), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Errore durante il recupero dei gruppi: $e');
      rethrow;
    }
  }

  /// Rimuove un utente dai partecipanti di un gruppo.
  /// Il Leader non può uscire senza prima trasferire il comando o eliminare il gruppo.
  Future<void> esciDalGruppo(String idGruppo, String idUtente) async {
    try {
      if (await _eLeader(idGruppo, idUtente)) {
        throw Exception('Il Leader non può uscire dal gruppo. Trasferisci il comando o elimina il gruppo.');
      }

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

  /// Recupera la lista di tutti i partecipanti di un gruppo con i relativi ruoli.
  Future<List<PartecipanteGruppo>> listaPartecipanti(String idGruppo) async {
    try {
      final snapshot = await _gruppiRef.doc(idGruppo).collection('partecipanti').get();
      return snapshot.docs
          .map((doc) => PartecipanteGruppo.daMappa(FirestoreMapper.timestampToDateTime(doc.data()), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Errore durante il recupero dei partecipanti: $e');
      rethrow;
    }
  }

  /// Stream della lista dei partecipanti per aggiornamenti real-time.
  Stream<List<PartecipanteGruppo>> streamPartecipanti(String idGruppo) {
    // Semplifichiamo lo stream ascoltando solo la sottocollezione partecipanti per la massima reattività.
    // I membri sono comunque registrati qui non appena aprono il dettaglio o entrano nel gruppo.
    return _gruppiRef
        .doc(idGruppo)
        .collection('partecipanti')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PartecipanteGruppo.daMappa(FirestoreMapper.timestampToDateTime(doc.data()), doc.id))
            .toList());
  }

  /// Recupera il ruolo di un utente specifico in un gruppo.
  Future<PartecipanteGruppo?> ottieniRuoloUtente(String idGruppo, String idUtente) async {
    try {
      final doc = await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .get();
      
      if (!doc.exists) return null;
      return PartecipanteGruppo.daMappa(FirestoreMapper.timestampToDateTime(doc.data()!), idUtente);
    } catch (e) {
      debugPrint('Errore recupero ruolo utente: $e');
      return null;
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
        .update({
          'ruolo': RuoloGruppo.scopa.name,
          'statoAudio.prioritaAudio': true,
        });
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
        .update({
          'ruolo': RuoloGruppo.partecipante.name,
          'statoAudio.prioritaAudio': false,
        });
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
      {
        'ruolo': RuoloGruppo.partecipante.name,
        'statoAudio.prioritaAudio': false,
      },
    );

    // Nuovo leader
    batch.update(
      _gruppiRef.doc(idGruppo).collection('partecipanti').doc(idNuovoLeader),
      {
        'ruolo': RuoloGruppo.leader.name,
        'statoAudio.prioritaAudio': true,
      },
    );

    // Aggiorna anche idCreatore nel documento principale per coerenza
    batch.update(_gruppiRef.doc(idGruppo), {'idCreatore': idNuovoLeader});

    await batch.commit();
  }

  /// Permette a un utente (tipicamente la Scopa) di assumere il ruolo di Leader
  /// nel caso in cui il Leader originale non sia più presente o attivo.
  Future<void> takeoverLeader(String idGruppo, String idNuovoLeader) async {
    try {
      final snapshot = await _gruppiRef.doc(idGruppo).collection('partecipanti').get();
      final batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        if (doc.data()['ruolo'] == RuoloGruppo.leader.name) {
          // Declassa il vecchio leader a partecipante semplice
          batch.update(doc.reference, {
            'ruolo': RuoloGruppo.partecipante.name,
            'statoAudio.prioritaAudio': false,
          });
        }
      }

      // Promuove il nuovo leader
      batch.update(
        _gruppiRef.doc(idGruppo).collection('partecipanti').doc(idNuovoLeader),
        {
          'ruolo': RuoloGruppo.leader.name,
          'statoAudio.prioritaAudio': true,
        },
      );

      // Aggiorna la proprietà del gruppo
      batch.update(_gruppiRef.doc(idGruppo), {'idCreatore': idNuovoLeader});

      await batch.commit();
      debugPrint('[GROUPS] Takeover completato: $idNuovoLeader è il nuovo Leader.');
    } catch (e) {
      debugPrint('Errore durante il takeover del Leader: $e');
      rethrow;
    }
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

  // --- LOGICA PRESENZA E STATO AUDIO ---

  /// Aggiorna lo stato di partecipazione attiva (Carovana) di un utente.
  Future<void> aggiornaPartecipazione(String idGruppo, String idUtente, bool partecipando) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .set({'partecipando': partecipando}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore aggiornaPartecipazione: $e');
    }
  }

  /// Aggiorna lo stato di presenza (online/offline) di un partecipante.
  Future<void> aggiornaPresenza(String idGruppo, String idUtente, bool online) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .set({
            'online': online,
            'ultimoAccesso': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore aggiornamento presenza: $e');
    }
  }

  /// Aggiorna lo stato audio in tempo reale.
  Future<void> aggiornaStatoAudio(String idGruppo, String idUtente, StatoAudio stato) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .set({
            'statoAudio': FirestoreMapper.dateTimeToTimestamp(stato.aMappa()),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore aggiornamento stato audio: $e');
    }
  }

  /// Attiva lo stato di emergenza per un partecipante.
  Future<void> attivaEmergenza(String idGruppo, String idUtente) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .set({
            'statoAudio': {
              'emergenzaAttiva': true,
              'ultimoAggiornamento': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore attivazione emergenza: $e');
    }
  }

  /// Disattiva lo stato di emergenza.
  Future<void> disattivaEmergenza(String idGruppo, String idUtente) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('partecipanti')
          .doc(idUtente)
          .set({
            'statoAudio': {
              'emergenzaAttiva': false,
              'ultimoAggiornamento': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Errore disattivazione emergenza: $e');
    }
  }

  /// Salva la configurazione tecnica del gruppo.
  Future<void> salvaConfigurazione(String idGruppo, ConfigurazioneGruppo config) async {
    try {
      await _gruppiRef.doc(idGruppo).update({
        'configurazione': FirestoreMapper.dateTimeToTimestamp(config.aMappa()),
      });
    } catch (e) {
      debugPrint('Errore salvataggio configurazione: $e');
      rethrow;
    }
  }

  /// Cancella tutti i waypoint (svolte) registrati per un gruppo.
  /// Utilizzato per pulire il database all'inizio o alla fine di una sessione.
  Future<void> cancellaEventiPercorso(String idGruppo) async {
    try {
      // Pulizia V1
      final collectionV1 = _gruppiRef.doc(idGruppo).collection('eventi_percorso');
      final snapshotsV1 = await collectionV1.get();
      
      final batch = _firestore.batch();
      for (var doc in snapshotsV1.docs) {
        batch.delete(doc.reference);
      }

      // Pulizia V2
      final collectionV2 = _gruppiRef.doc(idGruppo).collection('route_points');
      final snapshotsV2 = await collectionV2.get();
      for (var doc in snapshotsV2.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('Database svolte (V1+V2) pulito per il gruppo: $idGruppo');
    } catch (e) {
      debugPrint('Errore durante la cancellazione degli eventi percorso: $e');
    }
  }

  /// Elimina i punti della traccia superati da tutta la carovana su Firestore (GC V2).
  Future<void> pulisciPuntiFirestore(String idGruppo, int tailIndex, {int safeBuffer = 50}) async {
    try {
      final collection = _gruppiRef.doc(idGruppo).collection('route_points');
      // Recuperiamo i punti con indice inferiore alla coda tecnica meno un buffer di sicurezza
      final limitIndex = tailIndex - safeBuffer;
      if (limitIndex <= 0) return;

      final snapshots = await collection
          .where('timestamp', isLessThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 5))))
          .get();
      
      // Nota: Firestore non supporta query dirette su indici progressivi se non indicizzati.
      // Per ora usiamo una logica basata sul timestamp dei punti più vecchi.
      // In produzione si consiglia di aggiungere un campo 'index' ai RoutePoint.
      
      final batch = _firestore.batch();
      int count = 0;
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 450) break; // Limite batch Firestore
      }
      
      if (count > 0) {
        await batch.commit();
        debugPrint('GC V2: Eliminati $count punti obsoleti.');
      }
    } catch (e) {
      debugPrint('Errore Garbage Collection Firestore: $e');
    }
  }

  /// Aggiorna lo stato dello Snake su Firestore. Solo il Leader dovrebbe chiamarlo.
  Future<void> aggiornaSnakeState(String idGruppo, SnakeState stato) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('stato_snake')
          .doc('attuale')
          .set(FirestoreMapper.dateTimeToTimestamp(stato.aMappa()));
    } catch (e) {
      debugPrint('Errore aggiornamento SnakeState: $e');
    }
  }

  /// Recupera l'ultimo SnakeState salvato (Recovery).
  Future<SnakeState?> ottieniSnakeState(String idGruppo) async {
    try {
      final doc = await _gruppiRef
          .doc(idGruppo)
          .collection('stato_snake')
          .doc('attuale')
          .get();
      
      if (!doc.exists || doc.data() == null) return null;
      return SnakeState.daMappa(FirestoreMapper.timestampToDateTime(doc.data()!));
    } catch (e) {
      debugPrint('Errore recupero SnakeState: $e');
      return null;
    }
  }

  /// Stream per ricevere gli aggiornamenti dello SnakeState in tempo reale.
  Stream<SnakeState?> streamSnakeState(String idGruppo) {
    return _gruppiRef
        .doc(idGruppo)
        .collection('stato_snake')
        .doc('attuale')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return SnakeState.daMappa(FirestoreMapper.timestampToDateTime(doc.data()!));
    });
  }

  /// Aggiorna gli avanzamenti dei Rider registrati dalla Scopa su Firestore.
  Future<void> aggiornaAvanzamentiScopa(String idGruppo, Map<String, int> avanzamenti) async {
    try {
      await _gruppiRef
          .doc(idGruppo)
          .collection('stato_scopa')
          .doc('attuale')
          .set({
            'avanzamenti': avanzamenti,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Errore aggiornamento avanzamenti Scopa: $e');
    }
  }

  /// Recupera gli avanzamenti dei Rider registrati dalla Scopa (usato dal Leader nel Recovery).
  Future<Map<String, int>> ottieniAvanzamentiScopa(String idGruppo) async {
    try {
      final doc = await _gruppiRef
          .doc(idGruppo)
          .collection('stato_scopa')
          .doc('attuale')
          .get();
      
      if (!doc.exists || doc.data() == null) return {};
      final mappaAvanzamenti = doc.data()!['avanzamenti'] as Map<String, dynamic>? ?? {};
      return mappaAvanzamenti.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      debugPrint('Errore recupero avanzamenti Scopa: $e');
      return {};
    }
  }
}
