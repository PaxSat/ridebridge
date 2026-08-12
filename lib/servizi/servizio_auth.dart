import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ServizioAuth {

  Future<UserCredential?> accediConGoogle() async {

    final GoogleSignInAccount? account =
    await GoogleSignIn().signIn();

    if (account == null) {
      return null;
    }

    final GoogleSignInAuthentication auth =
    await account.authentication;

    final credential =
    GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    return FirebaseAuth.instance
        .signInWithCredential(
      credential,
    );
  }
}