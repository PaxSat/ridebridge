import 'package:flutter_test/flutter_test.dart';
import 'package:ridebridge/modelli/posizione_gps.dart';
import 'package:ridebridge/modelli/route_point.dart';
import 'package:ridebridge/modelli/route_point_status.dart';
import 'package:ridebridge/modelli/engine_state.dart';
import 'package:ridebridge/modelli/route_progress.dart';
import 'package:ridebridge/servizi/route_track_manager.dart';
import 'package:ridebridge/servizi/snake_formation_manager.dart';

void main() {
  group('GeoRef V2 Consolidation Tests', () {
    late RouteTrackManager track;
    late SnakeFormationManager snake;

    setUp(() {
      track = RouteTrackManager(
        sogliaDistanzaMeters: 25.0,
        sogliaTempo: const Duration(seconds: 4),
      );
      snake = SnakeFormationManager();
    });

    test('1. Leader fermo 30s -> nessun nuovo RoutePoint (AND logic)', () {
      final t0 = DateTime.now();
      final pos = PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: t0);
      
      track.aggiungiPosizioneLeader(pos); // P0
      
      // Passano 30 secondi ma rimane fermo
      for (int i = 1; i <= 30; i++) {
        final p = track.aggiungiPosizioneLeader(pos.copiaCon(ultimoAggiornamento: t0.add(Duration(seconds: i))));
        expect(p, isNull);
      }
      
      expect(track.ottieniRoutePoints().length, 1);
    });

    test('2-3. SequenceId progressivo e UUID presente', () {
      final t0 = DateTime.now();
      track.aggiungiPosizioneLeader(PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: t0));
      
      final p1 = track.aggiungiPosizioneLeader(PosizioneGps(
        latitudine: 0.001, // ~111m
        longitudine: 0, 
        ultimoAggiornamento: t0.add(const Duration(seconds: 10)),
      ));

      expect(p1!.sequenceId, 1);
      expect(p1.id, isNotEmpty);
      expect(p1.id.length, greaterThan(30)); // UUID format
    });

    test('4-5. Transito individuale in RoutePointStatus', () {
      final status = RoutePointStatus(routePointId: 'p1', sequenceId: 1);
      final activeUids = ['mario', 'luca', 'scopa'];

      final status1 = status.copiaCon(passaggiUtenti: {'mario': DateTime.now()});
      expect(status1.sonoTuttiPassati(activeUids), false);

      final statusFull = status1.copiaCon(passaggiUtenti: {
        'mario': DateTime.now(),
        'luca': DateTime.now(),
        'scopa': DateTime.now(),
      });
      expect(statusFull.sonoTuttiPassati(activeUids), true);
    });

    test('6-7. Garbage Collection basata su transito topologico', () {
      final t0 = DateTime.now();
      final p0 = track.aggiungiPosizioneLeader(PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: t0))!;
      final p1 = track.aggiungiPosizioneLeader(PosizioneGps(latitudine: 0.001, longitudine: 0, ultimoAggiornamento: t0.add(const Duration(seconds: 10))))!;

      // GC con p0 non completato (basato su sequenceId)
      track.garbageCollection(completedSequenceIds: [p1.sequenceId]);
      expect(track.ottieniRoutePoints().contains(p0), true);

      // GC con p0 completato
      track.garbageCollection(completedSequenceIds: [p0.sequenceId]);
      expect(track.ottieniRoutePoints().contains(p0), false);
    });

    test('8. Scopa non dominante nel TailState', () {
      final traccia = [
        RoutePoint(id: 'p0', sequenceId: 0, latitudine: 0, longitudine: 0, timestamp: DateTime.now()),
        RoutePoint(id: 'p1', sequenceId: 1, latitudine: 0.01, longitudine: 0, timestamp: DateTime.now()),
      ];

      // Scopa ferma a P0
      snake.aggiornaPosizionePartecipante(uid: 'scopa', pos: PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: DateTime.now()), traccia: traccia, leaderSequenceId: 1);
      // Rider avanti a P1
      snake.aggiornaPosizionePartecipante(uid: 'rider', pos: PosizioneGps(latitudine: 0.01, longitudine: 0, ultimoAggiornamento: DateTime.now()), traccia: traccia, leaderSequenceId: 1);

      final tail = snake.calcolaTailState();
      expect(tail.tailUid, 'scopa');
      expect(tail.tailIndex, 0);
    });
  });
}

extension on PosizioneGps {
  PosizioneGps copiaCon({DateTime? ultimoAggiornamento}) {
    return PosizioneGps(
      latitudine: latitudine,
      longitudine: longitudine,
      ultimoAggiornamento: ultimoAggiornamento ?? this.ultimoAggiornamento,
    );
  }
}
