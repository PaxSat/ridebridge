import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../servizi/servizio_gruppi.dart';

/// Schermata per la creazione di un nuovo gruppo di motociclisti.
class SchermataCreaGruppo extends StatefulWidget {
  const SchermataCreaGruppo({super.key});

  @override
  State<SchermataCreaGruppo> createState() => _SchermataCreaGruppoState();
}

class _SchermataCreaGruppoState extends State<SchermataCreaGruppo> {
  final TextEditingController _controlloreNome = TextEditingController();
  final ServizioGruppi _servizioGruppi = ServizioGruppi();
  
  bool _inCaricamento = false;
  String? _errore;

  /// Esegue la logica di creazione del gruppo.
  Future<void> _gestisciCreaGruppo() async {
    final nome = _controlloreNome.text.trim();

    if (nome.isEmpty) {
      setState(() => _errore = "Il nome del gruppo non può essere vuoto");
      return;
    }

    setState(() {
      _inCaricamento = true;
      _errore = null;
    });

    try {
      final utenteAttuale = FirebaseAuth.instance.currentUser;
      if (utenteAttuale == null) {
        throw Exception("Utente non autenticato");
      }

      // Creazione del gruppo su Firestore e recupero diretto del codice
      final codice = await _servizioGruppi.creaGruppo(nome, utenteAttuale.uid);

      if (mounted) {
        _mostraConferma(codice);
      }
    } catch (e) {
      setState(() => _errore = "Errore durante la creazione: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _inCaricamento = false);
      }
    }
  }

  /// Mostra un dialogo di successo con il codice del gruppo.
  void _mostraConferma(String codice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Gruppo creato con successo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Condividi questo codice con i tuoi amici:"),
            const SizedBox(height: 16),
            SelectableText(
              codice,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Chiude il dialog
              Navigator.of(context).pop(); // Torna alla home
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crea Gruppo"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Inizia una nuova avventura",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Scegli un nome per il tuo gruppo di motociclisti.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controlloreNome,
              enabled: !_inCaricamento,
              decoration: InputDecoration(
                labelText: "Nome del Gruppo",
                hintText: "es. I Lupi della Strada",
                errorText: _errore,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _inCaricamento ? null : _gestisciCreaGruppo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _inCaricamento
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "CREA GRUPPO",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controlloreNome.dispose();
    super.dispose();
  }
}
