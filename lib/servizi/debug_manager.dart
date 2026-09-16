import 'package:flutter/foundation.dart';

/// Gestisce centralmente lo stato globale persistente del debugMode
/// e l'interruttore REAL / FAKE per il simulatore GPS.
class DebugManager extends ChangeNotifier {
  static final DebugManager _instance = DebugManager._internal();
  factory DebugManager() => _instance;
  DebugManager._internal();

  bool _debugMode = false;
  bool _gpsFake = false;
  bool _ghostSnake = false;

  // Coordinate default: Brescia
  double _latFake = 45.5416;
  double _lonFake = 10.2118;

  bool get debugMode => _debugMode;
  bool get gpsFake => _gpsFake;
  bool get ghostSnake => _ghostSnake;
  double get latFake => _latFake;
  double get lonFake => _lonFake;

  set debugMode(bool value) {
    if (_debugMode != value) {
      _debugMode = value;
      notifyListeners();
    }
  }

  set gpsFake(bool value) {
    if (_gpsFake != value) {
      _gpsFake = value;
      notifyListeners();
    }
  }

  set ghostSnake(bool value) {
    if (_ghostSnake != value) {
      _ghostSnake = value;
      notifyListeners();
    }
  }

  void impostaCoordinateFake(double lat, double lon) {
    _latFake = lat;
    _lonFake = lon;
    notifyListeners();
  }
}
