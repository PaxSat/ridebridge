import '../modelli/evento_percorso.dart';
import '../modelli/posizione_gps.dart';
import 'location_evaluator.dart';

/// Definisce lo stato di un waypoint nel ciclo di vita della carovana.
enum WaypointStatus {
  attivo,
  completato,
}

/// Gestore del ciclo di vita dei waypoint (EventoPercorso).
/// Un waypoint viene rimosso solo dopo che l'ultimo membro della carovana lo ha superato.
class WaypointManager {
  final _evaluator = LocationEvaluator();
  final List<ManagedWaypoint> _managedWaypoints = [];
  
  // Soglia di distanza per considerare un punto come "superato" (metri)
  static const double _sogliaSuperamento = 40.0;

  List<ManagedWaypoint> get waypointsAttivi => 
      _managedWaypoints.where((w) => w.status == WaypointStatus.attivo).toList();

  List<ManagedWaypoint> get waypointsCompletati => 
      _managedWaypoints.where((w) => w.status == WaypointStatus.completato).toList();

  /// Aggiunge un nuovo waypoint alla gestione.
  void aggiungiWaypoint(EventoPercorso evento) {
    // Evita duplicati basati su ID
    if (!_managedWaypoints.any((w) => w.evento.id == evento.id)) {
      _managedWaypoints.add(ManagedWaypoint(evento: evento));
    }
  }

  /// Aggiorna il progresso dei partecipanti rispetto ai waypoint.
  /// Identifica l'ultimo membro e segna come completati i waypoint superati da tutti.
  void aggiornaProgresso(Map<String, PosizioneGps> posizioniMembri) {
    if (posizioniMembri.isEmpty) return;

    for (var managed in _managedWaypoints) {
      if (managed.status == WaypointStatus.completato) continue;

      for (var entry in posizioniMembri.entries) {
        final uid = entry.key;
        final pos = entry.value;

        if (!managed.partecipantiPassati.contains(uid)) {
          final distanza = _evaluator.distanzaTraDuePunti(
            pos.latitudine, pos.longitudine,
            managed.evento.latitudine, managed.evento.longitudine,
          );

          if (distanza < _sogliaSuperamento) {
            managed.partecipantiPassati.add(uid);
          }
        }
      }

      // Verifica se TUTTI i membri attuali hanno superato il waypoint
      if (managed.partecipantiPassati.length >= posizioniMembri.length) {
        managed.status = WaypointStatus.completato;
      }
    }
  }

  /// Identifica l'ultimo membro reale della carovana (colui che ha superato meno waypoint recenti).
  String? identificaUltimoMembro(Map<String, PosizioneGps> posizioniMembri) {
    if (posizioniMembri.isEmpty) return null;

    String? ultimoUid;
    int minWaypointsPassati = 999999;

    for (var uid in posizioniMembri.keys) {
      int contatore = 0;
      for (var w in _managedWaypoints) {
        if (w.partecipantiPassati.contains(uid)) contatore++;
      }
      
      if (contatore < minWaypointsPassati) {
        minWaypointsPassati = contatore;
        ultimoUid = uid;
      }
    }

    return ultimoUid;
  }

  /// Restituisce il prossimo waypoint che l'utente deve raggiungere e la relativa istruzione.
  /// Implementa 3 livelli di avviso per la navigazione.
  String? ottieniIstruzioneNavigazione(String uid, PosizioneGps posAttuale, double triggerDistance) {
    // Cerchiamo il primo waypoint attivo che l'utente non ha ancora superato
    final prossimi = _managedWaypoints.where((w) => 
        w.status == WaypointStatus.attivo && !w.partecipantiPassati.contains(uid)).toList();
    
    if (prossimi.isEmpty) return null;

    // Ordiniamo per timestamp per seguire l'ordine cronologico
    prossimi.sort((a, b) => a.evento.timestamp.compareTo(b.evento.timestamp));
    
    final prossimo = prossimi.first;
    final distanza = _evaluator.distanzaTraDuePunti(
      posAttuale.latitudine, posAttuale.longitudine,
      prossimo.evento.latitudine, prossimo.evento.longitudine,
    );

    // Identificazione direzione
    String direzione = prossimo.evento.tipoEvento == TipoEventoPercorso.svoltaDestra ? "destra" : 
                       prossimo.evento.tipoEvento == TipoEventoPercorso.svoltaSinistra ? "sinistra" : "inversione";

    // LIVELLO 3: Svolta (15 metri)
    if (distanza < 15) {
      return "Svolta a $direzione";
    } 
    // LIVELLO 2: Preparazione (40 metri)
    else if (distanza < 40) {
      return "Preparati alla svolta a $direzione";
    }
    // LIVELLO 1: Pre-avviso (triggerDistanceConfig)
    else if (distanza < triggerDistance) {
      return "Tra ${distanza.round()} metri svolta a $direzione";
    }
    
    return null;
  }

  /// Rimuove i waypoint completati per liberare memoria.
  void pulisciCompletati() {
    _managedWaypoints.removeWhere((w) => w.status == WaypointStatus.completato);
  }

  void reset() {
    _managedWaypoints.clear();
  }
}

/// Wrapper interno per gestire i metadati del waypoint.
class ManagedWaypoint {
  final EventoPercorso evento;
  final Set<String> partecipantiPassati = {};
  WaypointStatus status = WaypointStatus.attivo;

  ManagedWaypoint({required this.evento});
}
