import 'package:flutter/material.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_database.dart';

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
          const SnackBar(content: Text("Profilo aggiornato con successo")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante il salvataggio: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Il Mio Profilo"),
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
                  labelText: "Nickname",
                  hintText: "Scegli il tuo nome da rider",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Inserisci un nickname";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controlloreMoto,
                decoration: InputDecoration(
                  labelText: "La tua Moto",
                  hintText: "es. Ducati Monster, BMW GS...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.motorcycle),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Inserisci il modello della tua moto";
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
                      : const Text("SALVA MODIFICHE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
