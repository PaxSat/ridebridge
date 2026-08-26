import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'servizio_database.dart';
import '../modelli/utente.dart';

/// Gestisce l'autenticazione degli utenti tramite Firebase e Google.
class ServizioAuth {
  final ServizioDatabase _servizioDatabase = ServizioDatabase();

  /// Effettua l'accesso tramite Google e sincronizza i dati su Firestore.
  Future<UserCredential?> accediConGoogle() async {
    try {
      final GoogleSignInAccount? account = await GoogleSignIn().signIn();

      if (account == null) {
        return null; // L'utente ha annullato il login
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final AuthCredential credenziale = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
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
    } catch (e) {
      print('Errore durante il login Google: $e');
      rethrow;
    }
  }

  /// Effettua il logout dell'utente.
  Future<void> esci() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
