import 'package:flutter/foundation.dart';

/// Gestisce centralmente lo stato globale persistente del debugMode
/// e l'interruttore REAL / FAKE per il simulatore GPS.
class DebugManager extends ChangeNotifier {
  static final DebugManager _instance = DebugManager._internal();
  factory DebugManager() => _instance;
  DebugManager._internal();

  bool _debugMode = false;
  bool _gpsFake = false;

  bool get debugMode => _debugMode;
  bool get gpsFake => _gpsFake;

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
}
