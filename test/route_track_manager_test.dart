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
    test('Creazione primo RoutePoint con UUID', () {
      final pos = PosizioneGps(
        latitudine: 41.8902,
        longitudine: 12.4922,
        direzione: 90.0,
        ultimoAggiornamento: DateTime.now(),
      );

      final p = manager.aggiungiPosizioneLeader(pos);

      expect(p, isNotNull);
      expect(p!.id.length, greaterThan(20)); // Verifica formato UUID
      expect(p.bearing, 90.0); // Primo punto usa GPS bearing
      expect(p.distanzaProgressiva, 0.0);
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

      // P2: Spostamento verso EST (90 gradi) di ~111 metri
      final p2 = manager.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 0.0,
        longitudine: 0.001, // ~111 metri a 0,0
        direzione: 180.0, // GPS dice SUD (errato volutamente per test)
        ultimoAggiornamento: ora.add(const Duration(seconds: 10)),
      ));

      expect(p2, isNotNull);
      // Il bearing deve essere ~90 (EST) calcolato dal segmento, non 180 (GPS)
      expect(p2!.bearing, closeTo(90.0, 1.0));
    });

    test('Identificativo univoco', () {
      final pos = PosizioneGps(
        latitudine: 41.8902,
        longitudine: 12.4922,
        ultimoAggiornamento: DateTime.now(),
      );

      final p1 = manager.aggiungiPosizioneLeader(pos);
      manager.reset();
      final p2 = manager.aggiungiPosizioneLeader(pos);

      expect(p1!.id, isNot(p2!.id));
    });

    test('Incremento progressivo su percorso spezzato', () {
      final ora = DateTime.now();
      
      manager.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 0, 
        longitudine: 0, 
        ultimoAggiornamento: ora,
      )); // P1
      
      // Spostamento 100m Nord
      final p2 = manager.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 100 / 111320, 
        longitudine: 0, 
        ultimoAggiornamento: ora.add(const Duration(seconds: 10)),
      ));
      
      // Spostamento 100m Est
      final p3 = manager.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 100 / 111320, 
        longitudine: 100 / 111320, 
        ultimoAggiornamento: ora.add(const Duration(seconds: 20)),
      ));

      expect(p2!.distanzaProgressiva, closeTo(100.0, 1.0));
      expect(p3!.distanzaProgressiva, closeTo(200.0, 2.0));
    });
  });

  group('RoutePoint Models Tests', () {
    test('Serializzazione RoutePointStatus con mappa passaggi', () {
      final ora = DateTime.now();
      final status = RoutePointStatus(
        routePointId: 'test-id',
        utentiPassati: {'mario', 'luca'},
        passaggiUtenti: {
          'mario': ora,
          'luca': ora.add(const Duration(seconds: 2)),
        },
        lifecycle: RoutePointLifecycle.completed,
      );

      final mappa = status.aMappa();
      expect(mappa['passaggiUtenti'], isA<Map>());
      expect(mappa['passaggiUtenti']['mario'], isNotNull);

      final status2 = RoutePointStatus.daMappa(mappa);
      expect(status2.passaggiUtenti['luca'], isNotNull);
      // Confronto grossolano dei secondi per evitare problemi di precisione millisecondi
      expect(status2.passaggiUtenti['luca']!.second, status.passaggiUtenti['luca']!.second);
    });
  });
}
