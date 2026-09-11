import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelli/posizione_gps.dart';
import 'servizio_gruppi.dart';

/// Servizio reale per la gestione delle posizioni GPS (GeoRef V2).
/// Utilizza Firestore per le posizioni dei compagni e si predispone per Geolocator.
class ServizioPosizioneReal {
  final String idGruppo;
  final String mioUid;
  final _servizioGruppi = ServizioGruppi();
  
  String? leaderUid;
  String? scopaUid;

  final _controller = StreamController<Map<String, PosizioneGps>>.broadcast();
  StreamSubscription? _subscription;

  ServizioPosizioneReal({required this.idGruppo, required this.mioUid});

  /// Stream che emette le posizioni reali aggregate di tutti i partecipanti.
  Stream<Map<String, PosizioneGps>> get streamPosizioni => _controller.stream;

  /// Avvia l'ascolto delle posizioni reali dal gruppo Firestore.
  void avvia() {
    _subscription?.cancel();
    
    // Ascoltiamo i cambiamenti nella sottocollezione partecipanti del gruppo
    _subscription = FirebaseFirestore.instance
        .collection('gruppi')
        .doc(idGruppo)
        .collection('partecipanti')
        .snapshots()
        .listen((snapshot) {
      final Map<String, PosizioneGps> posizioni = {};
      
      leaderUid = null;
      scopaUid = null;

      for (var doc in snapshot.docs) {
        final dati = doc.data();
        
        // Identificazione dinamica dei ruoli
        final ruolo = dati['ruolo'];
        if (ruolo == 'leader') leaderUid = doc.id;
        if (ruolo == 'scopa') scopaUid = doc.id;

        if (dati.containsKey('posizioneGps')) {
          posizioni[doc.id] = PosizioneGps.daMappa(dati['posizioneGps'] as Map<String, dynamic>);
        }
      }
      
      if (posizioni.isNotEmpty) {
        _controller.add(posizioni);
      }
    });
  }

  /// Metodo predisposto per l'aggiornamento della propria posizione reale.
  /// Dovrebbe essere chiamato da un listener di Geolocator.
  Future<void> aggiornaMiaPosizione(PosizioneGps pos) async {
    await _servizioGruppi.aggiornaPosizione(idGruppo, mioUid, pos);
  }

  void ferma() {
    _subscription?.cancel();
  }
}
