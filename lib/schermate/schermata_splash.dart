import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'schermata_login.dart';
import 'schermata_home.dart';

/// Schermata di Splash personalizzata che mostra l'immagine del brand.
class SchermataSplash extends StatefulWidget {
  const SchermataSplash({super.key});

  @override
  State<SchermataSplash> createState() => _SchermataSplashState();
}

class _SchermataSplashState extends State<SchermataSplash> {
  @override
  void initState() {
    super.initState();
    // Verifica l'autenticazione persistente dopo il timer di splash
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        
        Widget nextScreen = (user != null) 
            ? const SchermataHome() 
            : const SchermataLogin();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/splash.png',
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
