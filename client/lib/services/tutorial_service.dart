import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage tutorial state and completion tracking.
/// Stores tutorial completion status in SharedPreferences.
class TutorialService {
  TutorialService._internal();
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;

  static const String _tutorialCompletedKey = 'tutorial_completed';
  static const String _tutorialVersionKey = 'tutorial_version';
  
  // Increment this version when tutorial content changes significantly
  static const int _currentTutorialVersion = 2;

  SharedPreferences? _prefs;
  
  // Stream controller for active step notifications
  final _stepController = StreamController<GlobalKey>.broadcast();
  Stream<GlobalKey> get onStepChanged => _stepController.stream;
  
  // Flag to prevent auto-start when manually restarting
  bool _isManualRestart = false;
  bool get isManualRestart => _isManualRestart;

  /// Initialize the tutorial service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if the tutorial has been completed
  Future<bool> isTutorialCompleted() async {
    if (_prefs == null) await init();
    
    final completed = _prefs?.getBool(_tutorialCompletedKey) ?? false;
    final version = _prefs?.getInt(_tutorialVersionKey) ?? 0;
    
    // If tutorial version changed, reset completion status
    if (version < _currentTutorialVersion) {
      await resetTutorial();
      return false;
    }
    
    return completed;
  }

  /// Mark the tutorial as completed
  Future<void> completeTutorial() async {
    if (_prefs == null) await init();
    
    await _prefs?.setBool(_tutorialCompletedKey, true);
    await _prefs?.setInt(_tutorialVersionKey, _currentTutorialVersion);
    
    if (kDebugMode) {
      debugPrint('✅ TutorialService: Tutorial marked as completed');
    }
  }

  /// Reset the tutorial (allows user to see it again)
  /// [isManual] indicates if this is a manual restart (prevents auto-start)
  Future<void> resetTutorial({bool isManual = false}) async {
    if (_prefs == null) await init();
    
    _isManualRestart = isManual;
    await _prefs?.remove(_tutorialCompletedKey);
    await _prefs?.setInt(_tutorialVersionKey, _currentTutorialVersion);
    
    if (kDebugMode) {
      debugPrint('🔄 TutorialService: Tutorial reset (manual: $isManual)');
    }
  }
  
  /// Clear the manual restart flag (called after tutorial starts)
  void clearManualRestartFlag() {
    _isManualRestart = false;
  }

  /// Check if tutorial should be shown (not completed)
  Future<bool> shouldShowTutorial() async {
    return !(await isTutorialCompleted());
  }

  /// Notify listeners that the tutorial step has changed
  void notifyStepChanged(GlobalKey key) {
    _stepController.add(key);
  }
}

