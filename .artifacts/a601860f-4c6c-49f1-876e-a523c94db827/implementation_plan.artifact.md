# Piano di Implementazione: Step 1 & 2 (Utente e Gruppi Firestore)

Questo piano copre la creazione della struttura dati su Firestore per gestire i profili utente e la creazione/gestione dei gruppi di motociclisti.

## User Review Required

> [!IMPORTANT]
> Verificare che le dipendenze `cloud_firestore` e `google_sign_in` siano correttamente configurate nel `pubspec.yaml` (dovrebbero esserlo già, vista la presenza di `servizio_auth.dart`).

## Proposed Changes

### [Modelli]
Aggiornamento e creazione delle classi dati per garantire coerenza tra il codice e Firestore.

#### [MODIFY] [utente.dart](file:///C:/progetti/ridebridge/lib/modelli/utente.dart)
- Aggiunta di campi: `fotoUrl`, `dataRegistrazione`.
- Aggiunta di metodi `toMap()` e `fromMap()` per la serializzazione Firestore.

#### [MODIFY] [gruppo.dart](file:///C:/progetti/ridebridge/lib/modelli/gruppo.dart)
- Definizione dei campi: `id`, `nome`, `codiceAccesso`, `creatoreId`, `membriIds` (lista di ID utente).
- Aggiunta di metodi di serializzazione.

---

### [Servizi]
Creazione del cuore della logica di persistenza.

#### [NEW] [servizio_database.dart](file:///C:/progetti/ridebridge/lib/servizi/servizio_database.dart)
- Metodo `salvaUtente(Utente utente)`: crea o aggiorna il profilo utente su Firestore.
- Metodo `creaGruppo(String nome, String creatoreId)`: genera un nuovo gruppo con un codice univoco.
- Metodo `recuperaGruppiUtente(String utenteId)`: stream per vedere i gruppi di cui si fa parte.

#### [MODIFY] [servizio_auth.dart](file:///C:/progetti/ridebridge/lib/servizi/servizio_auth.dart)
- Integrazione: dopo il login con Google, chiamare automaticamente `ServizioDatabase.salvaUtente` per sincronizzare il profilo.

---

### [Schermate]
Predisposizione per visualizzare i dati.

#### [MODIFY] [schermata_home.dart](file:///C:/progetti/ridebridge/lib/schermate/schermata_home.dart)
- Modifica per visualizzare i dati dell'utente loggato (nome/foto) recuperati da Firebase.

## Verification Plan

### Manual Verification
1.  Effettuare il login con Google nell'app.
2.  Verificare sulla console Firebase -> Firestore che sia stato creato un documento nella collezione `users` con i dati corretti.
3.  Testare (tramite una chiamata temporanea o UI) la creazione di un gruppo e verificare la comparsa nella collezione `groups`.
