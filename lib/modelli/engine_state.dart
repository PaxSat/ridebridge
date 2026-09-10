/// Stati interni della logica di progressione sulla traccia (GeoRef V2).
enum EngineState {
  normal,    // Il rider sta seguendo lo Snake sequenzialmente
  offRoute,  // Il rider è fuori dalla traccia o non riesce a validare i punti
  rejoin,    // Il rider è appena rientrato sulla traccia (stato transitorio)
  invalid,   // Dati GPS inaffidabili o segnale perso
}
