import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'servizio_database.dart';
import '../modelli/utente.dart';

/// Gestisce l'autenticazione degli utenti tramite Firebase e Google.
class ServizioAuth {
  final ServizioDatabase _servizioDatabase = ServizioDatabase();

  // Configurazione esplicita del Web Client ID per risolvere l'errore ApiException 10 in produzione.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '799919702472-k2337qjipc111i7hlamvn19qtg0e9h18.apps.googleusercontent.com',
  );

  /// Effettua l'accesso tramite Google e sincronizza i dati su Firestore.
  Future<UserCredential?> accediConGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

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

      if (userCredential.user != null) {
        await _sincronizzaProfilo(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Effettua l'accesso tramite Email e Password.
  Future<UserCredential?> accediConEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user != null) {
        await _sincronizzaProfilo(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Effettua la registrazione tramite Email e Password.
  Future<UserCredential?> registraConEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      
      if (userCredential.user != null) {
        await _sincronizzaProfilo(userCredential.user!);
        await inviaEmailVerifica();
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Invia l'email di verifica all'utente corrente.
  Future<void> inviaEmailVerifica() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Sincronizza i dati dell'utente Firebase con Firestore.
  Future<void> _sincronizzaProfilo(User firebaseUser) async {
    final bool esiste = await _servizioDatabase.esisteUtente(firebaseUser.uid);

    if (esiste) {
      await _servizioDatabase.aggiornaUltimoAccesso(firebaseUser.uid);
    } else {
      final Utente utente = Utente(
        id: firebaseUser.uid,
        nome: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Motociclista',
        email: firebaseUser.email ?? '',
        fotoUrl: firebaseUser.photoURL,
        ultimoAccesso: DateTime.now(),
        attivo: true,
        dataRegistrazione: DateTime.now(),
      );
      await _servizioDatabase.salvaUtente(utente);
    }
  }

  /// Effettua il logout dell'utente.
  Future<void> esci() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
