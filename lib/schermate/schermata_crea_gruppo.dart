import 'package:flutter/material.dart';
import 'schermata_gruppo.dart';

class SchermataCreaGruppo extends StatefulWidget {
  const SchermataCreaGruppo({super.key});

  @override
  State<SchermataCreaGruppo> createState() =>
      _SchermataCreaGruppoState();
}

class _SchermataCreaGruppoState
    extends State<SchermataCreaGruppo> {

  final TextEditingController controlloreNomeGruppo =
  TextEditingController();

  final TextEditingController controlloreCodiceGruppo =
  TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crea Gruppo"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            const Text(
              "Inserisci i dati del gruppo",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: controlloreNomeGruppo,
              decoration: const InputDecoration(
                labelText: "Nome gruppo",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: controlloreCodiceGruppo,
              decoration: const InputDecoration(
                labelText: "Codice gruppo",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SchermataGruppo(
                        nomeGruppo:
                        controlloreNomeGruppo.text,
                        codiceGruppo:
                        controlloreCodiceGruppo.text,
                      ),
                    ),
                  );
                },
                child: const Text("CREA"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}