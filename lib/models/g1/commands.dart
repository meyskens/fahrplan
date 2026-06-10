class Commands {
  // Control Commands
  static const int START_AI = 0xF5;
  static const int OPEN_MIC = 0x0E;
  static const int MIC_RESPONSE = 0x0E;
  static const int RECEIVE_MIC_DATA = 0xF1;
  static const int INIT = 0x4D;
  static const int HEARTBEAT = 0x25;
  static const int SEND_RESULT = 0x4E;
  static const int QUICK_NOTE = 0x21;
  static const int QUICK_NOTE_ADD = 0x1E;
  static const int DASHBOARD = 0x22;
  static const int NOTIFICATION = 0x4B;
  static const int CLEAR_NOTIFICATION = 0x4C;
  static const int DASHBOARD_LOCK = 0x50;
  static const int CLEAR_SCREEN = 0x18;
  static const int HARD_RESET = 0x23;
  static const int HARD_RESET_SUB = 0x72;

  // Setter Commands
  static const int SILENT_MODE = 0x03;
  static const int BRIGHTNESS = 0x01;
  static const int DASBOARD_POSITION = 0x26;
  static const int HEADUP_ANGLE = 0x0B;
  static const int DASBOARD_SHOW = 0x06;
  static const int GLASS_WEAR = 0x27;
  static const int BMP = 0x15;
  static const int CRC = 0x16;
  static const int SETUP = 0x04;
  static const int SEQUENCE_SYNC = 0x22;
  static const int SEQUENCE_SYNC_SUB = 0x05;
  static const int DEBUG_MODE = 0xF4;

  // Getter Commands
  static const int GET_FIRMWARE_INFO = 0x23;
  static const int GET_FIRMWARE_INFO_SUB = 0x74;
  static const int GET_BATTERY_STATE = 0x2C;
  static const int GET_BATTERY_STATE_SUB = 0x01;
  static const int GET_BRIGHTNESS = 0x29;
  static const int GET_SILENT_MODE = 0x2B;
  static const int GET_ANTI_SHAKE = 0x2A;
  static const int GET_HEADUP_ANGLE = 0x32;
  static const int GET_WEAR_DETECTION = 0x3A;
  static const int GET_DISPLAY_SETTINGS = 0x3B;
  static const int GET_TIME_SINCE_BOOT = 0x37;
  static const int GET_BURIED_POINT_DATA = 0x3E;
  static const int GET_MAC_ADDRESS = 0x2D;
  static const int GET_APP_WHITELIST = 0x2E;
  static const int GET_GLASSES_SERIAL = 0x33;
  static const int GET_DEVICE_SERIAL = 0x34;
  static const int GET_ESB_CHANNEL = 0x35;
  static const int GET_ESB_NOTIFICATION_COUNT = 0x36;

  // Response Status Codes
  static const int RESPONSE_SUCCESS = 0xC9;
  static const int RESPONSE_FAILURE = 0xCA;
  static const int RESPONSE_CONTINUE = 0xCB;
}
