import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../modelli/gruppo.dart';
import '../modelli/configurazione_gruppo.dart';
import '../servizi/servizio_gruppi.dart';

/// Schermata per la configurazione dei parametri tecnici del gruppo.
/// Accessibile esclusivamente al Leader.
class SchermataConfigurazioneGruppo extends StatefulWidget {
  final Gruppo gruppo;

  const SchermataConfigurazioneGruppo({super.key, required this.gruppo});

  @override
  State<SchermataConfigurazioneGruppo> createState() => _SchermataConfigurazioneGruppoState();
}

class _SchermataConfigurazioneGruppoState extends State<SchermataConfigurazioneGruppo> {
  final _formKey = GlobalKey<FormState>();
  final _servizioGruppi = ServizioGruppi();

  late TextEditingController _turnThresholdAngle;
  late TextEditingController _triggerDistanceMeters;
  late TextEditingController _distanzaMassimaGruppo;
  late TextEditingController _distanzaMassimaScopa;
  late TextEditingController _offRouteThreshold;

  bool _inCaricamento = false;

  @override
  void initState() {
    super.initState();
    final c = widget.gruppo.configurazione;
    _turnThresholdAngle = TextEditingController(text: c.turnThresholdAngle.toString());
    _triggerDistanceMeters = TextEditingController(text: c.triggerDistanceMeters.toString());
    _distanzaMassimaGruppo = TextEditingController(text: c.distanzaMassimaGruppo.toString());
    _distanzaMassimaScopa = TextEditingController(text: c.distanzaMassimaScopa.toString());
    _offRouteThreshold = TextEditingController(text: c.offRouteThreshold.toString());
  }

  @override
  void dispose() {
    _turnThresholdAngle.dispose();
    _triggerDistanceMeters.dispose();
    _distanzaMassimaGruppo.dispose();
    _distanzaMassimaScopa.dispose();
    _offRouteThreshold.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _inCaricamento = true);

    try {
      final nuovaConfig = ConfigurazioneGruppo(
        turnThresholdAngle: double.parse(_turnThresholdAngle.text),
        triggerDistanceMeters: double.parse(_triggerDistanceMeters.text),
        distanzaMassimaGruppo: double.parse(_distanzaMassimaGruppo.text),
        distanzaMassimaScopa: double.parse(_distanzaMassimaScopa.text),
        offRouteThreshold: double.parse(_offRouteThreshold.text),
      );

      await _servizioGruppi.salvaConfigurazione(widget.gruppo.id, nuovaConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.configSaved)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorPrefix(e.toString()))));
    } finally {
      if (mounted) setState(() => _inCaricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupConfiguration), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.navParameters, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 16),
              _campoNumerico(
                controller: _turnThresholdAngle,
                etichetta: l10n.turnAngle,
                suggerimento: "es. 20.0",
              ),
              _campoNumerico(
                controller: _triggerDistanceMeters,
                etichetta: l10n.waypointDistance,
                suggerimento: "es. 10.0",
              ),
              const SizedBox(height: 32),
              Text(l10n.convoyThresholds, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 16),
              _campoNumerico(
                controller: _distanzaMassimaGruppo,
                etichetta: l10n.maxGroupDistance,
                suggerimento: "es. 500.0",
              ),
              _campoNumerico(
                controller: _distanzaMassimaScopa,
                etichetta: l10n.maxSweeperDistance,
                suggerimento: "es. 1000.0",
              ),
              _campoNumerico(
                controller: _offRouteThreshold,
                etichetta: l10n.offRouteThreshold,
                suggerimento: "es. 50.0",
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _inCaricamento ? null : _salva,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _inCaricamento 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text(l10n.saveConfiguration, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoNumerico({
    required TextEditingController controller,
    required String etichetta,
    required String suggerimento,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: etichetta,
          hintText: suggerimento,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.settings_input_component),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return l10n.requiredField;
          if (double.tryParse(value) == null) return l10n.invalidNumber;
          return null;
        },
      ),
    );
  }
}
