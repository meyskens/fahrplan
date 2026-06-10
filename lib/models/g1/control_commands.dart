import 'package:fahrplan/models/g1/commands.dart';

/// Control commands for the G1 glasses
/// These commands control various aspects of the glasses

class ControlCommands {
  /// Send hard reset (0x23 72)
  /// Restarts the glasses. No response expected.
  static List<int> hardReset() {
    return [Commands.HARD_RESET, Commands.HARD_RESET_SUB];
  }

  /// Send heartbeat (0x25)
  /// Needs to be sent periodically to keep the device connected.
  /// Disconnection happens after 32 seconds, so send every 28-30 seconds.
  /// The heartbeat sequence is unique to heartbeats and different from global sequence.
  static List<int> heartbeat(int sequence) {
    return [Commands.HEARTBEAT, sequence & 0xFF];
  }

  /// Clear screen (0x18)
  /// Clears the screen of bitmaps. Also clears text.
  static List<int> clearScreen() {
    return [Commands.CLEAR_SCREEN];
  }

  /// Clear notification (0x4C)
  /// Clears the current notification on the glasses
  static List<int> clearNotification() {
    return [Commands.CLEAR_NOTIFICATION];
  }

  /// Dashboard lock (0x50)
  /// Locks the dashboard display
  static List<int> dashboardLock() {
    return [Commands.DASHBOARD_LOCK];
  }

  /// Initialize/Init command (0x4D)
  /// Sent to left arm only. Response is generic.
  static List<int> init() {
    return [Commands.INIT, 0xFB];
  }
}

/// Setter commands for configuring the glasses
class SetterCommands {
  /// Set brightness settings (0x01)
  /// Adjust the brightness level or enable/disable auto brightness.
  /// Send to right arm. Response is generic.
  /// brightness: 0x00 - 0x2A (0-42)
  /// autoBrightness: true/false
  static List<int> setBrightness(int brightness, bool autoBrightness) {
    // Clamp brightness to valid range
    brightness = brightness.clamp(0, 0x2A);
    return [
      Commands.BRIGHTNESS,
      brightness,
      autoBrightness ? 0x01 : 0x00,
    ];
  }

  /// Set silent mode (0x03)
  /// Activate or deactivate silent mode of the glasses.
  /// Send to both arms. Response is generic.
  static List<int> setSilentMode(bool enabled) {
    return [Commands.SILENT_MODE, enabled ? 0x0C : 0x0A];
  }

  /// Set head-up angle settings (0x0B)
  /// Sets the angle at which the display turns on when the wearer looks up.
  /// Send to right arm. Response is generic.
  /// angle: 0x00 - 0x3C (0-60 degrees)
  static List<int> setHeadUpAngle(int angle) {
    // Clamp angle to valid range
    angle = angle.clamp(0, 0x3C);
    return [
      Commands.HEADUP_ANGLE,
      angle,
      0x01, // Level? (always 0x01 based on protocol)
    ];
  }

  /// Set wear detection settings (0x27)
  /// Enable or disable wear detection.
  /// When enabled, additional 0xF5 messages are sent when worn or not.
  /// Response is generic.
  static List<int> setWearDetection(bool enabled) {
    return [Commands.GLASS_WEAR, enabled ? 0x01 : 0x00];
  }

  /// Set debug mode (0xF4)
  /// Enable or disable debug mode
  static List<int> setDebugMode(bool enabled) {
    return [Commands.DEBUG_MODE, enabled ? 0x01 : 0x00];
  }

  /// Send sequence synchronization number (0x22 05)
  /// Sets the global sequence. Sent periodically to the right lens.
  static List<int> syncSequence(int sequence) {
    return [
      Commands.SEQUENCE_SYNC,
      Commands.SEQUENCE_SYNC_SUB,
      0x00, // pad
      sequence & 0xFF,
      0x01,
    ];
  }

  /// Set display settings (0x26)
  /// Control the display's height and depth.
  /// Must be called twice: first with preview=1, then after a few seconds with preview=0.
  /// The glasses will stay on permanently until preview=0 is sent.
  /// height: 0x00 - 0x08
  /// depth: 0x01 - 0x09
  static List<int> setDisplaySettings({
    required int height,
    required int depth,
    required bool preview,
  }) {
    // Clamp values to valid ranges
    height = height.clamp(0, 0x08);
    depth = depth.clamp(1, 0x09);

    return [
      Commands.DASBOARD_POSITION,
      0x08, // subcommand?
      0x00, // pad
      0x00, // seq (will be set by caller)
      0x02, // ??
      preview ? 0x01 : 0x00,
      height,
      depth,
    ];
  }
}

/// Button configuration commands
/// These configure what happens on touchpad events
class ButtonConfigCommands {
  /// Set head-up action to none
  static List<int> setHeadUpNone() {
    return [0x08, 0x06, 0x00, 0x00, 0x03, 0x02];
  }

  /// Set head-up action to dashboard
  static List<int> setHeadUpDashboard() {
    return [0x08, 0x06, 0x00, 0x00, 0x03, 0x00];
  }

  /// Set double tap action to none
  static List<int> setDoubleTapNone() {
    return [0x26, 0x06, 0x00, 0x00, 0x05, 0x00];
  }

  /// Set double tap action to transcribe
  static List<int> setDoubleTapTranscribe() {
    return [0x26, 0x06, 0x00, 0x00, 0x05, 0x05];
  }

  /// Set double tap action to teleprompter
  static List<int> setDoubleTapTeleprompter() {
    return [0x26, 0x06, 0x00, 0x00, 0x05, 0x03];
  }

  /// Set double tap action to translate
  static List<int> setDoubleTapTranslate() {
    return [0x26, 0x06, 0x00, 0x00, 0x05, 0x02];
  }

  /// Set double tap action to dashboard
  static List<int> setDoubleTapDashboard() {
    return [0x26, 0x06, 0x00, 0x00, 0x05, 0x04];
  }
}

/// Calibration commands
class CalibrationCommands {
  /// Reset 0-degree position
  static List<int> resetZeroDegreePosition() {
    return [0x10, 0x05, 0x00, 0x04, 0x01];
  }

  /// Start calibration
  static List<int> startCalibration() {
    return [0x39, 0x05, 0x00, 0x5F, 0x01];
  }

  /// Acknowledge calibration on glasses
  static List<int> ackCalibration() {
    return [0x10, 0x07, 0x00, 0x0D, 0x02, 0x01, 0x01];
  }

  /// Complete calibration in app
  static List<int> completeCalibration() {
    return [0x10, 0x07, 0x00, 0x05, 0x02, 0x00, 0x00];
  }
}

/// Screen control commands
class ScreenCommands {
  /// Turn display on
  static List<int> turnDisplayOn() {
    return [0x39, 0x05, 0x00, 0x69, 0x01];
  }

  /// Turn display off
  static List<int> turnDisplayOff() {
    return [0x39, 0x05, 0x00, 0x69, 0x00];
  }
}
