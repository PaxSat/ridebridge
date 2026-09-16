import 'dart:async';
import 'package:flutter/material.dart';
import 'schermata_login.dart';

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
    // Avvia il timer di 5 secondi per il passaggio al Login
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SchermataLogin()),
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
