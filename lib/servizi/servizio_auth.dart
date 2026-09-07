import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'servizio_database.dart';
import '../modelli/utente.dart';

/// Gestisce l'autenticazione degli utenti tramite Firebase e Google.
class ServizioAuth {
  final ServizioDatabase _servizioDatabase = ServizioDatabase();

  // Web Client ID necessario per risolvere l'errore ApiException 10 in produzione.
  static const String _webClientId = '799919702472-k2337qjipc111i7hlamvn19qtg0e9h18.apps.googleusercontent.com';

  /// Effettua l'accesso tramite Google e sincronizza i dati su Firestore.
  Future<UserCredential?> accediConGoogle() async {
    try {
      // In google_sign_in 7.2.0, l'inizializzazione tramite singleton è obbligatoria.
      await GoogleSignIn.instance.initialize(
        serverClientId: _webClientId,
      );

      // Il metodo signIn() è stato sostituito da authenticate() per supportare Credential Manager.
      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();

      if (account == null) {
        return null; // L'utente ha annullato il login
      }

      // In 7.2.0, l'oggetto authentication è accessibile in modo sincrono e contiene l'idToken.
      final GoogleSignInAuthentication auth = account.authentication;

      // L'accessToken è stato rimosso da GoogleSignInAuthentication e spostato in authorizationClient.
      // Viene richiesto qui per completare la credenziale Firebase.
      final GoogleSignInClientAuthorization authorization = 
          await account.authorizationClient.authorizeScopes(['email', 'profile']);

      final AuthCredential credenziale = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: auth.idToken,
      );

      // Autenticazione su Firebase
      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credenziale);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Creazione o aggiornamento del profilo utente su Firestore
        final Utente utente = Utente(
          id: firebaseUser.uid,
          nome: firebaseUser.displayName ?? 'Motociclista',
          email: firebaseUser.email ?? '',
          fotoUrl: firebaseUser.photoURL,
          ultimoAccesso: DateTime.now(),
          attivo: true,
        );

        await _servizioDatabase.salvaUtente(utente);
      }

      return userCredential;
    } catch (e, stack) {
      debugPrint('================================');
      debugPrint('LOGIN GOOGLE FALLITO');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      debugPrint('================================');
      rethrow;
    }
  }

  /// Effettua il logout dell'utente.
  Future<void> esci() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
