import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pendingURL: URL?
  private var pendingOptions: [UIApplication.OpenURLOptionsKey: Any]?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up notification center delegate for proper notification handling
    // This is crucial for handling notification taps on iOS
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle remote notifications in background
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Let Flutter handle the notification through Firebase Messaging
    // This ensures the notification data is properly processed
    // Super will call completionHandler() internally when it's done
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  // Handle notification taps when app is in foreground, background, or terminated
  // This is the key method for handling notification taps on iOS
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // Log notification tap for debugging
    print("🔔 [iOS] Notification tapped - ID: \(response.notification.request.identifier)")
    print("🔔 [iOS] Notification payload: \(userInfo)")
    
    // Call super to let Flutter plugins handle it (flutter_local_notifications)
    // Super WILL call completionHandler() internally when it's done
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  
  // Handle notifications when app is in foreground
  // This ensures notifications are displayed even when app is active
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    // This allows users to see and tap notifications
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
    
    // Also call super to let Flutter plugins handle it
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // If Flutter engine is not ready yet (cold start), defer URL handling
    guard let flutterEngine = (window?.rootViewController as? FlutterViewController)?.engine,
          flutterEngine.isolateId != nil else {
      // Store URL to process after Flutter is ready
      pendingURL = url
      pendingOptions = options
      
      // Schedule processing after a brief delay to allow Flutter to initialize
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.processPendingURL()
      }
      return true
    }
    
    // Flutter is ready, process URL normally
    return super.application(app, open: url, options: options)
  }
  
  private func processPendingURL() {
    guard let url = pendingURL else { return }
    let options = pendingOptions ?? [:]
    
    // Clear pending values
    pendingURL = nil
    pendingOptions = nil
    
    // Now process the URL with Flutter ready
    _ = super.application(UIApplication.shared, open: url, options: options)
  }
}
