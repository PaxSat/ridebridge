import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Schermata che mostra le informazioni sull'app e lo sviluppatore.
class SchermataInfo extends StatelessWidget {
  const SchermataInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appInfo),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Logo o Icona App
            const Center(
              child: Hero(
                tag: 'app_logo',
                child: Icon(
                  Icons.motorcycle,
                  size: 100,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "RideBridge",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              l10n.appSubtitle,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 40),
            
            // Card Informazioni
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _rigaInfo(context, Icons.person, l10n.developer, "Pasquale Cardillo Giuliano\n& Gemini & Copilot"),
                      const Divider(height: 32),
                      _rigaInfo(context, Icons.info_outline, l10n.version, "1.0.13+14"),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Testo "About"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                l10n.aboutText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Credits
            Text(
              l10n.credits,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _rigaInfo(BuildContext context, IconData icona, String etichetta, String valore) {
    return Row(
      children: [
        Icon(icona, color: Colors.orange, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etichetta,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                valore,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
