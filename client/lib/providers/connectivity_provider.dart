import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';

/// Provider for connectivity state throughout the app
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  bool _isInitialized = false;

  ConnectivityProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize connectivity service
      await _connectivityService.initialize();
      
      // Get initial state
      _connectionStatus = _connectivityService.connectionStatus;
      
      // Listen to changes
      _subscription = _connectivityService.onConnectivityChanged.listen(
        (status) {
          _connectionStatus = status;
          notifyListeners();
        },
        onError: (error) {
          // Handle errors gracefully
          _connectionStatus = [ConnectivityResult.none];
          notifyListeners();
        },
      );
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Handle MissingPluginException gracefully
      // Default to offline state - will work after full rebuild
      _connectionStatus = [ConnectivityResult.none];
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Current connection status
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  
  /// Check if device is online (has any connection)
  bool get isOnline => _connectivityService.isOnline;
  
  /// Check if device has WiFi connection
  bool get hasWifi => _connectivityService.hasWifi;
  
  /// Check if device has mobile/cellular connection
  bool get hasMobile => _connectivityService.hasMobile;
  
  /// Get primary connection type (WiFi preferred over mobile)
  ConnectivityResult? get primaryConnection => _connectivityService.primaryConnection;
  
  /// Check if device is offline
  bool get isOffline => !isOnline;
  
  /// Get connection type as string for display
  String get connectionTypeString {
    if (hasWifi) return 'WiFi';
    if (hasMobile) return 'Mobile';
    return 'Offline';
  }

  /// Manually check connectivity (useful for retry scenarios)
  Future<void> checkConnectivity() async {
    await _connectivityService.checkConnectivity();
    _connectionStatus = _connectivityService.connectionStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

