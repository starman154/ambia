import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL_NAME = "com.ambia.live_activity"
  private var liveActivityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure window for edge-to-edge black background
    if let window = self.window {
      window.backgroundColor = UIColor.black
      window.frame = UIScreen.main.bounds

      if let rootViewController = window.rootViewController {
        rootViewController.view.backgroundColor = UIColor.black
        rootViewController.view.frame = UIScreen.main.bounds
      }
    }

    // Set up platform channel for Live Activities
    let controller = window?.rootViewController as! FlutterViewController
    controller.view.backgroundColor = UIColor.black
    controller.view.frame = UIScreen.main.bounds
    controller.viewRespectsSystemMinimumLayoutMargins = false
    if #available(iOS 11.0, *) {
      controller.view.insetsLayoutMarginsFromSafeArea = false
    }

    liveActivityChannel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: controller.binaryMessenger)

    liveActivityChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      self?.handleMethodCall(call: call, result: result)
    }

    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        print("[Ambia] Notification permissions granted")
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      } else if let error = error {
        print("[Ambia] Notification permission error: \(error)")
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle method calls from Flutter
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if #available(iOS 16.1, *) {
      switch call.method {
      case "startLiveActivity":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        let activityId = AmbiaLiveActivityManager.shared.startActivity(eventData: args)
        result(activityId)

      case "updateLiveActivity":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        AmbiaLiveActivityManager.shared.updateActivity(eventData: args)
        result(nil)

      case "endLiveActivity":
        AmbiaLiveActivityManager.shared.endActivity()
        result(nil)

      case "getActiveActivities":
        let activities = AmbiaLiveActivityManager.shared.getActiveActivities()
        result(activities)

      default:
        result(FlutterMethodNotImplemented)
      }
    } else {
      result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Live Activities require iOS 16.1+", details: nil))
    }
  }

  // Handle remote notifications
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("[Ambia] Device token: \(tokenString)")

    // Send token to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onDeviceTokenReceived", arguments: tokenString)
    }
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[Ambia] Failed to register for remote notifications: \(error)")
  }

  // Handle deep links from Live Activity taps
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("[Ambia] Deep link opened: \(url)")

    // Check if it's our ambient-info deep link
    if url.scheme == "ambia" && url.host == "ambient-info" {
      let eventId = url.lastPathComponent
      print("[Ambia] Live Activity tapped for event: \(eventId)")

      // Send to Flutter via method channel
      liveActivityChannel?.invokeMethod("onLiveActivityTapped", arguments: eventId)

      return true
    }

    return super.application(app, open: url, options: options)
  }
}
