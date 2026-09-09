import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../servizi/servizio_gruppi.dart';

/// Schermata per entrare in un gruppo tramite codice di accesso.
class SchermataEntraGruppo extends StatefulWidget {
  const SchermataEntraGruppo({super.key});

  @override
  State<SchermataEntraGruppo> createState() => _SchermataEntraGruppoState();
}

class _SchermataEntraGruppoState extends State<SchermataEntraGruppo> {
  final TextEditingController _controlloreCodice = TextEditingController();
  final ServizioGruppi _servizioGruppi = ServizioGruppi();
  
  bool _inCaricamento = false;
  String? _errore;

  /// Esegue la logica per entrare nel gruppo.
  Future<void> _gestisciEntraNelGruppo() async {
    final l10n = AppLocalizations.of(context)!;
    final codice = _controlloreCodice.text.trim().toUpperCase();

    if (codice.isEmpty) {
      setState(() => _errore = l10n.enterCodeError);
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

      await _servizioGruppi.entraNelGruppo(codice, utenteAttuale.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.joinSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Torna alla Home
      }
    } catch (e) {
      setState(() => _errore = e.toString().replaceAll("Exception: ", ""));
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
        title: Text(l10n.joinGroup),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.joinTeam,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.enterCodeInstructions,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controlloreCodice,
              enabled: !_inCaricamento,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: l10n.groupCode,
                hintText: l10n.groupCodeHint,
                errorText: _errore,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.vpn_key),
                counterText: "",
              ),
              onChanged: (val) {
                // Forza il maiuscolo durante la digitazione
                if (val != val.toUpperCase()) {
                  _controlloreCodice.value = _controlloreCodice.value.copyWith(
                    text: val.toUpperCase(),
                    selection: TextSelection.collapsed(offset: val.length),
                  );
                }
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _inCaricamento ? null : _gestisciEntraNelGruppo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
                    : Text(
                        l10n.joinGroup,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
    _controlloreCodice.dispose();
    super.dispose();
  }
}
