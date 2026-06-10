import 'dart:typed_data';

import 'package:fahrplan/models/g1/commands.dart';

/// Device info commands for the G1 glasses
/// These commands fetch various information from the glasses

class DeviceInfoCommands {
  /// Get firmware information (0x23 74)
  /// Response is raw ASCII data starting with "net"
  static List<int> getFirmwareInfo() {
    return [Commands.GET_FIRMWARE_INFO, Commands.GET_FIRMWARE_INFO_SUB];
  }

  /// Get battery state (0x2C 01)
  /// Returns battery percentage and charging status
  static List<int> getBatteryState() {
    return [Commands.GET_BATTERY_STATE, Commands.GET_BATTERY_STATE_SUB];
  }

  /// Get brightness settings (0x29)
  /// Returns brightness value (0x00-0x2A) and auto brightness enabled (0x00/0x01)
  static List<int> getBrightness() {
    return [Commands.GET_BRIGHTNESS];
  }

  /// Get silent mode settings (0x2B)
  /// Returns silent mode enabled status
  static List<int> getSilentMode() {
    return [Commands.GET_SILENT_MODE];
  }

  /// Get anti-shake settings (0x2A)
  static List<int> getAntiShake() {
    return [Commands.GET_ANTI_SHAKE];
  }

  /// Get head-up activation angle settings (0x32)
  /// Returns the angle at which display turns on when looking up
  static List<int> getHeadUpAngle() {
    return [Commands.GET_HEADUP_ANGLE];
  }

  /// Get wear detection settings (0x3A)
  /// Returns whether wear detection is enabled
  static List<int> getWearDetection() {
    return [Commands.GET_WEAR_DETECTION];
  }

  /// Get display settings (0x3B)
  /// Returns screen height and depth values
  static List<int> getDisplaySettings() {
    return [Commands.GET_DISPLAY_SETTINGS];
  }

  /// Get time since boot in seconds (0x37)
  static List<int> getTimeSinceBoot() {
    return [Commands.GET_TIME_SINCE_BOOT];
  }

  /// Get buried point data (user usage tracking) (0x3E)
  static List<int> getBuriedPointData() {
    return [Commands.GET_BURIED_POINT_DATA];
  }

  /// Get MAC address information (0x2D)
  static List<int> getMacAddress() {
    return [Commands.GET_MAC_ADDRESS];
  }

  /// Get app whitelist settings (0x2E)
  static List<int> getAppWhitelist() {
    return [Commands.GET_APP_WHITELIST];
  }

  /// Get glasses serial number (0x33)
  static List<int> getGlassesSerial() {
    return [Commands.GET_GLASSES_SERIAL];
  }

  /// Get device serial number (0x34)
  static List<int> getDeviceSerial() {
    return [Commands.GET_DEVICE_SERIAL];
  }

  /// Get ESB channel information (0x35)
  static List<int> getEsbChannel() {
    return [Commands.GET_ESB_CHANNEL];
  }

  /// Get ESB channel notification count (0x36)
  static List<int> getEsbNotificationCount() {
    return [Commands.GET_ESB_NOTIFICATION_COUNT];
  }
}

/// Response parsers for device info responses
class DeviceInfoResponse {
  /// Parse battery response
  /// Returns map with percentage and charging status
  static Map<String, dynamic>? parseBatteryResponse(List<int> data) {
    if (data.length < 4) return null;
    if (data[0] != Commands.GET_BATTERY_STATE) return null;

    // Response format: [0x2C, 0x66?, percentage, ...]
    int percentage = data[2];
    bool isCharging = data.length > 4 && data[4] == 0x01;

    return {
      'percentage': percentage,
      'isCharging': isCharging,
    };
  }

  /// Parse brightness response
  /// Returns map with brightness value and auto brightness status
  static Map<String, dynamic>? parseBrightnessResponse(List<int> data) {
    if (data.length < 4) return null;
    if (data[0] != Commands.GET_BRIGHTNESS) return null;

    // Response format: [0x29, 0x65, brightness, autoEnabled]
    int brightness = data[2];
    bool autoBrightness = data[3] == 0x01;

    return {
      'brightness': brightness,
      'autoBrightness': autoBrightness,
    };
  }

  /// Parse silent mode response
  static Map<String, dynamic>? parseSilentModeResponse(List<int> data) {
    if (data.length < 4) return null;
    if (data[0] != Commands.GET_SILENT_MODE) return null;

    // Response format: [0x2B, 0x69, enabled, ??]
    // 0x0C = true, 0x0A = false
    bool enabled = data[2] == 0x0C;

    return {
      'enabled': enabled,
    };
  }

  /// Parse head-up angle response
  static Map<String, dynamic>? parseHeadUpAngleResponse(List<int> data) {
    if (data.length < 3) return null;
    if (data[0] != Commands.GET_HEADUP_ANGLE) return null;

    // Response format: [0x32, C9, enabled]
    bool enabled = data[2] == 0x01;

    return {
      'enabled': enabled,
    };
  }

  /// Parse wear detection response
  static Map<String, dynamic>? parseWearDetectionResponse(List<int> data) {
    if (data.length < 3) return null;
    if (data[0] != Commands.GET_WEAR_DETECTION) return null;

    // Response format: [0x3A, C9, enabled]
    bool enabled = data[2] == 0x01;

    return {
      'enabled': enabled,
    };
  }

  /// Parse display settings response
  static Map<String, dynamic>? parseDisplaySettingsResponse(List<int> data) {
    if (data.length < 4) return null;
    if (data[0] != Commands.GET_DISPLAY_SETTINGS) return null;

    // Response format: [0x3B, C9, height, depth]
    int height = data[2];
    int depth = data[3];

    return {
      'height': height,
      'depth': depth,
    };
  }

  /// Parse time since boot response (returns seconds)
  static int? parseTimeSinceBootResponse(List<int> data) {
    if (data.length < 5) return null;
    if (data[0] != Commands.GET_TIME_SINCE_BOOT) return null;

    // Response format: [0x37, ...payload...]
    // Payload is a 32-bit little-endian integer
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(data.sublist(1)));
    return byteData.getUint32(0, Endian.little);
  }

  /// Parse firmware info response (returns ASCII string)
  static String? parseFirmwareResponse(List<int> data) {
    if (data.length < 3) return null;
    if (data[0] != Commands.GET_FIRMWARE_INFO) return null;

    // Response is raw ASCII data starting with "net"
    try {
      String response = String.fromCharCodes(data.sublist(1));
      return response.trim().replaceAll('\u0000', '');
    } catch (e) {
      return null;
    }
  }
}
