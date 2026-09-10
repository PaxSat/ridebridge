import 'package:flutter_test/flutter_test.dart';
import 'package:ridebridge/modelli/posizione_gps.dart';
import 'package:ridebridge/modelli/route_point.dart';
import 'package:ridebridge/modelli/route_progress.dart';
import 'package:ridebridge/servizi/snake_formation_manager.dart';
import 'package:ridebridge/servizi/formation_manager.dart';

void main() {
  late SnakeFormationManager manager;
  late List<RoutePoint> mockTraccia;

  setUp(() {
    manager = SnakeFormationManager();
    // Traccia rettilinea: 1 punto ogni 100m
    mockTraccia = List.generate(20, (i) => RoutePoint(
      id: 'p$i',
      latitudine: i * 0.0009,
      longitudine: 0.0,
      timestamp: DateTime.now().add(Duration(seconds: i * 4)),
      distanzaProgressiva: i * 100.0,
    ));
  });

  group('GeoRef V2 - Walking on the Snake', () {
    test('Progressione sequenziale corretta', () {
      final t0 = DateTime.now();
      
      // 1. Aggancio iniziale a P0
      manager.aggiornaPosizionePartecipante(
        uid: 'rider', pos: PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: t0), 
        traccia: mockTraccia, leaderIndex: 10,
      );
      
      // 2. Passaggio a P1
      final p1 = manager.aggiornaPosizionePartecipante(
        uid: 'rider', pos: PosizioneGps(latitudine: 0.0009, longitudine: 0, ultimoAggiornamento: t0.add(const Duration(seconds: 4))), 
        traccia: mockTraccia, leaderIndex: 10,
      );

      expect(p1.lastValidatedIndex, 1);
      expect(p1.nextTargetIndex, 2);
      expect(p1.engineState, EngineState.normal);
    });

    test('Blocco tornante (ignora P8 se target è P3)', () {
      final t0 = DateTime.now();
      
      // Agganciato a P2
      manager.aggiornaPosizionePartecipante(
        uid: 'rider', pos: PosizioneGps(latitudine: 0.0018, longitudine: 0, ultimoAggiornamento: t0), 
        traccia: mockTraccia, leaderIndex: 15,
      );

      // Salto GPS vicino a P8 (0.0072)
      // La finestra di ricerca è limitata (P3, P4, P5), P8 non dovrebbe essere validato
      final p = manager.aggiornaPosizionePartecipante(
        uid: 'rider', pos: PosizioneGps(latitudine: 0.0072, longitudine: 0, ultimoAggiornamento: t0.add(const Duration(seconds: 1))), 
        traccia: mockTraccia, leaderIndex: 15,
      );

      expect(p.lastValidatedIndex, 2); // Rimane fermo al precedente
      expect(p.consecutiveMisses, 1);
    });

    test('Transizione in OFF_ROUTE', () {
      final t0 = DateTime.now();
      // Inizio a P0
      manager.aggiornaPosizionePartecipante(
        uid: 'rider', 
        pos: PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: t0), 
        traccia: mockTraccia, 
        leaderIndex: 10,
      );

      // Si sposta lontano (200m) per 5 campionamenti
      RouteProgress? p;
      for (int i = 1; i <= 5; i++) {
        p = manager.aggiornaPosizionePartecipante(
          uid: 'rider', 
          pos: PosizioneGps(latitudine: 0.001, longitudine: 0.0018, ultimoAggiornamento: t0.add(Duration(seconds: i*4))), 
          traccia: mockTraccia, leaderIndex: 10
        );
      }

      expect(p!.engineState, EngineState.offRoute);
      expect(manager.determinaStato(uid: 'rider', leaderProgress: 1000.0), StatoCarovana.offRoute);
    });

    test('Rientro sulla traccia (REJOIN)', () {
      final t0 = DateTime.now();
      // Rider già OFF_ROUTE
      manager.aggiornaPosizionePartecipante(
        uid: 'rider', 
        pos: PosizioneGps(latitudine: 1.0, longitudine: 1.0, ultimoAggiornamento: t0), 
        traccia: mockTraccia, leaderIndex: 10
      );

      // Rientra vicino a P5
      final p = manager.aggiornaPosizionePartecipante(
        uid: 'rider', 
        pos: PosizioneGps(latitudine: 5 * 0.0009, longitudine: 0, ultimoAggiornamento: t0.add(const Duration(seconds: 10))), 
        traccia: mockTraccia, leaderIndex: 10
      );

      expect(p.engineState, EngineState.rejoin);
      expect(p.lastValidatedIndex, 5);
      expect(p.nextTargetIndex, 6);
    });
  });
}

extension on PosizioneGps {
  static PosizioneGps create({required double lat, required double lon, required DateTime time}) {
    return PosizioneGps(latitudine: lat, longitudine: lon, ultimoAggiornamento: time);
  }
}

PosizioneGps PosizioneGpsShort({double lat = 0, double lon = 0, DateTime? time}) {
  return PosizioneGps(latitudine: lat, longitudine: lon, ultimoAggiornamento: time ?? DateTime.now());
}
