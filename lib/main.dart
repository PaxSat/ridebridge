import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'schermate/schermata_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

/// Punto di ingresso dell'applicazione.
/// Tutto parte da qui.
void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      home: const SchermataLogin(),
    );
  }
}
