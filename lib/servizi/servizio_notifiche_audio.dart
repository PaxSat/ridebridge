import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Gestisce la generazione di messaggi testuali per il sistema TTS (Text-to-Speech).
class ServizioNotificheAudio {
  
  /// Restituisce la stringa localizzata per l'avviso di "avanti al leader".
  static String avvisoAvantiLeader(BuildContext context) {
    return AppLocalizations.of(context)!.aheadOfLeader;
  }

  /// Restituisce la stringa localizzata per l'avviso di "dietro la scopa".
  static String avvisoDietroScopa(BuildContext context) {
    return AppLocalizations.of(context)!.behindSweeper;
  }

  /// Restituisce la stringa localizzata per l'avviso di "fuori percorso".
  static String avvisoFuoriPercorso(BuildContext context) {
    return AppLocalizations.of(context)!.offRoute;
  }

  /// Restituisce la stringa localizzata per una svolta imminente.
  static String avvisoSvolta(BuildContext context, int distanza, String direzione) {
    return AppLocalizations.of(context)!.turnAlert(distanza, direzione);
  }

  /// Esempio di come recuperare le localizzazioni senza BuildContext 
  /// (necessario per servizi background o classi isolate).
  /// Nota: In una vera implementazione, si potrebbe salvare l'istanza 
  /// delle localizzazioni durante l'inizializzazione dell'app.
  static Future<String> avvisoSenzaContext(Locale locale, String key) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    // Nota: l10n è un oggetto tipizzato, l'accesso dinamico via key richiede 
    // una logica di mapping o l'uso di riflessione (sconsigliata).
    // In Flutter l10n si preferisce l'accesso diretto alle proprietà.
    return l10n.aheadOfLeader; // Esempio statico
  }
}
