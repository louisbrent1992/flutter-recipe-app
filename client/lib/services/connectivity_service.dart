import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// Service to monitor network connectivity state
/// Uses connectivity_plus to detect WiFi, mobile, and offline states
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Current connectivity state
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final _connectivityController =
      StreamController<List<ConnectivityResult>>.broadcast();

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivityController.stream;

  /// Current connection status
  List<ConnectivityResult> get connectionStatus => _connectionStatus;

  /// Check if device is online (has any connection)
  bool get isOnline => !_connectionStatus.contains(ConnectivityResult.none);

  /// Check if device has WiFi connection
  bool get hasWifi => _connectionStatus.contains(ConnectivityResult.wifi);

  /// Check if device has mobile/cellular connection
  bool get hasMobile => _connectionStatus.contains(ConnectivityResult.mobile);

  /// Get primary connection type (WiFi preferred over mobile)
  ConnectivityResult? get primaryConnection {
    if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      return ConnectivityResult.wifi;
    } else if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      return ConnectivityResult.mobile;
    } else if (_connectionStatus.contains(ConnectivityResult.ethernet)) {
      return ConnectivityResult.ethernet;
    } else if (_connectionStatus.contains(ConnectivityResult.none)) {
      return ConnectivityResult.none;
    }
    return null;
  }

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Get initial connectivity state
      await checkConnectivity();

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          if (kDebugMode) {
            debugPrint('Connectivity stream error: $error');
          }
          // Default to offline on stream error
          _updateConnectionStatus([ConnectivityResult.none]);
        },
      );
    } catch (e) {
      // Handle MissingPluginException - plugin not registered yet
      if (kDebugMode) {
        debugPrint(
          'Connectivity initialization error (plugin may not be registered): $e',
        );
        debugPrint('Please do a full app rebuild (not just hot reload)');
      }
      // Default to offline - will work after full rebuild
      await _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  /// Check current connectivity status
  Future<void> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Couldn\'t check connectivity status: $e');
      }
      // Default to offline on error
      await _updateConnectionStatus([ConnectivityResult.none]);
    } catch (e) {
      // Handle MissingPluginException and other errors
      if (kDebugMode) {
        debugPrint(
          'Connectivity check error (plugin may not be registered): $e',
        );
      }
      // Default to offline on error - plugin will be available after full rebuild
      await _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  /// Update connection status and notify listeners
  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    if (_connectionStatus.toString() != result.toString()) {
      _connectionStatus = result;
      _connectivityController.add(result);

      if (kDebugMode) {
        debugPrint('Connectivity changed: $result');
        debugPrint('Is online: $isOnline');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
