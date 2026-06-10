import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  var audioPlayer: AVAudioPlayer?
  var backgroundAudioEnabled = false
  var settingsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins early for BLE state restoration
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channel for settings communication
    if let controller = window?.rootViewController as? FlutterViewController {
      settingsChannel = FlutterMethodChannel(name: "dev.maartje.fahrplan/settings",
                                              binaryMessenger: controller.binaryMessenger)
      settingsChannel?.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "setBackgroundAudioEnabled" {
          if let args = call.arguments as? [String: Any],
             let enabled = args["enabled"] as? Bool {
            self?.backgroundAudioEnabled = enabled
          }
          result(nil)
        } else if call.method == "isBackgroundAudioEnabled" {
          result(self?.backgroundAudioEnabled ?? false)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Only start silent audio if enabled in settings
    guard backgroundAudioEnabled else { return }

    // Start silent audio keep-alive to maintain BLE connection in background
    // This is the same technique used by the official Even app
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)

      // Create a silent audio player (1 second of silence, looped)
      if let url = Bundle.main.url(forResource: "silence", withExtension: "mp3") {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = -1  // Loop indefinitely
        audioPlayer?.volume = 0.0        // Silent
        audioPlayer?.play()
      }
    } catch {
      print("Audio keepalive error: \(error)")
    }
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    // Stop the silent audio when returning to foreground
    audioPlayer?.stop()
    audioPlayer = nil
  }
}
