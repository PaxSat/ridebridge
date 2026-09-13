import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../modelli/route_progress.dart';
import '../modelli/tail_state.dart';
import '../modelli/configurazione_gruppo.dart';
import 'servizio_posizione_fake.dart';
import 'servizio_posizione_real.dart';
import 'route_track_manager.dart';
import 'snake_formation_manager.dart';
import 'formation_manager.dart';
import 'waypoint_manager.dart';
import 'leader_engine.dart';
import 'follower_engine.dart';
import 'servizio_gruppi.dart';
import 'debug_manager.dart';

/// Controller persistente per la gestione della Georeferenziazione (GeoRef V3).
/// Gestisce il ciclo di vita dei motori indipendentemente dalle schermate UI.
class GeoRefController extends ChangeNotifier {
  static final GeoRefController _instance = GeoRefController._internal();
  factory GeoRefController() => _instance;
  GeoRefController._internal();

  final _servizioGruppi = ServizioGruppi();
  final _fakeGps = ServizioPosizioneFake();
  final _trackManager = RouteTrackManager();
  final _snakeManager = SnakeFormationManager();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo();

  late final LeaderEngine _leaderEngine = LeaderEngine(_trackManager);
  late final FollowerEngine _followerEngine = FollowerEngine(_snakeManager);

  ServizioPosizioneReal? _servizioReal;
  StreamSubscription? _subscription;
  StreamSubscription? _localGpsSubscription;
  StreamSubscription<bool>? _gpsStatusSubscription;

  // Stato Operativo
  bool _isAttivo = false;
  String? _idGruppoCorrente;
  String? _mioUid;
  RuoloGruppo? _mioRuolo;

  // Dati in tempo reale (Sola Lettura per la UI)
  final Map<String, PartecipanteGruppo> _snapshotRidersCompleti = {};
  final Map<String, PosizioneGps> _ultimePosizioni = {};
  final Map<String, RouteProgress> _progressi = {};
  final Map<String, String?> _messaggiNavigazione = {};
  final Map<String, AvvisoCarovana?> _avvisiAttivi = {};
  TailState? _tailState;
  bool _gpsDisabilitato = false;

  // Getters per la UI
  bool get isAttivo => _isAttivo;
  Map<String, RouteProgress> get progressi => _progressi;
  Map<String, String?> get messaggiNavigazione => _messaggiNavigazione;
  Map<String, AvvisoCarovana?> get avvisiAttivi => _avvisiAttivi;
  TailState? get tailState => _tailState;
  bool get gpsDisabilitato => _gpsDisabilitato;
  LeaderEngine get leaderEngine => _leaderEngine;
  Map<String, PosizioneGps> get ultimePosizioni => _ultimePosizioni;

  /// Avvia il sistema GeoRef (Bootstrap Reale).
  Future<void> start({
    required String idGruppo,
    required String mioUid,
    required RuoloGruppo mioRuolo,
  }) async {
    if (_isAttivo) return;

    _idGruppoCorrente = idGruppo;
    _mioUid = mioUid;
    _mioRuolo = mioRuolo;
    _isAttivo = true;

    // 1. Imposta partecipazione attiva su Firestore
    await _servizioGruppi.aggiornaPartecipazione(idGruppo, mioUid, true);

    // 2. Inizializza sorgente dati (Real / Fake)
    _cambiaSorgenteGps(!DebugManager().gpsFake);
    
    notifyListeners();
  }

  /// Ferma il sistema GeoRef (Abbandona Carovana).
  Future<void> stop() async {
    if (!_isAttivo) return;

    if (_idGruppoCorrente != null && _mioUid != null) {
      await _servizioGruppi.aggiornaPartecipazione(_idGruppoCorrente!, _mioUid!, false);
    }

    _isAttivo = false;
    _subscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _fakeGps.fermaSimulazione();
    _servizioReal?.ferma();

    _leaderEngine.reset();
    _followerEngine.reset();
    _snapshotRidersCompleti.clear();
    _ultimePosizioni.clear();
    _progressi.clear();
    _messaggiNavigazione.clear();
    _avvisiAttivi.clear();
    _tailState = null;

    notifyListeners();
  }

  void _cambiaSorgenteGps(bool reale) {
    _subscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _fakeGps.fermaSimulazione();
    _servizioReal?.ferma();

    if (reale && _idGruppoCorrente != null && _mioUid != null) {
      _servizioReal = ServizioPosizioneReal(idGruppo: _idGruppoCorrente!, mioUid: _mioUid!);
      
      _subscription = _servizioReal?.streamPosizioni.listen((mappaPartecipanti) {
        _aggiornaDatiEProcessa(mappaPartecipanti);
      });

      _servizioReal?.avvia();
      _avviaBroadcastGpsReale();

      _gpsStatusSubscription = _servizioReal?.streamStatoGps.listen((attivo) {
        _gpsDisabilitato = !attivo;
        notifyListeners();
      });
    } else {
      _subscription = _fakeGps.streamPosizioni.listen((posizioni) {
        final Map<String, PartecipanteGruppo> mockMappa = {};
        posizioni.forEach((uid, gps) {
          mockMappa[uid] = PartecipanteGruppo(
            idUtente: uid,
            ruolo: uid == 'leader' ? RuoloGruppo.leader : (uid == 'scopa' ? RuoloGruppo.scopa : RuoloGruppo.partecipante),
            partecipando: true,
            posizioneGps: gps,
          );
        });
        _aggiornaDatiEProcessa(mockMappa);
      });
      _fakeGps.avviaSimulazione();
    }
  }

  void _aggiornaDatiEProcessa(Map<String, PartecipanteGruppo> mappa) {
    _snapshotRidersCompleti.clear();
    _snapshotRidersCompleti.addAll(mappa);
    
    _ultimePosizioni.clear();
    mappa.forEach((uid, p) {
      if (p.posizioneGps != null) {
        _ultimePosizioni[uid] = p.posizioneGps!;
      }
    });

    _processaMotoreV3();
    notifyListeners();
  }

  void _processaMotoreV3() {
    final leaderKey = !DebugManager().gpsFake ? (_servizioReal?.leaderUid ?? '') : 'leader';
    final scopaKey = !DebugManager().gpsFake ? (_servizioReal?.scopaUid ?? '') : 'scopa';

    final leaderPos = _ultimePosizioni[leaderKey];
    if (leaderPos == null) return;

    final partecipantiAttivi = _snapshotRidersCompleti.values.where((p) => p.partecipando).toList();
    _leaderEngine.processaPosizioneLeader(leaderPos, partecipantiAttivi.length);

    final traccia = _leaderEngine.ottieniRoutePoints();
    final leaderSeqId = _leaderEngine.ultimoRoutePoint()?.sequenceId ?? 0;
    final bool snakeValido = traccia.length >= 2;

    // 2. Inseguimento Snake
    _snapshotRidersCompleti.forEach((uid, rider) {
      if (rider.partecipando && rider.posizioneGps != null) {
        _progressi[uid] = _followerEngine.aggiornaPosizionePartecipante(
          uid: uid,
          pos: rider.posizioneGps!,
          traccia: traccia,
          leaderSequenceId: leaderSeqId,
        );
      }
    });

    // 3. Calcolo TailState
    _tailState = _snakeManager.calcolaTailState();

    // 4. Garbage Collection
    if (partecipantiAttivi.isNotEmpty && snakeValido) {
      int minValidatedIndex = -1;
      for (var rider in partecipantiAttivi) {
        final p = _progressi[rider.idUtente];
        if (p == null || p.lastValidatedIndex == -1) {
          minValidatedIndex = -1;
          break;
        }
        if (minValidatedIndex == -1 || p.lastValidatedIndex < minValidatedIndex) {
          minValidatedIndex = p.lastValidatedIndex;
        }
      }

      final completedIds = minValidatedIndex >= 0 ? List.generate(minValidatedIndex + 1, (i) => i) : <int>[];
      _leaderEngine.eseguiGarbageCollection(
        completedSequenceIds: completedIds,
        distanzaMassimaGruppo: _config.distanzaMassimaGruppo,
      );
    }

    // 5. Analisi Stati e Navigazione
    final leaderProgress = _progressi[leaderKey]?.routeProgress ?? 0.0;
    final scopaProgress = _progressi[scopaKey]?.routeProgress;

    _snapshotRidersCompleti.forEach((uid, rider) {
      if (rider.partecipando && rider.posizioneGps != null) {
        final p = _progressi[uid]!;
        final stato = _snakeManager.determinaStato(
          uid: uid,
          leaderProgress: leaderProgress,
          scopaProgress: scopaProgress,
          maxGroupDistance: _config.distanzaMassimaGruppo,
        );
        _avvisiAttivi[uid] = _formation.generaAvviso(uid, p.engineState, stato);
        final targetPoint = p.nextTargetIndex < traccia.length && p.nextTargetIndex >= 0 ? traccia[p.nextTargetIndex] : null;
        _messaggiNavigazione[uid] = _waypointManager.ottieniIstruzioneNavigazione(
          rider.posizioneGps!, targetPoint, _config.triggerDistanceMeters, p.engineState
        );
      }
    });
  }

  Future<void> _avviaBroadcastGpsReale() async {
    _localGpsSubscription?.cancel();
    _localGpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      final pos = PosizioneGps(
        latitudine: position.latitude,
        longitudine: position.longitude,
        altitudine: position.altitude,
        velocita: position.speed,
        direzione: position.heading,
        ultimoAggiornamento: position.timestamp,
      );
      _servizioReal?.aggiornaMiaPosizione(pos);
    });
  }

  /// Forza un aggiornamento della sorgente (chiamato dal DebugManager)
  void ricaricaSorgenteGps() {
    if (_isAttivo) {
      _cambiaSorgenteGps(!DebugManager().gpsFake);
    }
  }
}
