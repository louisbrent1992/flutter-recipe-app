import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  // Singleton pattern
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request photo library permissions
  Future<bool> requestPhotosPermission() async {
    if (await Permission.photos.isGranted) {
      return true;
    }

    PermissionStatus status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Request multiple permissions at once
  Future<Map<Permission, PermissionStatus>> requestMultiplePermissions({
    bool camera = false,
    bool photos = false,
    bool notification = false,
  }) async {
    List<Permission> permissions = [];

    if (camera) permissions.add(Permission.camera);
    if (photos) permissions.add(Permission.photos);
    if (notification) permissions.add(Permission.notification);

    return await permissions.request();
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Open app settings
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Show rationale for requesting permissions
  Future<bool> shouldShowRationale(Permission permission) async {
    return await permission.shouldShowRequestRationale;
  }

  /// Show dialog explaining why permission is needed
  Future<bool> showPermissionRationaleDialog(
    BuildContext context,
    String title,
    String message,
    Permission permission,
  ) async {
    bool shouldShowRationale = await permission.shouldShowRequestRationale;

    if (shouldShowRationale && context.mounted) {
      bool? result = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not Now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            ),
      );

      return result ?? false;
    }

    return true;
  }
}
