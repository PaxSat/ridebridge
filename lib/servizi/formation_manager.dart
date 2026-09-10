import '../modelli/avviso_carovana.dart';
import '../modelli/engine_state.dart';
import '../modelli/stato_carovana.dart';

/// Servizio reporter per la carovana (GeoRef V2).
/// Trasforma gli stati del motore in avvisi per l'utente.
class FormationManager {
  /// Genera un oggetto [AvvisoCarovana] basato sullo stato calcolato dallo Snake Engine.
  AvvisoCarovana? generaAvviso(String idUtente, EngineState engineState, StatoCarovana statoCarovana) {
    String messaggio = "";
    TipoAvvisoCarovana? tipo;

    // Priorità agli stati bloccanti del motore (OffRoute)
    if (engineState == EngineState.offRoute) {
      tipo = TipoAvvisoCarovana.offRoute;
      messaggio = "Sei fuori percorso. Torna verso il leader.";
    } 
    // Segue la logica della carovana calcolata topologicamente
    else {
      switch (statoCarovana) {
        case StatoCarovana.aheadOfLeader:
          tipo = TipoAvvisoCarovana.aheadOfLeader;
          messaggio = "Attenzione. Sei avanti al leader. Rientra in formazione.";
          break;
        case StatoCarovana.behindSweeper:
          tipo = TipoAvvisoCarovana.behindSweeper;
          messaggio = "Attenzione. Sei dietro la scopa. Rientra nel gruppo.";
          break;
        case StatoCarovana.groupBroken:
          tipo = TipoAvvisoCarovana.groupBroken;
          messaggio = "Gruppo spezzato. Leader troppo distante.";
          break;
        default:
          return null;
      }
    }

    if (tipo == null) return null;

    return AvvisoCarovana(
      idUtente: idUtente,
      tipo: tipo,
      timestamp: DateTime.now(),
      messaggio: messaggio,
    );
  }
}
