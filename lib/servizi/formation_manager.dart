import '../modelli/configurazione_gruppo.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/avviso_carovana.dart';
import 'location_evaluator.dart';

/// Enum che definisce gli stati possibili di un rider nella formazione.
enum StatoCarovana {
  inGroup,
  aheadOfLeader,
  behindSweeper,
  offRoute,
  groupBroken,
}

/// Servizio per la gestione della coesione e dell'ordine della carovana.
class FormationManager {
  final _evaluator = LocationEvaluator();
  
  /// Analizza la posizione di un utente e restituisce lo stato attuale ed eventuali avvisi.
  StatoCarovana verificaFormazione({
    required String idUtente,
    required String idLeader,
    required String? idScopa,
    required PosizioneGps posizioneUtente,
    required PosizioneGps? posizioneLeader,
    required PosizioneGps? posizioneScopa,
    required ConfigurazioneGruppo config,
  }) {
    // 0. Verifica GROUP_BROKEN (Distanza Leader-Scopa troppo elevata)
    if (posizioneLeader != null && posizioneScopa != null) {
      double distLeaderScopa = _evaluator.distanzaTraDuePunti(
        posizioneLeader.latitudine, posizioneLeader.longitudine,
        posizioneScopa.latitudine, posizioneScopa.longitudine,
      );
      if (distLeaderScopa > config.distanzaMassimaScopa) {
        return StatoCarovana.groupBroken;
      }
    }

    // 1. Verifica AHEAD_OF_LEADER (solo se non sono il leader)
    if (posizioneLeader != null && idUtente != idLeader) {
       bool ahead = _evaluator.eAvantiAlLeader(
         posizioneUtente.latitudine, posizioneUtente.longitudine,
         posizioneLeader.latitudine, posizioneLeader.longitudine,
         posizioneLeader.direzione,
       );
       if (ahead) return StatoCarovana.aheadOfLeader;
    }

    // 2. Verifica BEHIND_SWEEPER (solo se non sono la scopa e se la scopa esiste)
    if (posizioneScopa != null && idUtente != idScopa) {
      bool behind = _evaluator.eDietroLaScopa(
        posizioneUtente.latitudine, posizioneUtente.longitudine,
        posizioneScopa.latitudine, posizioneScopa.longitudine,
        posizioneScopa.direzione,
      );
      
      if (behind) {
        double distScopa = _evaluator.distanzaDallaScopa(
          posizioneUtente.latitudine, posizioneUtente.longitudine,
          posizioneScopa.latitudine, posizioneScopa.longitudine,
        );
        if (distScopa > 30.0) return StatoCarovana.behindSweeper;
      }
    }

    // 3. Verifica OFF_ROUTE
    if (posizioneLeader != null) {
      double distLeader = _evaluator.distanzaDalLeader(
        posizioneUtente.latitudine, posizioneUtente.longitudine,
        posizioneLeader.latitudine, posizioneLeader.longitudine,
      );
      // Se sono troppo lontano dal leader e non sono "dietro" (perché gestito da behindSweeper)
      // assumiamo che siamo fuori rotta lateralmente.
      if (distLeader > config.distanzaMassimaScopa + config.offRouteThreshold) {
        return StatoCarovana.offRoute;
      }
    }

    return StatoCarovana.inGroup;
  }

  /// Genera un oggetto [AvvisoCarovana] basato sullo stato rilevato.
  AvvisoCarovana? generaAvviso(String idUtente, StatoCarovana stato) {
    if (stato == StatoCarovana.inGroup) return null;

    String messaggio = "";
    TipoAvvisoCarovana tipo;

    switch (stato) {
      case StatoCarovana.aheadOfLeader:
        tipo = TipoAvvisoCarovana.aheadOfLeader;
        messaggio = "Sei avanti al Leader! Rallenta.";
        break;
      case StatoCarovana.behindSweeper:
        tipo = TipoAvvisoCarovana.behindSweeper;
        messaggio = "Sei rimasto dietro la Scopa!";
        break;
      case StatoCarovana.offRoute:
        tipo = TipoAvvisoCarovana.offRoute;
        messaggio = "Sembri fuori percorso.";
        break;
      case StatoCarovana.groupBroken:
        tipo = TipoAvvisoCarovana.groupBroken;
        messaggio = "La carovana si è spezzata! Leader troppo lontano dalla Scopa.";
        break;
      default:
        return null;
    }

    return AvvisoCarovana(
      idUtente: idUtente,
      tipo: tipo,
      timestamp: DateTime.now(),
      messaggio: messaggio,
    );
  }
}
