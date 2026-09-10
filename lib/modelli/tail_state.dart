/// Rappresenta lo stato della coda tecnica della carovana.
class TailState {
  final int tailIndex; // L'indice del RoutePoint più arretrato tra i membri affidabili
  final String? tailUid; // UID del membro che sta facendo da "tappo" tecnico
  final bool isScopaReliable; // Indica se il riferimento è la Scopa ufficiale
  final DateTime timestamp;

  TailState({
    required this.tailIndex,
    this.tailUid,
    this.isScopaReliable = false,
    required this.timestamp,
  });

  /// Crea un'istanza iniziale vuota o di default.
  factory TailState.iniziale() => TailState(
    tailIndex: 0,
    timestamp: DateTime.now(),
  );
}
