import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let backgroundTaskIdentifier = "dev.maartje.fahrplan.heartbeat"

  var speechChannel: FlutterMethodChannel?
  var speechEventChannel: FlutterEventChannel?
  var backgroundTaskChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins early for BLE state restoration
    GeneratedPluginRegistrant.register(with: self)

    // Register background processing task for heartbeat/reconnect
    BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { [weak self] task in
      self?.handleBackgroundTask(task as! BGProcessingTask)
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      setupSpeechMethodChannel(controller: controller)
      setupSpeechEventChannels(controller: controller)
      setupBackgroundTaskChannel(controller: controller)

      // Setup WeatherKit for weather updates (iOS 16.0+)
      if #available(iOS 16.0, *) {
        WeatherKitManager.shared.setupChannel(with: controller)
      }
    }

    // Schedule the first heartbeat task; it will reschedule itself.
    scheduleBackgroundTask()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    scheduleBackgroundTask()
  }

  private func setupSpeechMethodChannel(controller: FlutterViewController) {
    speechChannel = FlutterMethodChannel(name: "dev.maartje.fahrplan/speech",
                                         binaryMessenger: controller.binaryMessenger)
    speechChannel?.setMethodCallHandler { (call, result) in
      switch call.method {
      case "startSpeechRecognition":
        if let args = call.arguments as? [String: Any],
           let language = args["language"] as? String {
          SpeechStreamRecognizer.shared.startRecognition(identifier: language)
          result(nil)
        } else {
          result(FlutterError(code: "InvalidArgs", message: "language required", details: nil))
        }
      case "appendAudio":
        if let audioData = call.arguments as? FlutterStandardTypedData {
          SpeechStreamRecognizer.shared.appendPCMData(audioData.data)
          result(nil)
        } else {
          result(FlutterError(code: "InvalidArgs", message: "audio data required", details: nil))
        }
      case "appendLC3Audio":
        if let audioData = call.arguments as? FlutterStandardTypedData {
          let pcmConverter = PcmConverter()
          let pcmData = pcmConverter.decode(audioData.data)
          guard pcmData.length > 0 else {
            result(nil)
            return
          }
          SpeechStreamRecognizer.shared.appendPCMData(pcmData as Data)
          result(nil)
        } else {
          result(FlutterError(code: "InvalidArgs", message: "audio data required", details: nil))
        }
      case "stopSpeechRecognition":
        SpeechStreamRecognizer.shared.stopRecognition { finalText in
          result(finalText)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupSpeechEventChannels(controller: FlutterViewController) {
    speechEventChannel = FlutterEventChannel(name: "dev.maartje.fahrplan/speech_events",
                                             binaryMessenger: controller.binaryMessenger)
    speechEventChannel?.setStreamHandler(SpeechEventStreamHandler.shared)
  }

  private func setupBackgroundTaskChannel(controller: FlutterViewController) {
    backgroundTaskChannel = FlutterMethodChannel(
      name: "dev.maartje.fahrplan/background_tasks",
      binaryMessenger: controller.binaryMessenger
    )
  }

  private func handleBackgroundTask(_ task: BGProcessingTask) {
    // Always schedule the next task before doing work.
    scheduleBackgroundTask()

    guard let channel = backgroundTaskChannel else {
      task.setTaskCompleted(success: false)
      return
    }

    let timeoutWorkItem = DispatchWorkItem { [weak task] in
      task?.setTaskCompleted(success: false)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeoutWorkItem)

    channel.invokeMethod("onBackgroundTask", arguments: nil) { result in
      timeoutWorkItem.cancel()
      task.setTaskCompleted(success: result != nil)
    }
  }

  private func scheduleBackgroundTask() {
    let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false
    // iOS decides when to run; ask for the earliest possible time.
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30)

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print(error)
    }
  }
}

// Stream handler for iOS native speech recognition partial results
class SpeechEventStreamHandler: NSObject, FlutterStreamHandler {
  static let shared = SpeechEventStreamHandler()
  var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    SpeechStreamRecognizer.shared.speechEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    SpeechStreamRecognizer.shared.speechEventSink = nil
    return nil
  }
}
