import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'schermate/schermata_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'servizi/georef_controller.dart';
import 'servizi/firebase_georef_transport.dart';

/// Punto di ingresso dell'applicazione.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  GeoRefController().initialize(
    FirebaseGeorefTransport(),
  );

  runApp(
    const RideBridgeApp(),
  );
}

/// Classe principale dell'app.
class RideBridgeApp extends StatelessWidget {
  const RideBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nasconde il banner DEBUG in alto a destra
      debugShowCheckedModeBanner: false,

      // Nome applicazione
      title: 'RideBridge',

      // Tema grafico generale
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),

      // Localizzazione
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      // Prima schermata mostrata all'avvio
      home: const SchermataSplash(),
    );
  }
}
