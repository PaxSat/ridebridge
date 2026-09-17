import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/avviso_carovana.dart';
import '../modelli/route_progress.dart';
import '../modelli/tail_state.dart';
import '../modelli/configurazione_gruppo.dart';
import 'package:collection/collection.dart';
import 'servizio_posizione_fake.dart';
import 'georef_transport.dart';
import 'route_track_manager.dart';
import 'snake_formation_manager.dart';
import 'formation_manager.dart';
import 'waypoint_manager.dart';
import 'leader_engine.dart';
import 'follower_engine.dart';
import 'debug_manager.dart';
import 'servizio_gruppi.dart';
import '../modelli/route_point.dart';
import '../modelli/snake_state.dart';
import '../modelli/rider_stream_data.dart';

/// Controller persistente per la gestione della Georeferenziazione (GeoRef V3).
/// Gestisce il ciclo di vita dei motori indipendentemente dalle schermate UI.
class GeoRefController extends ChangeNotifier {
  static final GeoRefController _instance = GeoRefController._internal();
  factory GeoRefController() => _instance;
  GeoRefController._internal();

  late final GeorefTransport _transport;
  final _fakeGps = ServizioPosizioneFake();
  final _trackManager = RouteTrackManager();
  final _snakeManager = SnakeFormationManager();
  final _formation = FormationManager();
  final _waypointManager = WaypointManager();
  final _config = ConfigurazioneGruppo();

  late final LeaderEngine _leaderEngine = LeaderEngine(_trackManager);
  late final FollowerEngine _followerEngine = FollowerEngine(_snakeManager);

  StreamSubscription? _subscription;
  StreamSubscription? _groupSubscription;
  StreamSubscription? _localGpsSubscription;
  StreamSubscription<bool>? _gpsStatusSubscription;

  // Stato Operativo
  bool _isAttivo = false;
  bool _sessioneAvviataConPartecipanti = false; // Per Auto-Ghost
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
  final Map<String, int> _indiciCertificati = {};
  final Map<String, RouteProgress> _progressi = {};
  final Map<String, String?> _messaggiNavigazione = {};
  final Map<String, AvvisoCarovana?> _avvisiAttivi = {};
  TailState? _tailState;
  bool _gpsDisabilitato = false;

  /// Inizializza il transport layer (Dependency Injection).
  /// Deve essere chiamato prima di start().
  void initialize(GeorefTransport transport) {
    _transport = transport;
    
    // Sincronizzazione iniziale stato Ghost
    _leaderEngine.ghostSnake = DebugManager().ghostSnake;
  }

  /// Attiva o disattiva la modalità Ghost Snake (generazione traccia in solitaria).
  void impostaGhostSnake(bool attivo) {
    DebugManager().ghostSnake = attivo;
    _leaderEngine.ghostSnake = attivo;
    _processaMotoreV3(); // Ricalcola subito per vedere se può generare punti
    notifyListeners();
  }

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

  /// Restituisce la lista dei rider effettivamente attivi nella carovana.
  List<PartecipanteGruppo> get riderPartecipanti {
    final List<PartecipanteGruppo> attivi = [];
    
    // Iniziamo controllando se ci siamo noi (Leader locale o Rider attivo)
    if (_mioUid != null && _isAttivo) {
      final me = _snapshotRidersCompleti[_mioUid!];
      if (me != null) {
        bool isLeader = me.ruolo == RuoloGruppo.leader;
        if (DebugManager().gpsFake) {
          if (_uidsVirtualiEntrati.contains(_mioUid!) || isLeader) {
            attivi.add(me);
          }
        } else {
          if (me.partecipando || isLeader) {
            attivi.add(me);
          }
        }
      }
    }

    // Aggiungiamo gli altri rider dalla cache
    for (var p in _snapshotRidersCompleti.values) {
      if (p.idUtente == _mioUid) continue; // Già gestito sopra

      bool isLeader = p.ruolo == RuoloGruppo.leader;
      if (DebugManager().gpsFake) {
        if (_uidsVirtualiEntrati.contains(p.idUtente) || isLeader) {
          attivi.add(p);
        }
      } else {
        if (p.partecipando) {
          attivi.add(p);
        }
      }
    }
    
    return attivi;
  }

  /// Avvia il sistema GeoRef (Bootstrap Reale).
  Future<void> start({
    required String idGruppo,
    required String mioUid,
    required RuoloGruppo mioRuolo,
    ConfigurazioneGruppo? configurazione,
  }) async {
    if (_isAttivo) return;

    _idGruppoCorrente = idGruppo;
    _mioUid = mioUid;
    _mioRuolo = mioRuolo;
    _isAttivo = true;

    // Sincronizzazione soglie tracciamento
    final config = configurazione ?? _config;
    _trackManager.aggiornaSoglie(config.snakeDistanceMeters, config.snakeTimeSeconds, config.turnThresholdAngle);
    _leaderEngine.ghostSnake = DebugManager().ghostSnake;
    _leaderEngine.distanzaMassimaGhost = config.distanzaMassimaGhost;
    _sessioneAvviataConPartecipanti = false; 

    // Forza ingresso immediato nella cache locale per reattività UI
    _snapshotRidersCompleti[mioUid] = PartecipanteGruppo(
      idUtente: mioUid,
      ruolo: mioRuolo,
      partecipando: true,
      online: true,
    );

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
    
    // Attiva Wakelock per mantenere lo schermo acceso
    WakelockPlus.enable();
    
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
    _groupSubscription?.cancel();
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
    _indiciCertificati.clear();
    _progressi.clear();
    _messaggiNavigazione.clear();
    _avvisiAttivi.clear();
    _tailState = null;
    _tuttiIMembriGruppo.clear();
    _uidsVirtualiEntrati.clear();

    // Disattiva Wakelock
    WakelockPlus.disable();

    notifyListeners();
  }

  void _cambiaSorgenteGps(bool reale) {
    _subscription?.cancel();
    _groupSubscription?.cancel();
    _localGpsSubscription?.cancel();
    _gpsStatusSubscription?.cancel();
    _snakeSubscription?.cancel();
    _fakeGps.fermaSimulazione();

    if (reale && _idGruppoCorrente != null && _mioUid != null) {
      // 1. Ascolto dati di GESTIONE (Firestore - Ruoli, Nomi)
      _groupSubscription = ServizioGruppi().streamPartecipanti(_idGruppoCorrente!).listen((membri) {
        _aggiornaAnagraficaMembri(membri);
      });

      // 2. Ascolto dati di STREAM (Transport - GPS, Progresso)
      _subscription = _transport.streamPosizioni(_idGruppoCorrente!).listen((mappaStream) {
        _aggiornaDatiStreamEProcessa(mappaStream);
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
      // MODALITÀ FAKE: Transizione (Espulsione e Reset DB)
      if (_idGruppoCorrente != null) {
        final sg = ServizioGruppi();
        sg.cancellaEventiPercorso(_idGruppoCorrente!); // Reset DB di viaggio (Punti + Stati)
      }

      _fakeGps.impostaPuntoPartenza(DebugManager().latFake, DebugManager().lonFake);
      
      // RESET TOTALE LOCAL CACHE per pulizia laboratorio
      _uidsVirtualiEntrati.clear();
      _snapshotRidersCompleti.clear();
      _ultimePosizioni.clear();
      _progressi.clear();
      _leaderEngine.reset();
      _followerEngine.reset();

      if (_idGruppoCorrente != null) {
        // 1. Stream per avere sempre la lista aggiornata di chi FA PARTE del gruppo (Firestore)
        _groupSubscription = ServizioGruppi().streamPartecipanti(_idGruppoCorrente!).listen((membri) {
          _tuttiIMembriGruppo.clear();
          _tuttiIMembriGruppo.addAll(membri);
          _fakeGps.aggiornaMembriSimulazione(membri);
          
          // In modalità FAKE, non popoliamo _snapshotRidersCompleti qui.
          // Aspettiamo che l'utente prema "ENTRA RIDER".
          notifyListeners();
        });

        // 2. Ascoltiamo il simulatore
        _localGpsSubscription = _fakeGps.streamPosizioni.listen((posizioni) {
          final Map<String, RiderStreamData> streamMap = {};
          
          for (var uid in _uidsVirtualiEntrati) {
            final gps = posizioni[uid];
            if (gps != null) {
              _ultimePosizioni[uid] = gps;
              
              streamMap[uid] = RiderStreamData(
                uid: uid,
                posizioneGps: gps,
                lastValidatedIndex: _progressi[uid]?.lastValidatedIndex,
                timestamp: DateTime.now(),
              );
            }
          }
          
          if (streamMap.isNotEmpty) {
            _aggiornaDatiStreamEProcessa(streamMap);
          }
        });
      }
      _fakeGps.avviaSimulazione();
    }
  }

  void _aggiornaAnagraficaMembri(List<PartecipanteGruppo> membri) {
    // Aggiorna l'anagrafica stabile (Ruoli, online, partecipando)
    for (var m in membri) {
      _snapshotRidersCompleti[m.idUtente] = m;
    }
    
    // Rimuoviamo chi non è più nel gruppo Firestore
    final uidsAttuali = membri.map((e) => e.idUtente).toSet();
    _snapshotRidersCompleti.removeWhere((uid, _) {
      // PROTEZIONE: Non rimuovere mai se stessi se l'engine è attivo
      if (uid == _mioUid && _isAttivo) return false;
      return !uidsAttuali.contains(uid);
    });

    _processaMotoreV3();
    notifyListeners();
  }

  void _aggiornaDatiStreamEProcessa(Map<String, RiderStreamData> mappaStream) {
    // Integra i dati di stream (GPS, progresso)
    mappaStream.forEach((uid, stream) {
      _ultimePosizioni[uid] = stream.posizioneGps;
      if (stream.lastValidatedIndex != null) {
        _indiciCertificati[uid] = stream.lastValidatedIndex!;
      }
    });

    _processaMotoreV3();
    notifyListeners();
  }

  void _processaMotoreV3() {
    // Identificazione sicura del Leader e della Scopa (anche in modalità Fake)
    final leaderKey = _snapshotRidersCompleti.values
            .firstWhereOrNull((p) => p.ruolo == RuoloGruppo.leader)
            ?.idUtente ??
        'leader';
    final scopaKey = _snapshotRidersCompleti.values
            .firstWhereOrNull((p) => p.ruolo == RuoloGruppo.scopa)
            ?.idUtente ??
        'scopa';

    final leaderPos = _ultimePosizioni[leaderKey];
    
    // Filtriamo i partecipanti che stanno effettivamente partecipando.
    final partecipantiAttivi = riderPartecipanti;

    // Gestione LOGICA AUTO-GHOST
    if (partecipantiAttivi.length > 1) {
      _sessioneAvviataConPartecipanti = true;
    }
    
    if (_mioRuolo == RuoloGruppo.leader && partecipantiAttivi.length <= 1 && _sessioneAvviataConPartecipanti) {
      _leaderEngine.autoGhostActive = true;
    }

    bool snakeCambiato = false;
    final List<RoutePoint> traccia;
    final int leaderSeqId;
    final bool isFakeMode = DebugManager().gpsFake;

    if (_mioRuolo == RuoloGruppo.leader || isFakeMode) {
      // 1. Autorità: Calcolo Snake Locale
      if (leaderPos != null) {
        final puntoAggiunto = _leaderEngine.processaPosizioneLeader(
          leaderPos, 
          partecipantiAttivi.length,
          ignoreTimeThreshold: isFakeMode,
        );
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
      final pos = _ultimePosizioni[uid];
      
      // LOGICA AUTORITÀ DI PROGRESSO:
      if (uid == _mioUid) {
        if (pos != null && snakeValido) {
          _progressi[uid] = _followerEngine.aggiornaPosizionePartecipante(
            uid: uid,
            pos: pos,
            traccia: traccia,
            leaderSequenceId: leaderSeqId,
          );
        }
      } else if (_mioRuolo == RuoloGruppo.leader || DebugManager().gpsFake) {
        // Sono il Leader o in modalità Fake: gestiamo il progresso
        final lastIdx = _indiciCertificati[uid];
        if (lastIdx != null && lastIdx >= 0) {
          final p = traccia.firstWhereOrNull((pt) => pt.sequenceId == lastIdx);
          _progressi[uid] = RouteProgress(
            uid: uid,
            lastValidatedIndex: lastIdx,
            lastValidatedId: p?.id,
            nextTargetIndex: lastIdx + 1,
            routeProgress: p?.distanzaProgressiva ?? 0.0,
            ultimoAggiornamento: DateTime.now(),
            ultimaPosizioneGps: pos ?? PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: DateTime.now()),
          );
        } else if (pos != null && snakeValido) {
          _progressi[uid] = _followerEngine.aggiornaPosizionePartecipante(
            uid: uid,
            pos: pos,
            traccia: traccia,
            leaderSequenceId: leaderSeqId,
          );
        }
      }

      // PROTEZIONE INCOERENZA METRI (Fix per i 13km fantasma)
      final progAttuale = _progressi[uid];
      if (progAttuale == null || progAttuale.lastValidatedIndex == -1) {
        _progressi[uid] = RouteProgress(
          uid: uid,
          lastValidatedIndex: -1,
          nextTargetIndex: 0,
          routeProgress: 0.0, // Forza 0 metri finché non si aggancia
          ultimoAggiornamento: DateTime.now(),
          ultimaPosizioneGps: pos ?? PosizioneGps(latitudine: 0, longitudine: 0, ultimoAggiornamento: DateTime.now()),
        );
      }
    }

    // 3. Calcolo TailState (Autorità del Leader o Simulatore)
    // Sincronizziamo la mappa globale dei progressi con lo SnakeManager prima del calcolo
    _snakeManager.sincronizzaInteraMappaProgressi(_progressi);
    _tailState = _snakeManager.calcolaTailState(partecipantiAttivi.map((e) => e.idUtente).toList());

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

      // Verifichiamo se la coda è rientrata nell'area "Normal"
      final leaderProgress = _progressi[leaderKey]?.routeProgress ?? 0.0;
      final tailProgress = _tailState?.tailIndex != null 
          ? traccia.firstWhereOrNull((pt) => pt.sequenceId == _tailState!.tailIndex)?.distanzaProgressiva ?? 0.0
          : 0.0;
      final bool codaInAreaNormal = (leaderProgress - tailProgress) <= _config.distanzaMassimaGruppo;

      final statsGC = _leaderEngine.eseguiGarbageCollection(
        completedSequenceIds: completedIds,
        distanzaMassimaGruppo: _config.distanzaMassimaGruppo,
        codaInAreaNormal: codaInAreaNormal,
      );
      if ((statsGC['passed'] ?? 0) > 0 || (statsGC['distance'] ?? 0) > 0) {
        snakeCambiato = true;
      }
    }

    // 5. Analisi Stati e Navigazione
    final leaderProgress = _progressi[leaderKey]?.routeProgress ?? 0.0;
    final scopaProgress = _progressi[scopaKey]?.routeProgress;

    _snapshotRidersCompleti.forEach((uid, rider) {
      final pos = _ultimePosizioni[uid];
      if (rider.partecipando && pos != null) {
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
          pos, targetPoint, _config.triggerDistanceMeters, p.engineState
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

    // Se non abbiamo mai inviato nulla e la traccia non è vuota, forziamo le cambiamento
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
        final mioProgresso = _progressi[_mioUid];
        _transport.pubblicaPosizione(
          _idGruppoCorrente!, 
          _mioUid!, 
          pos, 
          lastValidatedIndex: mioProgresso?.lastValidatedIndex
        );
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
    
    // Correzione Diagonali: se ci muoviamo in diagonale, dobbiamo usare il seno/coseno di 45 gradi (0.707)
    // per far sì che lo spostamento totale (l'ipotenusa) sia esattamente pari ai metri scelti.
    final bool isDiagonal = direzione.length == 2; // NE, NW, SE, SW
    final double spostamentoEffettivo = isDiagonal ? (metri * 0.7071) : metri;
    final double offsetGradi = spostamentoEffettivo / 111320.0;

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
    
    // Recuperiamo il membro reale dalla cache per preservarne il RUOLO
    final riderReale = _tuttiIMembriGruppo.firstWhereOrNull((m) => m.idUtente == riderId);
    
    _snapshotRidersCompleti[riderId] = (riderReale ?? PartecipanteGruppo(
      idUtente: riderId,
      ruolo: RuoloGruppo.partecipante,
    )).copiaCon(
      partecipando: true,
      online: true,
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
    
    // Recuperiamo l'anagrafica reale per non perdere il RUOLO
    final mReale = _tuttiIMembriGruppo.firstWhereOrNull((m) => m.idUtente == riderId);
    _snapshotRidersCompleti[riderId] = (mReale ?? PartecipanteGruppo(idUtente: riderId, ruolo: RuoloGruppo.partecipante)).copiaCon(
      partecipando: true,
      online: true,
    );

    // Coordinate iniziali dal pannello debug
    final nuovaPos = PosizioneGps(
      latitudine: DebugManager().latFake,
      longitudine: DebugManager().lonFake,
      ultimoAggiornamento: DateTime.now(),
    );
    
    _ultimePosizioni[riderId] = nuovaPos;
    _fakeGps.aggiornaPosizioneManuale(riderId, nuovaPos);
    
    _processaMotoreV3();
    notifyListeners();
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
