import 'package:flutter/material.dart';
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
            content: Text("Errore durante il login: ${errore.toString()}"),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("RideBridge"),
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
              const Text(
                "RideBridge",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                "Il tuo interfono intelligente",
                style: TextStyle(
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
                  label: const Text("ACCEDI CON GOOGLE"),
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
