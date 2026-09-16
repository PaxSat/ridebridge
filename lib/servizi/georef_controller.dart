import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../modelli/route_progress.dart';
import '../modelli/tail_state.dart';
import '../modelli/configurazione_gruppo.dart';
import 'package:collection/collection.dart';
import 'servizio_posizione_fake.dart';
import 'georef_transport.dart';
import 'firebase_georef_transport.dart';
import 'route_track_manager.dart';
import 'snake_formation_manager.dart';
import 'formation_manager.dart';
import 'waypoint_manager.dart';
import 'leader_engine.dart';
import 'follower_engine.dart';
import 'debug_manager.dart';
import '../modelli/route_point.dart';
import '../modelli/snake_state.dart';

/// Controller persistente per la gestione della Georeferenziazione (GeoRef V3).
/// Gestisce il ciclo di vita dei motori indipendentemente dalle schermate UI.
class GeoRefController extends ChangeNotifier {
  static final GeoRefController _instance = GeoRefController._internal();
  factory GeoRefController() => _instance;
  GeoRefController._internal();

  final GeorefTransport _transport = FirebaseGeorefTransport();
  final _fakeGps = ServizioPosizioneFake();
  final _trackManager = RouteTrackManager();
  final _snakeManager = SnakeFormationManager();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo();

  late final LeaderEngine _leaderEngine = LeaderEngine(_trackManager);
  late final FollowerEngine _followerEngine = FollowerEngine(_snakeManager);

  StreamSubscription? _subscription;
  StreamSubscription? _localGpsSubscription;
  StreamSubscription<bool>? _gpsStatusSubscription;

  // Stato Operativo
  bool _isAttivo = false;
  String? _idGruppoCorrente;
  String? _mioUid;
  RuoloGruppo? _mioRuolo;
  SnakeState? _ultimoSnakeStateInviato;
  Map<String, int>? _ultimiAvanzamentiInviati;
  SnakeState? _snakeStateRicevuto;
  StreamSubscription? _snakeSubscription;
  
  // Membri per modalità Fake
  final List<PartecipanteGruppo> _tuttiIMembriGruppo = [];
  final Set<String> _uidsVirtualiEntrati = {};
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
  Map<String, PartecipanteGruppo> get snapshotRidersCompleti => _snapshotRidersCompleti;
  LeaderEngine get leaderEngine => _leaderEngine;
  Map<String, PosizioneGps> get ultimePosizioni => _ultimePosizioni;
  List<PartecipanteGruppo> get tuttiIMembriGruppo => _tuttiIMembriGruppo;

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

    // 1. Imposta partecipazione attiva tramite Transport
    await _transport.aggiornaPartecipazione(idGruppo, mioUid, true);

    // 2. Recovery per il Leader: ripristina lo Snake esistente per garantire continuità
    if (mioRuolo == RuoloGruppo.leader && !DebugManager().gpsFake) {
      final statoEsistente = await _transport.ottieniSnakeState(idGruppo);
      if (statoEsistente != null) {
        _leaderEngine.ripristinaStato(statoEsistente.punti, statoEsistente.leaderSequenceId);
        _ultimoSnakeStateInviato = statoEsistente;
        
        // 5. Chiede alla Scopa: "quali avanzamenti Rider mi sono perso?"
        // 6. La Scopa restituisce gli avanzamenti
        final avanzamentiScopa = await _transport.ottieniProgressBackup(idGruppo);
        if (avanzamentiScopa.isNotEmpty) {
          // 7. Il Leader aggiorna il proprio stato interno
          _snakeManager.ripristinaAvanzamentiRider(avanzamentiScopa, statoEsistente.punti);
          avanzamentiScopa.forEach((uid, lastIdx) {
            final p = _snakeManager.ottieniProgress(uid);
            if (p != null) {
              _progressi[uid] = p;
            }
          });
        }
        
        // 8. Il Leader ricalcola la situazione
        _processaMotoreV3();
        
        debugPrint('[GEOREF] Recovery completato: ripreso da seq=${statoEsistente.leaderSequenceId} con ${avanzamentiScopa.length} avanzamenti Scopa');
      }
    }

    // 3. Inizializza sorgente dati (Real / Fake)
    _cambiaSorgenteGps(!DebugManager().gpsFake);
    
    notifyListeners();
  }

  /// Ferma il sistema GeoRef (Abbandona Carovana).
  Future<void> stop() async {
    if (!_isAttivo) return;

    if (_idGruppoCorrente != null && _mioUid != null) {
      await _transport.aggiornaPartecipazione(_idGruppoCorrente!, _mioUid!, false);
    }

    _isAttivo = false;
    _subscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _fakeGps.fermaSimulazione();

    _leaderEngine.reset();
    _followerEngine.reset();
    _ultimoSnakeStateInviato = null;
    _ultimiAvanzamentiInviati = null;
    _snakeStateRicevuto = null;
    _snakeSubscription?.cancel();
    _mioRuolo = null;
    _snapshotRidersCompleti.clear();
    _ultimePosizioni.clear();
    _progressi.clear();
    _messaggiNavigazione.clear();
    _avvisiAttivi.clear();
    _tailState = null;
    _tuttiIMembriGruppo.clear();
    _uidsVirtualiEntrati.clear();

    notifyListeners();
  }

  void _cambiaSorgenteGps(bool reale) {
    _subscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _snakeSubscription?.cancel();
    _fakeGps.fermaSimulazione();

    if (reale && _idGruppoCorrente != null && _mioUid != null) {
      _subscription = _transport.streamPosizioni(_idGruppoCorrente!).listen((mappaPartecipanti) {
        _aggiornaDatiEProcessa(mappaPartecipanti);
      });

      _avviaBroadcastGpsReale();

      // Sincronizzazione SnakeState per i Follower (Rider/Scopa)
      if (_mioRuolo != RuoloGruppo.leader) {
        _snakeSubscription = _transport.streamSnakeState(_idGruppoCorrente!).listen((stato) {
          _snakeStateRicevuto = stato;
          _processaMotoreV3(); // Forza ricalcolo all'arrivo dello stato
        });
      }

      _gpsStatusSubscription = _transport.streamStatoGps.listen((attivo) {
        _gpsDisabilitato = !attivo;
        notifyListeners();
      });
    } else {
      _fakeGps.impostaPuntoPartenza(DebugManager().latFake, DebugManager().lonFake);
      
      if (_idGruppoCorrente != null) {
        // 1. Stream per avere sempre la lista aggiornata di chi FA PARTE del gruppo (tramite transport)
        _subscription = _transport.streamPosizioni(_idGruppoCorrente!).map((m) => m.values.toList()).listen((membri) {
          _tuttiIMembriGruppo.clear();
          _tuttiIMembriGruppo.addAll(membri);
          _fakeGps.aggiornaMembriSimulazione(membri);
          
          // Forza noi stessi tra quelli entrati virtualmente all'inizio se vogliamo vederci subito
          if (_uidsVirtualiEntrati.isEmpty && _mioUid != null) {
            _uidsVirtualiEntrati.add(_mioUid!);
          }
          
          notifyListeners();
        });

        // 2. Ascoltiamo il simulatore ma filtriamo solo chi è "Entrato" tramite debug
        _localGpsSubscription = _fakeGps.streamPosizioni.listen((posizioni) {
          final Map<String, PartecipanteGruppo> mockMappa = {};
          
          for (var riderOriginale in _tuttiIMembriGruppo) {
            final uid = riderOriginale.idUtente;
            if (_uidsVirtualiEntrati.contains(uid)) {
              final gps = posizioni[uid];
              if (gps != null) {
                mockMappa[uid] = riderOriginale.copiaCon(
                  partecipando: true,
                  online: true,
                  posizioneGps: gps,
                );
              }
            }
          }
          _aggiornaDatiEProcessa(mockMappa);
        });
      }
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
    String leaderKey = 'leader';
    String scopaKey = 'scopa';

    if (!DebugManager().gpsFake) {
      leaderKey = _snapshotRidersCompleti.values
          .firstWhereOrNull((p) => p.ruolo == RuoloGruppo.leader)?.idUtente ?? '';
      scopaKey = _snapshotRidersCompleti.values
          .firstWhereOrNull((p) => p.ruolo == RuoloGruppo.scopa)?.idUtente ?? '';
    }

    final leaderPos = _ultimePosizioni[leaderKey];
    final partecipantiAttivi = _snapshotRidersCompleti.values.where((p) => p.partecipando).toList();

    bool snakeCambiato = false;
    final List<RoutePoint> traccia;
    final int leaderSeqId;

    if (_mioRuolo == RuoloGruppo.leader || DebugManager().gpsFake) {
      // 1. Autorità: Calcolo Snake Locale
      if (leaderPos != null) {
        final puntoAggiunto = _leaderEngine.processaPosizioneLeader(leaderPos, partecipantiAttivi.length);
        if (puntoAggiunto != null) {
          snakeCambiato = true;
        }
      }
      traccia = _leaderEngine.ottieniRoutePoints();
      leaderSeqId = _leaderEngine.ultimoRoutePoint()?.sequenceId ?? 0;
    } else {
      // 1. Consumatore: Uso SnakeState ricevuto da Firestore
      traccia = _snakeStateRicevuto?.punti ?? [];
      leaderSeqId = _snakeStateRicevuto?.leaderSequenceId ?? 0;
    }

    final bool snakeValido = traccia.length >= 2;

    // 2. Inseguimento Snake e Inizializzazione Progressi
    for (var rider in partecipantiAttivi) {
      final uid = rider.idUtente;
      if (rider.posizioneGps != null && snakeValido) {
        _progressi[uid] = _followerEngine.aggiornaPosizionePartecipante(
          uid: uid,
          pos: rider.posizioneGps!,
          traccia: traccia,
          leaderSequenceId: leaderSeqId,
        );
      } else {
        // Se non ha posizione o snake non ancora pronto, creiamo un progresso placeholder per visibilità
        _progressi[uid] = _progressi[uid] ?? RouteProgress(
          uid: uid,
          lastValidatedIndex: -1,
          nextTargetIndex: 0,
          ultimoAggiornamento: DateTime.now(),
          ultimaPosizioneGps: rider.posizioneGps ?? PosizioneGps(
            latitudine: 0, 
            longitudine: 0, 
            ultimoAggiornamento: DateTime.now()
          ),
        );
      }
    }

    // 3. Calcolo TailState
    _tailState = _snakeManager.calcolaTailState();

    // 4. Garbage Collection (Solo Autorità)
    if (partecipantiAttivi.isNotEmpty && snakeValido && (_mioRuolo == RuoloGruppo.leader || DebugManager().gpsFake)) {
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

      // BUG FIX (STEP 7): Filtriamo solo i sequenceId effettivamente presenti in traccia
      // che sono inferiori o uguali al minimo validato. Evita assunzioni su sequenza 0-N.
      final completedIds = minValidatedIndex >= 0 
          ? traccia.where((p) => p.sequenceId <= minValidatedIndex).map((p) => p.sequenceId).toList()
          : <int>[];

      final statsGC = _leaderEngine.eseguiGarbageCollection(
        completedSequenceIds: completedIds,
        distanzaMassimaGruppo: _config.distanzaMassimaGruppo,
      );
      if ((statsGC['passed'] ?? 0) > 0 || (statsGC['distance'] ?? 0) > 0) {
        snakeCambiato = true;
      }
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
        
        final targetPoint = traccia.firstWhereOrNull((pt) => pt.sequenceId == p.nextTargetIndex);

        _messaggiNavigazione[uid] = _waypointManager.ottieniIstruzioneNavigazione(
          rider.posizioneGps!, targetPoint, _config.triggerDistanceMeters, p.engineState
        );
      }
    });

    // 6. Autorità Leader: Pubblicazione SnakeState (Solo se reale cambiamento)
    _gestisciPubblicazioneSnakeState(traccia, leaderSeqId, snakeCambiato);
    
    // 6b. Supporto Scopa: Pubblicazione Avanzamenti (Stato osservazionale di backup)
    _gestisciPubblicazioneAvanzamentiScopa();
  }

  void _gestisciPubblicazioneAvanzamentiScopa() {
    if (_idGruppoCorrente == null || _mioRuolo != RuoloGruppo.scopa) return;
    if (DebugManager().gpsFake) return; // Non pubblichiamo in modalità fake

    final Map<String, int> avanzamentiCorrenti = {};
    _progressi.forEach((uid, prog) {
      if (prog.lastValidatedIndex >= 0) {
        avanzamentiCorrenti[uid] = prog.lastValidatedIndex;
      }
    });

    bool cambiato = _ultimiAvanzamentiInviati == null ||
        _ultimiAvanzamentiInviati!.length != avanzamentiCorrenti.length;
        
    if (!cambiato && _ultimiAvanzamentiInviati != null) {
      for (var entry in avanzamentiCorrenti.entries) {
        if (_ultimiAvanzamentiInviati![entry.key] != entry.value) {
          cambiato = true;
          break;
        }
      }
    }

    if (cambiato) {
      _ultimiAvanzamentiInviati = Map.from(avanzamentiCorrenti);
      _transport.pubblicaProgressBackup(_idGruppoCorrente!, avanzamentiCorrenti);
      debugPrint('[GEOREF] Avanzamenti Scopa pubblicati: $avanzamentiCorrenti');
    }
  }

  void _gestisciPubblicazioneSnakeState(List<RoutePoint> traccia, int leaderSeqId, bool cambiato) {
    if (_idGruppoCorrente == null || _mioRuolo != RuoloGruppo.leader) return;
    if (DebugManager().gpsFake) return; // Non pubblichiamo in modalità fake per ora

    // Se non abbiamo mai inviato nulla e la traccia non è vuota, forziamo il cambiamento
    if (_ultimoSnakeStateInviato == null && traccia.isNotEmpty) {
      cambiato = true;
    }

    if (cambiato) {
      final nuovoStato = SnakeState(
        version: (_ultimoSnakeStateInviato?.version ?? 0) + 1,
        timestamp: DateTime.now(),
        punti: traccia,
        leaderSequenceId: leaderSeqId,
      );
      _ultimoSnakeStateInviato = nuovoStato;
      _transport.pubblicaSnakeState(_idGruppoCorrente!, nuovoStato);
      debugPrint('[GEOREF] SnakeState pubblicato v=${nuovoStato.version} punti=${traccia.length}');
    }
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
      if (_idGruppoCorrente != null && _mioUid != null) {
        _transport.pubblicaPosizione(_idGruppoCorrente!, _mioUid!, pos);
      }
    });
  }

  /// Sposta un rider in modalità FAKE (chiamato dal simulatore UI).
  void muoviRiderFake(String riderId, String direzione, double metri) {
    if (!DebugManager().gpsFake) return;

    final posAttuale = _ultimePosizioni[riderId] ?? PosizioneGps(
      latitudine: DebugManager().latFake,
      longitudine: DebugManager().lonFake,
      ultimoAggiornamento: DateTime.now(),
    );

    double dLat = 0.0;
    double dLon = 0.0;
    final double offsetGradi = metri / 111320.0;

    if (direzione.contains("N")) dLat = offsetGradi;
    if (direzione.contains("S")) dLat = -offsetGradi;
    if (direzione.contains("E")) dLon = offsetGradi;
    if (direzione.contains("W")) dLon = -offsetGradi;

    final nuovaPos = PosizioneGps(
      latitudine: posAttuale.latitudine + dLat,
      longitudine: posAttuale.longitudine + dLon,
      ultimoAggiornamento: DateTime.now(),
      direzione: posAttuale.direzione,
    );

    // 1. Notifica il simulatore fake della nuova posizione manuale
    _fakeGps.aggiornaPosizioneManuale(riderId, nuovaPos);

    // 2. Iniettiamo la posizione direttamente per reattività immediata
    _ultimePosizioni[riderId] = nuovaPos;
    
    // Aggiorniamo lo snap dei rider per coerenza mantenendo il ruolo reale
    final riderEsistente = _snapshotRidersCompleti[riderId];
    _snapshotRidersCompleti[riderId] = (riderEsistente ?? PartecipanteGruppo(
      idUtente: riderId,
      ruolo: RuoloGruppo.partecipante,
    )).copiaCon(
      partecipando: true,
      posizioneGps: nuovaPos,
    );

    _processaMotoreV3();
    notifyListeners();
  }

  /// Forza un aggiornamento della sorgente (chiamato dal DebugManager)
  void ricaricaSorgenteGps() {
    if (_isAttivo) {
      _cambiaSorgenteGps(!DebugManager().gpsFake);
    }
  }

  void forzaIngressoRider(String riderId) {
    _uidsVirtualiEntrati.add(riderId);
    muoviRiderFake(riderId, "N", 0); // Posizione base
  }

  void forzaUscitaRider(String riderId) {
    _uidsVirtualiEntrati.remove(riderId);
    _ultimePosizioni.remove(riderId);
    _snapshotRidersCompleti.remove(riderId);
    _progressi.remove(riderId);
    _processaMotoreV3();
    notifyListeners();
  }

}
