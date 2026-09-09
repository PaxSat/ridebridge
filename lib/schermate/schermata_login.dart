import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../servizi/servizio_auth.dart';
import 'schermata_home.dart';

/// Schermata iniziale per l'autenticazione dell'utente.
class SchermataLogin extends StatefulWidget {
  const SchermataLogin({super.key});

  @override
  State<SchermataLogin> createState() => _SchermataLoginState();
}

class _SchermataLoginState extends State<SchermataLogin> {
  bool _inCaricamento = false;
  final ServizioAuth _servizioAuth = ServizioAuth();

  Future<void> _gestisciLogin() async {
    setState(() => _inCaricamento = true);

    try {
      final risultato = await _servizioAuth.accediConGoogle();

      if (risultato != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SchermataHome(),
          ),
        );
      }
    } catch (errore) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.loginError(errore.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _inCaricamento = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.motorcycle,
                size: 120,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                l10n.appSubtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 60),
              if (_inCaricamento)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _gestisciLogin,
                  icon: const Icon(Icons.login),
                  label: Text(l10n.loginButton),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
