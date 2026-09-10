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

  group('TailState & GC V2 Tests', () {
    test('Calcolo TailState basato su progressione', () {
      final traccia = List.generate(10, (i) => RoutePoint(
        id: 'p$i', 
        sequenceId: i, 
        latitudine: i * 0.01, 
        longitudine: 0.0, 
        timestamp: DateTime.now()
      ));
      
      // Rider 1 a P2
      snake.aggiornaPosizionePartecipante(
        uid: 'user1',
        pos: PosizioneGps(latitudine: 0.02, longitudine: 0.0, ultimoAggiornamento: DateTime.now()),
        traccia: traccia,
        leaderSequenceId: 9,
      );

      // Rider 2 a P5
      snake.aggiornaPosizionePartecipante(
        uid: 'user2',
        pos: PosizioneGps(latitudine: 0.05, longitudine: 0.0, ultimoAggiornamento: DateTime.now()),
        traccia: traccia,
        leaderSequenceId: 9,
      );

      final tail = snake.calcolaTailState();
      expect(tail.tailIndex, 2);
    });

    test('Fallback TailState su partecipante attivo', () {
      final traccia = List.generate(10, (i) => RoutePoint(
        id: 'p$i', 
        sequenceId: i, 
        latitudine: i * 0.01, 
        longitudine: 0.0, 
        timestamp: DateTime.now()
      ));
      
      // Rider 1 inaffidabile (vecchio)
      snake.aggiornaPosizionePartecipante(
        uid: 'lost',
        pos: PosizioneGps(latitudine: 0.9, longitudine: 0.9, ultimoAggiornamento: DateTime.now().subtract(const Duration(minutes: 5))), 
        traccia: traccia,
        leaderSequenceId: 9,
      );

      // Rider 2 affidabile a P3
      snake.aggiornaPosizionePartecipante(
        uid: 'ok',
        pos: PosizioneGps(latitudine: 0.03, longitudine: 0.0, ultimoAggiornamento: DateTime.now()),
        traccia: traccia,
        leaderSequenceId: 9,
      );

      final tail = snake.calcolaTailState();
      expect(tail.tailUid, 'ok');
      expect(tail.tailIndex, 3);
    });

    test('Garbage Collection basata su transito completato', () {
      final p0 = track.aggiungiPosizioneLeader(PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: DateTime.now()))!;
      
      expect(track.ottieniRoutePoints().length, 1);

      // GC con p0 non completato (lista vuota)
      track.garbageCollection(completedSequenceIds: []);
      expect(track.ottieniRoutePoints().length, 1);

      // GC con p0 completato
      track.garbageCollection(completedSequenceIds: [p0.sequenceId]);
      expect(track.ottieniRoutePoints().length, 0);
    });
  });
}
