import 'package:flutter/material.dart';

class SchermataGruppo extends StatelessWidget {

  final String nomeGruppo;
  final String codiceGruppo;

  const SchermataGruppo({
    super.key,
    required this.nomeGruppo,
    required this.codiceGruppo,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gruppo"),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Text(
              "Gruppo: $nomeGruppo",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Codice: $codiceGruppo",
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

          ],
        ),
      ),
    );
  }
}