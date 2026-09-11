import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
  final _gpsController = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;
  Timer? _gpsTimer;

  ServizioPosizioneReal({required this.idGruppo, required this.mioUid});

  /// Stream che emette le posizioni reali aggregate di tutti i partecipanti.
  Stream<Map<String, PosizioneGps>> get streamPosizioni => _controller.stream;

  /// Stream che emette lo stato del servizio GPS (abilitato/disabilitato).
  Stream<bool> get streamStatoGps => _gpsController.stream;

  /// Verifica istantanea se il servizio GPS è attivo sul dispositivo.
  Future<bool> isGpsAbilitato() async {
    return await Geolocator.isLocationServiceEnabled();
  }

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
      
      debugPrint('[GEOREF] Snapshot ricevuto numPartecipanti=${posizioni.length} uids=${posizioni.keys.toList()}');

      if (posizioni.isNotEmpty) {
        _controller.add(posizioni);
      }
    });

    _avviaMonitoraggioGps();
  }

  /// Avvia un loop di verifica periodica dello stato GPS (ogni 5 secondi).
  void _avviaMonitoraggioGps() {
    _gpsTimer?.cancel();
    
    // Prima verifica immediata
    isGpsAbilitato().then((attivo) => _gpsController.add(attivo));

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final attivo = await isGpsAbilitato();
      _gpsController.add(attivo);
    });
  }

  /// Metodo predisposto per l'aggiornamento della propria posizione reale.
  /// Dovrebbe essere chiamato da un listener di Geolocator.
  Future<void> aggiornaMiaPosizione(PosizioneGps pos) async {
    debugPrint('[GEOREF] Firestore write uid=$mioUid lat=${pos.latitudine} lon=${pos.longitudine}');
    await _servizioGruppi.aggiornaPosizione(idGruppo, mioUid, pos);
    debugPrint('[GEOREF] Firestore write OK');
  }

  void ferma() {
    _subscription?.cancel();
    _gpsTimer?.cancel();
  }
}
