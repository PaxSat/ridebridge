import '../modelli/snake_state.dart';
import '../modelli/posizione_gps.dart';
import '../modelli/rider_stream_data.dart';

/// Contratto astratto per il Transport Layer del sistema GeoRef.
/// Permette di disaccoppiare la logica dei motori dal fornitore di dati (Firebase, LiveKit, Mock, ecc.)
abstract class GeorefTransport {
  /// Aggiorna lo stato di partecipazione attiva (Carovana) dell'utente.
  Future<void> aggiornaPartecipazione(String idGruppo, String idUtente, bool partecipando);

  /// Pubblica lo stato del percorso (Snake) calcolato dal Leader.
  Future<void> pubblicaSnakeState(String idGruppo, SnakeState stato);

  /// Sottoscrizione allo stato del percorso (Snake) per Follower e Scopa.
  Stream<SnakeState?> streamSnakeState(String idGruppo);

  /// Recupera l'ultimo SnakeState salvato (Recovery).
  Future<SnakeState?> ottieniSnakeState(String idGruppo);

  /// Pubblica gli avanzamenti dei rider (Backup Scopa).
  Future<void> pubblicaProgressBackup(String idGruppo, Map<String, int> avanzamenti);

  /// Recupera gli avanzamenti salvati dalla Scopa (Recovery Leader).
  Future<Map<String, int>> ottieniProgressBackup(String idGruppo);

  /// Pubblica la propria posizione GPS e l'ultimo indice dello Snake validato.
  Future<void> pubblicaPosizione(String idGruppo, String idUtente, PosizioneGps posizione, {int? lastValidatedIndex});

  /// Stream delle posizioni e avanzamenti in tempo reale dei partecipanti.
  Stream<Map<String, RiderStreamData>> streamPosizioni(String idGruppo);

  /// Stream dello stato del servizio GPS (abilitato/disabilitato).
  Stream<bool> get streamStatoGps;
}
