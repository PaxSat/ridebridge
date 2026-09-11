import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_database.dart';
import '../servizi/servizio_auth.dart';
import 'schermata_login.dart';

/// Schermata per la gestione del profilo utente (Nickname e Moto).
class SchermataProfilo extends StatefulWidget {
  final Utente utente;

  const SchermataProfilo({super.key, required this.utente});

  @override
  State<SchermataProfilo> createState() => _SchermataProfiloState();
}

class _SchermataProfiloState extends State<SchermataProfilo> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controlloreNickname;
  late TextEditingController _controlloreMoto;
  final ServizioDatabase _servizioDatabase = ServizioDatabase();
  final ServizioAuth _servizioAuth = ServizioAuth();
  
  bool _inCaricamento = false;

  @override
  void initState() {
    super.initState();
    _controlloreNickname = TextEditingController(text: widget.utente.nickname);
    _controlloreMoto = TextEditingController(text: widget.utente.moto);
  }

  @override
  void dispose() {
    _controlloreNickname.dispose();
    _controlloreMoto.dispose();
    super.dispose();
  }

  /// Salva le modifiche su Firestore.
  Future<void> _salvaProfilo() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _inCaricamento = true);

    try {
      final utenteAggiornato = widget.utente.copiaCon(
        nickname: _controlloreNickname.text.trim(),
        moto: _controlloreMoto.text.trim(),
      );

      await _servizioDatabase.salvaUtente(utenteAggiornato);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdated)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorPrefix(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  /// Mostra il dialogo di conferma ed esegue l'eliminazione.
  Future<void> _confermaEliminaAccount() async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare account?'),
        content: const Text(
          'Questa operazione è irreversibile.\n\n'
          'Saranno eliminati:\n'
          '• account RideBridge\n'
          '• dati profilo associati',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINA', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confermato == true) {
      await _eliminaAccount();
    }
  }

  /// Esegue la logica di eliminazione account.
  Future<void> _eliminaAccount() async {
    setState(() => _inCaricamento = true);
    try {
      await _servizioAuth.eliminaAccount();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SchermataLogin()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String messaggio = "Si è verificato un errore durante l'eliminazione.";
        if (e.toString().contains("recent-login")) {
          messaggio = "Effettua nuovamente il login e riprova.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messaggio)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfile),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Foto e Nome Base
              CircleAvatar(
                radius: 50,
                backgroundImage: widget.utente.fotoUrl != null 
                    ? NetworkImage(widget.utente.fotoUrl!) 
                    : null,
                child: widget.utente.fotoUrl == null 
                    ? const Icon(Icons.person, size: 50) 
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                widget.utente.nome,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.utente.email,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Campi Modificabili
              TextFormField(
                controller: _controlloreNickname,
                decoration: InputDecoration(
                  labelText: l10n.nickname,
                  hintText: l10n.nicknameHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.nicknameError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controlloreMoto,
                decoration: InputDecoration(
                  labelText: l10n.yourMotorcycle,
                  hintText: l10n.motorcycleHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.motorcycle),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.motorcycleError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Bottone Salvataggio
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _inCaricamento ? null : _salvaProfilo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _inCaricamento
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(l10n.saveChanges, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              
              // Bottone Eliminazione Account
              TextButton.icon(
                onPressed: _inCaricamento ? null : _confermaEliminaAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'Elimina account',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
