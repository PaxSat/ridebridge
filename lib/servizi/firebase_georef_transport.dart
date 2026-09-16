import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../modelli/snake_state.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/partecipante_gruppo.dart';
import 'georef_transport.dart';
import 'servizio_gruppi.dart';

/// Implementazione Firebase del Transport Layer per GeoRef.
/// Incapsula ServizioGruppi e le interazioni dirette con Firestore.
class FirebaseGeorefTransport implements GeorefTransport {
  final _servizioGruppi = ServizioGruppi();
  final _firestore = FirebaseFirestore.instance;
  
  final _gpsController = StreamController<bool>.broadcast();
  Timer? _gpsTimer;

  FirebaseGeorefTransport() {
    _avviaMonitoraggioGps();
  }

  void _avviaMonitoraggioGps() {
    _gpsTimer?.cancel();
    // Prima verifica immediata
    Geolocator.isLocationServiceEnabled().then((attivo) {
      if (!_gpsController.isClosed) _gpsController.add(attivo);
    });

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final attivo = await Geolocator.isLocationServiceEnabled();
      if (!_gpsController.isClosed) _gpsController.add(attivo);
    });
  }

  @override
  Stream<bool> get streamStatoGps => _gpsController.stream;

  @override
  Future<void> aggiornaPartecipazione(String idGruppo, String idUtente, bool partecipando) {
    return _servizioGruppi.aggiornaPartecipazione(idGruppo, idUtente, partecipando);
  }

  @override
  Future<void> pubblicaSnakeState(String idGruppo, SnakeState stato) {
    return _servizioGruppi.aggiornaSnakeState(idGruppo, stato);
  }

  @override
  Stream<SnakeState?> streamSnakeState(String idGruppo) {
    return _servizioGruppi.streamSnakeState(idGruppo);
  }

  @override
  Future<SnakeState?> ottieniSnakeState(String idGruppo) {
    return _servizioGruppi.ottieniSnakeState(idGruppo);
  }

  @override
  Future<void> pubblicaProgressBackup(String idGruppo, Map<String, int> avanzamenti) {
    return _servizioGruppi.aggiornaAvanzamentiScopa(idGruppo, avanzamenti);
  }

  @override
  Future<Map<String, int>> ottieniProgressBackup(String idGruppo) {
    return _servizioGruppi.ottieniAvanzamentiScopa(idGruppo);
  }

  @override
  Future<void> pubblicaPosizione(String idGruppo, String idUtente, PosizioneGps posizione) {
    return _servizioGruppi.aggiornaPosizione(idGruppo, idUtente, posizione);
  }

  @override
  Stream<Map<String, PartecipanteGruppo>> streamPosizioni(String idGruppo) {
    return _firestore
        .collection('gruppi')
        .doc(idGruppo)
        .collection('partecipanti')
        .snapshots()
        .map((snapshot) {
      final Map<String, PartecipanteGruppo> posizioni = {};
      for (var doc in snapshot.docs) {
        posizioni[doc.id] = PartecipanteGruppo.daMappa(doc.data(), doc.id);
      }
      return posizioni;
    });
  }

  void dispose() {
    _gpsTimer?.cancel();
    _gpsController.close();
  }
}
