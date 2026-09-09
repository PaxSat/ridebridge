/// Definisce i tipi di anomalie o avvisi relativi alla formazione del gruppo.
enum TipoAvvisoCarovana {
  aheadOfLeader,
  behindSweeper,
  offRoute,
  groupBroken,
}

/// Rappresenta un avviso generato dal motore di georeferenziazione.
class AvvisoCarovana {
  final String idUtente;
  final TipoAvvisoCarovana tipo;
  final DateTime timestamp;
  final String messaggio;

  AvvisoCarovana({
    required this.idUtente,
    required this.tipo,
    required this.timestamp,
    required this.messaggio,
  });
}
