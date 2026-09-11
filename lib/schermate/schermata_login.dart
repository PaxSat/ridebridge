import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _mostraMessaggio(String messaggio, {bool errore = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        backgroundColor: errore ? Colors.red : Colors.green,
      ),
    );
  }

  String _traduciErrore(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'Utente non trovato.';
        case 'wrong-password':
          return 'Password errata.';
        case 'email-already-in-use':
          return 'Questa email è già registrata.';
        case 'weak-password':
          return 'La password è troppo debole.';
        case 'invalid-email':
          return 'Email non valida.';
        default:
          return 'Errore di autenticazione: ${e.message}';
      }
    }
    return e.toString();
  }

  Future<void> _gestisciLoginGoogle() async {
    setState(() => _inCaricamento = true);
    try {
      final risultato = await _servizioAuth.accediConGoogle();
      if (risultato != null && mounted) {
        _vaiAllaHome();
      }
    } catch (e) {
      _mostraMessaggio(_traduciErrore(e));
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  Future<void> _gestisciLoginEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostraMessaggio('Inserisci email e password.');
      return;
    }

    setState(() => _inCaricamento = true);
    try {
      final risultato = await _servizioAuth.accediConEmail(email, password);
      if (risultato != null && mounted) {
        _vaiAllaHome();
      }
    } catch (e) {
      _mostraMessaggio(_traduciErrore(e));
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  Future<void> _gestisciRegistrazione() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostraMessaggio('Inserisci email e password.');
      return;
    }

    setState(() => _inCaricamento = true);
    try {
      final risultato = await _servizioAuth.registraConEmail(email, password);
      if (risultato != null && mounted) {
        _mostraMessaggio('Registrazione completata. Controlla la tua email per la verifica.', errore: false);
      }
    } catch (e) {
      _mostraMessaggio(_traduciErrore(e));
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  void _vaiAllaHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SchermataHome(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.motorcycle,
              size: 100,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              l10n.appSubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            
            // Login Google
            if (_inCaricamento)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _gestisciLoginGoogle,
                  icon: const Icon(Icons.login),
                  label: Text(l10n.loginButton),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("oppure email", style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              
              // Login/Registrazione Email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _gestisciLoginEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ACCEDI CON EMAIL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _gestisciRegistrazione,
                child: const Text('Non hai un account? REGISTRATI ORA', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
