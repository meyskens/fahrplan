import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  var audioPlayer: AVAudioPlayer?
  var backgroundAudioEnabled = false
  var settingsChannel: FlutterMethodChannel?
  var bluetoothChannel: FlutterMethodChannel?
  var blueInfoChannel: FlutterEventChannel?
  var blueSpeechChannel: FlutterEventChannel?

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

      // Setup Bluetooth method channel for sending data to glasses
      setupBluetoothMethodChannel(controller: controller)

      // Setup event channels for Bluetooth data from glasses
      setupBluetoothEventChannels(controller: controller)

      // Setup WeatherKit for weather updates
      WeatherKitManager.shared.setupChannel(with: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupBluetoothMethodChannel(controller: FlutterViewController) {
    bluetoothChannel = FlutterMethodChannel(name: "dev.maartje.fahrplan/bluetooth",
                                           binaryMessenger: controller.binaryMessenger)
    bluetoothChannel?.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "startScan":
        BluetoothManager.shared.startScan(result: result)
      case "stopScan":
        BluetoothManager.shared.stopScan(result: result)
      case "connectToDevice":
        if let args = call.arguments as? [String: Any],
           let deviceName = args["deviceName"] as? String {
          BluetoothManager.shared.connectToDevice(deviceName: deviceName, result: result)
        } else {
          result(FlutterError(code: "InvalidArgs", message: "deviceName required", details: nil))
        }
      case "disconnectFromGlasses":
        BluetoothManager.shared.disconnectFromGlasses(result: result)
      case "sendData":
        if let args = call.arguments as? [String: Any] {
          BluetoothManager.shared.sendData(params: args)
        } else {
          result(FlutterError(code: "InvalidArgs", message: "data required", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Update the BluetoothManager's channel reference
    BluetoothManager.shared.channel = bluetoothChannel
  }

  private func setupBluetoothEventChannels(controller: FlutterViewController) {
    // Blue Info Channel - for button presses and commands from glasses
    blueInfoChannel = FlutterEventChannel(name: "dev.maartje.fahrplan/blue_info",
                                          binaryMessenger: controller.binaryMessenger)
    blueInfoChannel?.setStreamHandler(BlueInfoStreamHandler())

    // Blue Speech Channel - for transcribed speech from glasses
    blueSpeechChannel = FlutterEventChannel(name: "dev.maartje.fahrplan/blue_speech",
                                            binaryMessenger: controller.binaryMessenger)
    blueSpeechChannel?.setStreamHandler(BlueSpeechStreamHandler())
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

// Stream handler for Blue Info events (button presses, commands from glasses)
class BlueInfoStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    BluetoothManager.shared.blueInfoSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    BluetoothManager.shared.blueInfoSink = nil
    return nil
  }
}

// Stream handler for Blue Speech events (transcribed speech from glasses)
class BlueSpeechStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    BluetoothManager.shared.blueSpeechSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    BluetoothManager.shared.blueSpeechSink = nil
    return nil
  }
}
