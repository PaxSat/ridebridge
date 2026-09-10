import 'package:flutter_test/flutter_test.dart';
import 'package:ridebridge/modelli/posizione_gps.dart';
import 'package:ridebridge/modelli/route_point_status.dart';
import 'package:ridebridge/servizi/route_track_manager.dart';

void main() {
  late RouteTrackManager manager;

  setUp(() {
    manager = RouteTrackManager(
      sogliaDistanzaMeters: 25.0,
      sogliaTempo: const Duration(seconds: 4),
    );
  });

  group('RouteTrackManager Tests', () {
    test('Creazione primo RoutePoint con UUID e sequenceId', () {
      final pos = PosizioneGps(
        latitudine: 41.8902,
        longitudine: 12.4922,
        direzione: 90.0,
        ultimoAggiornamento: DateTime.now(),
      );

      final p = manager.aggiungiPosizioneLeader(pos);

      expect(p, isNotNull);
      expect(p!.id.length, greaterThan(20)); // UUID format
      expect(p.sequenceId, 0);
      expect(p.bearing, 90.0);
    });

    test('Calcolo bearing reale del segmento', () {
      final ora = DateTime.now();
      
      // P1: Start a 0,0
      manager.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 0.0,
        longitudine: 0.0,
        direzione: 0.0,
        ultimoAggiornamento: ora,
      ));

      // P2: Spostamento verso EST (90 gradi)
      final p2 = manager.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 0.0,
        longitudine: 0.001,
        direzione: 180.0, // GPS errato
        ultimoAggiornamento: ora.add(const Duration(seconds: 10)),
      ));

      expect(p2, isNotNull);
      expect(p2!.sequenceId, 1);
      expect(p2.bearing, closeTo(90.0, 1.0));
    });

    test('Serializzazione RoutePointStatus', () {
      final status = RoutePointStatus(
        routePointId: 'uuid',
        sequenceId: 100,
        passaggiUtenti: {'mario': DateTime.now()},
      );

      final mappa = status.aMappa();
      expect(mappa['sequenceId'], 100);
      expect(mappa['passaggiUtenti']['mario'], isNotNull);

      final status2 = RoutePointStatus.daMappa(mappa);
      expect(status2.sequenceId, 100);
    });
  });
}
