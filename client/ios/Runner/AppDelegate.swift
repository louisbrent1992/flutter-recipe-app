import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pendingURL: URL?
  private var pendingOptions: [UIApplication.OpenURLOptionsKey: Any]?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
