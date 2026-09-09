import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/servizio_database.dart';

import 'schermata_dettaglio_membro.dart';

/// Schermata di dettaglio del gruppo con gestione ruoli e azioni specifiche.
class SchermataDettaglioGruppo extends StatefulWidget {
  final Gruppo gruppo;

  const SchermataDettaglioGruppo({super.key, required this.gruppo});

  @override
  State<SchermataDettaglioGruppo> createState() => _SchermataDettaglioGruppoState();
}

class _SchermataDettaglioGruppoState extends State<SchermataDettaglioGruppo> {
  final ServizioGruppi _servizioGruppi = ServizioGruppi();
  final ServizioDatabase _servizioDatabase = ServizioDatabase();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  PartecipanteGruppo? _mioRuolo;
  bool _inCaricamento = true;

  @override
  void initState() {
    super.initState();
    _caricaDati();
    // Aggiorniamo la presenza quando entriamo nel dettaglio
    if (_uid != null) {
      _servizioGruppi.aggiornaPresenza(widget.gruppo.id, _uid, true);
    }
  }

  @override
  void dispose() {
    // Aggiorniamo la presenza quando usciamo
    if (_uid != null) {
      _servizioGruppi.aggiornaPresenza(widget.gruppo.id, _uid, false);
    }
    super.dispose();
  }

  Future<void> _caricaDati() async {
    if (_uid == null) return;
    try {
      final ruolo = await _servizioGruppi.ottieniRuoloUtente(widget.gruppo.id, _uid);
      if (mounted) {
        setState(() {
          _mioRuolo = ruolo;
          _inCaricamento = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inCaricamento = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore caricamento dati: $e")),
        );
      }
    }
  }

  String _formattaRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader:
        return "👑 Leader";
      case RuoloGruppo.scopa:
        return "🏍️ Scopa";
      case RuoloGruppo.partecipante:
        return "👤 Partecipante";
    }
  }

  String _ottieniEmojiRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader:
        return "👑";
      case RuoloGruppo.scopa:
        return "🏍️";
      case RuoloGruppo.partecipante:
        return "👤";
    }
  }

  Future<void> _esciDalGruppo() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Esci dal Gruppo"),
        content: const Text("Sei sicuro di voler uscire? Non potrai più comunicare con il team."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULLA")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ESCI")),
        ],
      ),
    );

    if (conferma == true && _uid != null) {
      try {
        await _servizioGruppi.esciDalGruppo(widget.gruppo.id, _uid);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _eliminaGruppo() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ELIMINA GRUPPO"),
        content: const Text("Questa azione disattiverà il gruppo per tutti i partecipanti. Sei sicuro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ANNULLA")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("ELIMINA"),
          ),
        ],
      ),
    );

    if (conferma == true && _uid != null) {
      try {
        await _servizioGruppi.eliminaGruppo(widget.gruppo.id, _uid);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  /// Condivide il codice di accesso tramite il menu di sistema.
  void _condividiCodice() {
    Share.share(
      "${widget.gruppo.codiceAccesso}\n\n"
      "RideBridge\n"
      "Codice invito gruppo",
      subject: "Invito Gruppo RideBridge",
    );
  }

  /// Copia il codice di accesso negli appunti.
  void _copiaCodice() {
    Clipboard.setData(ClipboardData(text: widget.gruppo.codiceAccesso));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Codice copiato negli appunti"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inCaricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_mioRuolo == null) {
      return const Scaffold(body: Center(child: Text("Accesso negato o ruolo non trovato")));
    }

    final mioRuolo = _mioRuolo!;
    final bool eLeader = mioRuolo.ruolo == RuoloGruppo.leader;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gruppo.nome),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Info
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: const Border(bottom: BorderSide(color: Colors.orange, width: 0.5)),
            ),
            child: Column(
              children: [
                const Text("CODICE DI ACCESSO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                SelectableText(
                  widget.gruppo.codiceAccesso,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 5, color: Colors.orange),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _condividiCodice,
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text("CONDIVIDI"),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _copiaCodice,
                      icon: const Icon(Icons.copy, size: 20),
                      label: const Text("COPIA"),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text("IL TUO RUOLO", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  _formattaRuolo(mioRuolo.ruolo),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Lista Partecipanti
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text("PARTECIPANTI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<PartecipanteGruppo>>(
              stream: FirebaseFirestore.instance
                  .collection('gruppi')
                  .doc(widget.gruppo.id)
                  .collection('partecipanti')
                  .snapshots()
                  .map((snapshot) => snapshot.docs
                      .map((doc) => PartecipanteGruppo.daMappa(doc.data(), doc.id))
                      .toList()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final partecipanti = snapshot.data ?? [];
                
                return ListView.separated(
                  itemCount: partecipanti.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = partecipanti[index];

                    return FutureBuilder<Utente?>(
                      future: _servizioDatabase.leggiUtente(p.idUtente),
                      builder: (context, uSnapshot) {
                        final utente = uSnapshot.data;
                        final nomePartecipante = utente?.nickname?.isNotEmpty == true
                            ? utente!.nickname!
                            : (utente?.nome ?? "Caricamento...");
                        
                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SchermataDettaglioMembro(
                                  idGruppo: widget.gruppo.id,
                                  idUtente: p.idUtente,
                                ),
                              ),
                            );
                          },
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: utente?.fotoUrl != null ? NetworkImage(utente!.fotoUrl!) : null,
                                child: utente?.fotoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: p.online ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Text(
                                "${_ottieniEmojiRuolo(p.ruolo)} $nomePartecipante",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (p.statoAudio?.staParlando == true)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.mic, color: Colors.green, size: 16),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                utente?.moto?.isNotEmpty == true
                                    ? utente!.moto!
                                    : _formattaRuolo(p.ruolo),
                              ),
                              Row(
                                children: [
                                  if (!p.microfonoConsentito)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.mic_off, color: Colors.red, size: 14),
                                    ),
                                  if (!p.audioConsentito)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.volume_off, color: Colors.red, size: 14),
                                    ),
                                  if (p.statoAudio?.emergenzaAttiva == true)
                                    const Text(
                                      "🚨 EMERGENZA",
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Azioni di Fondo
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: eLeader
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _eliminaGruppo,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text("ELIMINA GRUPPO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _esciDalGruppo,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text("ESCI DAL GRUPPO"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
