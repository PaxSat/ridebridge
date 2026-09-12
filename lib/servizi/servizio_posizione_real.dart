import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/partecipante_gruppo.dart';
import 'servizio_gruppi.dart';

/// Servizio reale per la gestione delle posizioni GPS (GeoRef V3).
class ServizioPosizioneReal {
  final String idGruppo;
  final String mioUid;
  final _servizioGruppi = ServizioGruppi();
  
  String? leaderUid;
  String? scopaUid;

  final _controller = StreamController<Map<String, PartecipanteGruppo>>.broadcast();
  final _gpsController = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;
  Timer? _gpsTimer;

  ServizioPosizioneReal({required this.idGruppo, required this.mioUid});

  /// Stream che emette la mappa completa dei partecipanti compresi i flag.
  Stream<Map<String, PartecipanteGruppo>> get streamPosizioni => _controller.stream;

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
      final Map<String, PartecipanteGruppo> posizioni = {};
      
      leaderUid = null;
      scopaUid = null;

      for (var doc in snapshot.docs) {
        final dati = doc.data();
        final part = PartecipanteGruppo.daMappa(dati, doc.id);
        
        // Identificazione dinamica dei ruoli
        if (part.ruolo == RuoloGruppo.leader) leaderUid = doc.id;
        if (part.ruolo == RuoloGruppo.scopa) scopaUid = doc.id;

        if (part.posizioneGps != null) {
          posizioni[doc.id] = part;
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
