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

  /// Elimina definitivamente l'account utente e i dati associati.
  Future<void> eliminaAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception("Nessun utente autenticato.");
    }

    try {
      // 1. Identificazione Provider per ri-autenticazione
      final bool isGoogle = user.providerData.any((info) => info.providerId == 'google.com');

      // 2. Fase di Certezza / Riautenticazione
      if (isGoogle) {
        // STEP 4: Per utenti Google Sign-In, tentiamo ri-autenticazione automatica
        final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();
        
        if (googleAccount != null) {
          final GoogleSignInAuthentication googleAuth = await googleAccount.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          
          // Riautenticazione per ottenere un token fresco
          await user.reauthenticateWithCredential(credential);
        } else {
          // L'utente ha annullato il selettore Google, interrompiamo il processo
          return;
        }
      } else {
        // STEP 5: Per utenti Email/Password, verifichiamo la "freschezza" della sessione
        // Se l'ultimo login è avvenuto più di 5 minuti fa, forziamo l'errore prima di Firestore
        final lastSignIn = user.metadata.lastSignInTime;
        final isRecent = lastSignIn != null && 
            DateTime.now().difference(lastSignIn).inMinutes < 5;
            
        if (!isRecent) {
          throw FirebaseAuthException(
            code: 'requires-recent-login',
            message: "Per eliminare l'account è necessario effettuare nuovamente l'accesso.",
          );
        }
      }

      // STEP 6: Solo dopo una riautenticazione valida procediamo con l'eliminazione
      
      // 3. Eliminazione dati Firestore (Sicura perché Auth è ancora attivo e la sessione è fresca)
      await _servizioDatabase.eliminaDatiUtente(user.uid);

      // 4. Eliminazione Firebase Auth
      await user.delete();
      
      // 5. Logout per pulizia stato locale
      await esci();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception("Per eliminare l'account è necessario effettuare nuovamente l'accesso.");
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
