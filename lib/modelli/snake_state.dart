import 'route_point.dart';

  /// Rappresenta lo stato operativo attuale dello Snake per la carovana.
/// Definisce la "finestra attiva" dei punti che i Rider devono seguire.
class SnakeState {
  final int version;
  final DateTime timestamp;
  final List<RoutePoint> punti;
  final int leaderSequenceId;

  SnakeState({
    required this.version,
    required this.timestamp,
    required List<RoutePoint> punti,
    required this.leaderSequenceId,
  }) : punti = List.unmodifiable(punti);

  /// Crea uno SnakeState da una mappa Firestore.
  factory SnakeState.daMappa(Map<String, dynamic> mappa) {
    final listaPuntiMappa = mappa['punti'] as List<dynamic>? ?? [];
    
    DateTime convertiData(dynamic data) {
      if (data == null) return DateTime.now();
      if (data is DateTime) return data;
      try {
        return data.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    final puntiRecuperati = listaPuntiMappa.map((p) {
      final pMappa = p as Map<String, dynamic>;
      final id = pMappa['id'] ?? '';
      return RoutePoint.daMappa(pMappa, id);
    }).toList();

    return SnakeState(
      version: mappa['version'] ?? 0,
      timestamp: convertiData(mappa['timestamp']),
      punti: puntiRecuperati,
      leaderSequenceId: mappa['leaderSequenceId'] ?? 0,
    );
  }

  /// Converte lo SnakeState in una mappa per Firestore.
  Map<String, dynamic> aMappa() {
    return {
      'version': version,
      'timestamp': timestamp,
      'punti': punti.map((p) {
        final mappaPunto = p.aMappa();
        mappaPunto['id'] = p.id;
        return mappaPunto;
      }).toList(),
      'leaderSequenceId': leaderSequenceId,
    };
  }

  /// Crea una copia dello stato con campi modificati (Immutabilità).
  SnakeState copiaCon({
    int? version,
    DateTime? timestamp,
    List<RoutePoint>? punti,
    int? leaderSequenceId,
  }) {
    return SnakeState(
      version: version ?? this.version,
      timestamp: timestamp ?? this.timestamp,
      punti: punti ?? this.punti,
      leaderSequenceId: leaderSequenceId ?? this.leaderSequenceId,
    );
  }
}
