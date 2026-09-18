import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../modelli/gruppo.dart';
import '../modelli/partecipante_gruppo.dart';
import '../modelli/utente.dart';
import '../servizi/servizio_gruppi.dart';
import '../servizi/servizio_database.dart';
import '../servizi/georef_controller.dart';
import '../servizi/debug_manager.dart';

import 'schermata_dettaglio_membro.dart';
import 'schermata_conversazione.dart';

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
          SnackBar(content: Text(AppLocalizations.of(context)!.errorPrefix(e.toString()))),
        );
      }
    }
  }

  String _formattaRuolo(RuoloGruppo ruolo) {
    final l10n = AppLocalizations.of(context)!;
    switch (ruolo) {
      case RuoloGruppo.leader:
        return "👑 ${l10n.leader}";
      case RuoloGruppo.scopa:
        return "🧹 ${l10n.scopa}";
      case RuoloGruppo.partecipante:
        return "👤 ${l10n.participant}";
    }
  }

  String _ottieniEmojiRuolo(RuoloGruppo ruolo) {
    switch (ruolo) {
      case RuoloGruppo.leader:
        return "👑";
      case RuoloGruppo.scopa:
        return "🧹";
      case RuoloGruppo.partecipante:
        return "👤";
    }
  }

  Future<void> _esciDalGruppo() async {
    final l10n = AppLocalizations.of(context)!;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exitGroup),
        content: Text(l10n.exitGroupConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.exit)),
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
    final l10n = AppLocalizations.of(context)!;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(l10n.deleteGroupConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.codeCopied),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_inCaricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_mioRuolo == null) {
      return Scaffold(body: Center(child: Text(l10n.memberNotFound)));
    }

    final mioRuolo = _mioRuolo!;
    final bool eLeader = mioRuolo.ruolo == RuoloGruppo.leader;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gruppo.nome),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: DebugManager(),
            builder: (context, _) => DebugManager().debugMode 
                ? const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Center(
                      child: Text(
                        "[GRP_DET]",
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
                Text(l10n.accessCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
                      label: Text(l10n.share),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _copiaCodice,
                      icon: const Icon(Icons.copy, size: 20),
                      label: Text(l10n.copy),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(l10n.yourRole, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  _formattaRuolo(mioRuolo.ruolo),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('gruppi')
                      .doc(widget.gruppo.id)
                      .collection('partecipanti')
                      .doc(_uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                    
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final bool eLeader = mioRuolo.ruolo == RuoloGruppo.leader;
                          
                          if (eLeader) {
                            final l10n = AppLocalizations.of(context)!;
                            final cancella = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(l10n.clearWaypointsTitle),
                                content: Text(l10n.clearWaypointsContent),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(l10n.clearWaypointsKeep),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: Text(l10n.clearWaypointsConfirm),
                                  ),
                                ],
                              ),
                            );

                            if (cancella == true) {
                              await _servizioGruppi.cancellaEventiPercorso(widget.gruppo.id);
                            }
                          }

                          // AVVIO FORZATO: Avviamo sempre l'engine locale quando si preme PARTECIPA
                          // per garantire che il cruscotto sia attivo (Fix -/0)
                          await GeoRefController().start(
                            idGruppo: widget.gruppo.id,
                            mioUid: _uid!,
                            mioRuolo: mioRuolo.ruolo,
                            configurazione: widget.gruppo.configurazione,
                          );
                          
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SchermataConversazione(
                                  gruppo: widget.gruppo,
                                  mioRuoloIniziale: mioRuolo.ruolo,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("PARTECIPA"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Lista Membri del Gruppo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Text("MEMBRI DEL GRUPPO", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<PartecipanteGruppo>>(
              stream: _servizioGruppi.streamPartecipanti(widget.gruppo.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final listaFinale = snapshot.data ?? [];
                
                // Ordiniamo per ruolo
                listaFinale.sort((a, b) => a.ruolo.index.compareTo(b.ruolo.index));

                if (listaFinale.isEmpty) {
                  return Center(child: Text(l10n.noParticipants));
                }

                return ListView.separated(
                  itemCount: listaFinale.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = listaFinale[index];

                        return FutureBuilder<Utente?>(
                          future: _servizioDatabase.leggiUtente(p.idUtente),
                          builder: (context, uSnapshot) {
                            final utente = uSnapshot.data;
                            final nomePartecipante = utente?.nickname?.isNotEmpty == true
                                ? utente!.nickname!
                                : (utente?.nome ?? (uSnapshot.connectionState == ConnectionState.waiting ? l10n.loading : "Utente ${p.idUtente.substring(0, 4)}"));
                            
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
                                    backgroundImage: (utente?.fotoUrl != null && utente!.fotoUrl!.isNotEmpty) ? NetworkImage(utente.fotoUrl!) : null,
                                    child: (utente?.fotoUrl == null || utente!.fotoUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
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
                                  Flexible(
                                    child: Text(
                                      "${_ottieniEmojiRuolo(p.ruolo)} $nomePartecipante",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                    overflow: TextOverflow.ellipsis,
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
                                        Text(
                                          "🚨 ${l10n.sos}",
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
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
                      label: Text(l10n.deleteGroup),
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
                      label: Text(l10n.exitGroup),
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
