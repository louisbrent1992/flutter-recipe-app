import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Test ad unit IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Android test ad unit ID
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // iOS test ad unit ID
      }
    } else {
      // Production ad unit IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-9981622851892833/2805281212';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-9981622851892833/2892637111';
      }
    }
    throw UnsupportedError('Unsupported platform');
  }
}
