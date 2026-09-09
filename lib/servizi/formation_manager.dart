/// Enum che definisce gli stati possibili di un rider nella formazione.
enum StatoCarovana {
  inGroup,
  aheadOfLeader,
  behindSweeper,
  offRoute,
}

/// Servizio per la gestione della coesione e dell'ordine della carovana.
class FormationManager {
  
  /// Verifica se la formazione del gruppo è corretta in base alle distanze.
  StatoCarovana verificaFormazione(String idUtente, double distanzaDalLeader, double distanzaDallaScopa) {
    return StatoCarovana.inGroup;
  }

  /// Identifica l'ultimo membro effettivo del gruppo (esclusa la scopa).
  String? ultimoMembroGruppo(List<String> idPartecipanti) {
    return null;
  }

  /// Invia notifiche o aggiorna lo stato globale della carovana.
  Future<void> aggiornaStatoCarovana(String idGruppo) async {
    // Logica di monitoraggio
  }
}
