import 'package:flutter_test/flutter_test.dart';
import 'package:ridebridge/modelli/posizione_gps.dart';
import 'package:ridebridge/modelli/route_point.dart';
import 'package:ridebridge/servizi/snake_formation_manager.dart';
import 'package:ridebridge/servizi/route_track_manager.dart';

void main() {
  late SnakeFormationManager snake;
  late RouteTrackManager track;

  setUp(() {
    snake = SnakeFormationManager();
    track = RouteTrackManager();
  });

  group('TailState & GC Tests', () {
    test('Calcolo TailState con Scopa affidabile', () {
      final traccia = List.generate(10, (i) => RoutePoint(id: 'p$i', latitudine: i * 0.01, longitudine: 0.0, timestamp: DateTime.now()));
      
      // Scopa a P2
      snake.aggiornaPosizionePartecipante(
        uid: 'scopa_uid',
        pos: PosizioneGps(latitudine: 0.02, longitudine: 0.0, ultimoAggiornamento: DateTime.now()),
        traccia: traccia,
        leaderIndex: 9,
      );

      // Partecipante a P5
      snake.aggiornaPosizionePartecipante(
        uid: 'user_uid',
        pos: PosizioneGps(latitudine: 0.05, longitudine: 0.0, ultimoAggiornamento: DateTime.now()),
        traccia: traccia,
        leaderIndex: 9,
      );

      final tail = snake.calcolaTailState('scopa_uid');
      expect(tail.tailUid, 'scopa_uid');
      expect(tail.tailIndex, 2);
      expect(tail.isScopaReliable, true);
    });

    test('Fallback TailState su partecipante se Scopa inaffidabile', () {
      final traccia = List.generate(10, (i) => RoutePoint(id: 'p$i', latitudine: i * 0.01, longitudine: 0.0, timestamp: DateTime.now()));
      
      // Scopa con confidence bassissima (inaffidabile)
      snake.aggiornaPosizionePartecipante(
        uid: 'scopa_uid',
        pos: PosizioneGps(latitudine: 0.9, longitudine: 0.9, ultimoAggiornamento: DateTime.now()), // Lontano
        traccia: traccia,
        leaderIndex: 9,
      );

      // Partecipante affidabile a P3
      snake.aggiornaPosizionePartecipante(
        uid: 'user_uid',
        pos: PosizioneGps(latitudine: 0.03, longitudine: 0.0, ultimoAggiornamento: DateTime.now()),
        traccia: traccia,
        leaderIndex: 9,
      );

      final tail = snake.calcolaTailState('scopa_uid');
      expect(tail.tailUid, 'user_uid');
      expect(tail.tailIndex, 3);
      expect(tail.isScopaReliable, false);
    });

    test('Garbage Collection con buffer distanza', () {
      // Creiamo traccia lunga 3km (30 punti da 100m)
      for (int i = 0; i < 30; i++) {
        track.aggiungiPosizioneLeader(PosizioneGps(
          latitudine: i * 0.001, // ~111m per punto
          longitudine: 0.0,
          ultimoAggiornamento: DateTime.now().add(Duration(seconds: i * 5)),
        ));
      }

      final tracciaCompleta = track.ottieniRoutePoints();
      expect(tracciaCompleta.length, 30);

      // Coda tecnica a P20 (~2220m)
      // Vogliamo pulire con buffer 1000m -> Punti prima di 1220m (circa P11)
      track.pulisciPuntiSuperati(20, bufferMeters: 1000.0);

      final tracciaPulita = track.ottieniRoutePoints();
      
      // Verifica che i punti recenti siano rimasti
      expect(tracciaPulita.last.id, tracciaCompleta.last.id);
      expect(tracciaPulita.any((p) => tracciaCompleta.indexOf(p) == 20), true);
      
      // Verifica che i punti vecchi siano spariti
      expect(tracciaPulita.any((p) => tracciaCompleta.indexOf(p) == 0), false);
      expect(tracciaPulita.length, lessThan(30));
    });
  });
}
