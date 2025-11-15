import 'dart:io';

import 'package:android_package_manager/android_package_manager.dart';
import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:fahrplan/models/g1/bmp.dart';
import 'package:fahrplan/models/g1/commands.dart';
import 'package:fahrplan/models/g1/crc.dart';
import 'package:fahrplan/models/g1/dashboard.dart';
import 'package:fahrplan/models/g1/setup.dart';
import 'package:fahrplan/services/dashboard_controller.dart';
import 'package:fahrplan/models/g1/note.dart';
import 'package:fahrplan/models/g1/notification.dart';

import 'package:fahrplan/services/notifications_listener.dart';
import 'package:fahrplan/services/stops_manager.dart';
import 'package:fahrplan/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/constants.dart';
import '../models/g1/glass.dart';

/* Bluetooth Magnager is the heart of the application
  * It is responsible for scanning for the glasses and connecting to them
  * It also handles the connection state of the glasses
  * It allows for sending commands to the glasses
  */

typedef OnUpdate = void Function(String message);

class BluetoothManager {
  static final BluetoothManager singleton = BluetoothManager._internal();

  factory BluetoothManager() {
    return singleton;
  }

  BluetoothManager._internal() {
    notificationListener = AndroidNotificationsListener(
      onData: _handleAndroidNotification,
    );

    notificationListener!.startListening();
  }

  FahrplanDashboard fahrplanDashboard = FahrplanDashboard();
  DashboardController dashboardController = DashboardController();
  StopsManager stopsManager = StopsManager();

  Timer? _syncTimer;
  Completer<void>? _currentTextOperation;

  Glass? leftGlass;
  Glass? rightGlass;

  AndroidNotificationsListener? notificationListener;

  get isConnected =>
      leftGlass?.isConnected == true && rightGlass?.isConnected == true;
  get isScanning => _isScanning;

  Timer? _scanTimer;
  bool _isScanning = false;
  int _retryCount = 0;
  static const int maxRetries = 3;

  Future<String?> _getLastG1UsedUid(GlassSide side) async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(side == GlassSide.left ? 'left' : 'right');
  }

  Future<String?> _getLastG1UsedName(GlassSide side) async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(side == GlassSide.left ? 'leftName' : 'rightName');
  }

  Future<void> _saveLastG1Used(GlassSide side, String name, String uid) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(side == GlassSide.left ? 'left' : 'right', uid);
    await pref.setString(
        side == GlassSide.left ? 'leftName' : 'rightName', name);
  }

  Future<void> initialize() async {
    FlutterBluePlus.setLogLevel(LogLevel.none);
    await fahrplanDashboard.initialize();
    stopsManager.reload();
    _syncTimer ??= Timer.periodic(const Duration(minutes: 1), (timer) {
      _sync();
    });
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    Map<Permission, PermissionStatus> statuses = await [
      //Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((status) => status.isDenied)) {
      throw Exception(
          'All permissions are required to use Bluetooth. Please enable them in the app settings.');
    }

    if (statuses.values.any((status) => status.isPermanentlyDenied)) {
      await openAppSettings();
      throw Exception(
          'All permissions are required to use Bluetooth. Please enable them in the app settings.');
    }
  }

  Future<bool> requestMicrophonePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true; // Desktop platforms don't need explicit permission requests
    }

    PermissionStatus status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }

  Future<void> attemptReconnectFromStorage() async {
    await initialize();

    final leftUid = await _getLastG1UsedUid(GlassSide.left);
    final rightUid = await _getLastG1UsedUid(GlassSide.right);

    if (leftUid != null) {
      leftGlass = Glass(
        name: await _getLastG1UsedName(GlassSide.left) ?? 'Left Glass',
        device: BluetoothDevice(remoteId: DeviceIdentifier(leftUid)),
        side: GlassSide.left,
      );
      await leftGlass!.connect();
      _setReconnect(leftGlass!);
    }

    if (rightUid != null) {
      rightGlass = Glass(
        name: await _getLastG1UsedName(GlassSide.right) ?? 'Right Glass',
        device: BluetoothDevice(remoteId: DeviceIdentifier(rightUid)),
        side: GlassSide.right,
      );
      await rightGlass!.connect();
      _setReconnect(rightGlass!);
    }
  }

  Future<void> startScanAndConnect({
    required OnUpdate onUpdate,
  }) async {
    try {
      // this will fail in backround mode
      await _requestPermissions();
    } catch (e) {
      onUpdate(e.toString());
    }

    if (!await FlutterBluePlus.isAvailable) {
      onUpdate('Bluetooth is not available');
      throw Exception('Bluetooth is not available');
    }

    if (!await FlutterBluePlus.isOn) {
      onUpdate('Bluetooth is turned off');
      throw Exception('Bluetooth is turned off');
    }

    // Reset state
    _isScanning = true;
    _retryCount = 0;
    leftGlass = null;
    rightGlass = null;

    await _startScan(onUpdate);
  }

  Future<void> _startScan(OnUpdate onUpdate) async {
    await FlutterBluePlus.stopScan();
    debugPrint('Starting new scan attempt ${_retryCount + 1}/$maxRetries');

    // Set scan timeout
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 30), () {
      if (_isScanning) {
        _handleScanTimeout(onUpdate);
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
      androidUsesFineLocation: true,
    );

    // Listen for scan results
    FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult result in results) {
          String deviceName = result.device.name;
          String deviceId = result.device.id.id;
          debugPrint('Found device: $deviceName ($deviceId)');

          if (deviceName.isNotEmpty) {
            _handleDeviceFound(result, onUpdate);
          }
        }
      },
      onError: (error) {
        debugPrint('Scan results error: $error');
        onUpdate(error.toString());
      },
    );

    // Monitor scanning state
    FlutterBluePlus.isScanning.listen((isScanning) {
      debugPrint('Scanning state changed: $isScanning');
      if (!isScanning && _isScanning) {
        _handleScanComplete(onUpdate);
      }
    });
  }

  void _handleDeviceFound(ScanResult result, OnUpdate onUpdate) async {
    String deviceName = result.device.name;
    Glass? glass;
    if (deviceName.contains('_L_') && leftGlass == null) {
      debugPrint('Found left glass: $deviceName');
      glass = Glass(
        name: deviceName,
        device: result.device,
        side: GlassSide.left,
      );
      leftGlass = glass;
      onUpdate("Left glass found: ${glass.name}");
      await _saveLastG1Used(GlassSide.left, glass.name, glass.device.id.id);
    } else if (deviceName.contains('_R_') && rightGlass == null) {
      debugPrint('Found right glass: $deviceName');
      glass = Glass(
        name: deviceName,
        device: result.device,
        side: GlassSide.right,
      );
      rightGlass = glass;
      onUpdate("Right glass found: ${glass.name}");
      await _saveLastG1Used(GlassSide.right, glass.name, glass.device.id.id);
    }
    if (glass != null) {
      await glass.connect();

      _setReconnect(glass);
    }

    // Stop scanning if both glasses are found
    if (leftGlass != null && rightGlass != null) {
      _isScanning = false;
      stopScanning();
      _sync();
    }
  }

  void _setReconnect(Glass glass) {
    glass.device.connectionState.listen((BluetoothConnectionState state) {
      debugPrint('[${glass.side} Glass] Connection state: $state');
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint(
            '[${glass.side} Glass] Disconnected, attempting to reconnect...');
        glass.connect();
      }
    });
  }

  void _handleScanTimeout(OnUpdate onUpdate) async {
    debugPrint('Scan timeout occurred');

    if (_retryCount < maxRetries && (leftGlass == null || rightGlass == null)) {
      _retryCount++;
      debugPrint('Retrying scan (Attempt $_retryCount/$maxRetries)');
      await _startScan(onUpdate);
    } else {
      _isScanning = false;
      stopScanning();
      onUpdate(leftGlass == null && rightGlass == null
          ? 'No glasses found'
          : 'Scan completed');
    }
  }

  void _handleScanComplete(OnUpdate onUpdate) {
    if (_isScanning && (leftGlass == null || rightGlass == null)) {
      _handleScanTimeout(onUpdate);
    }
  }

  Future<void> connectToDevice(BluetoothDevice device,
      {required String side}) async {
    try {
      debugPrint('Attempting to connect to $side glass: ${device.name}');
      await device.connect(timeout: const Duration(seconds: 15));
      debugPrint('Connected to $side glass: ${device.name}');

      List<BluetoothService> services = await device.discoverServices();
      debugPrint('Discovered ${services.length} services for $side glass');

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() ==
            BluetoothConstants.UART_SERVICE_UUID) {
          debugPrint('Found UART service for $side glass');
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() ==
                BluetoothConstants.UART_TX_CHAR_UUID) {
              debugPrint('Found TX characteristic for $side glass');
            } else if (characteristic.uuid.toString().toUpperCase() ==
                BluetoothConstants.UART_RX_CHAR_UUID) {
              debugPrint('Found RX characteristic for $side glass');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error connecting to $side glass: $e');
      await device.disconnect();
      rethrow;
    }
  }

  void stopScanning() {
    _scanTimer?.cancel();
    FlutterBluePlus.stopScan().then((_) {
      debugPrint('Stopped scanning');
      _isScanning = false;
    }).catchError((error) {
      debugPrint('Error stopping scan: $error');
    });
  }

  Future<void> sendCommandToGlasses(List<int> command) async {
    if (leftGlass != null) {
      await leftGlass!.sendData(command);
      await Future.delayed(Duration(milliseconds: 100));
    }
    if (rightGlass != null) {
      await rightGlass!.sendData(command);
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  Future<void> sendText(String text,
      {Duration delay = const Duration(seconds: 5),
      bool clearOnComplete = true}) async {
    if (!isConnected) {
      debugPrint('Not connected to glasses');
      return;
    }

    // Cancel any existing text operation
    if (_currentTextOperation != null && !_currentTextOperation!.isCompleted) {
      _currentTextOperation!.complete();
      debugPrint('Cancelled previous text operation');
    }

    // Create new completer for this operation
    _currentTextOperation = Completer<void>();

    if (text.trim().isEmpty) {
      await clearScreen();
      return;
    }

    List<List<int>> chunks = _createTextWallChunks(text);
    await _sendChunks(chunks, delay, clearOnComplete);
  }

  static const int _TEXT_COMMAND = 0x4E;
  static const int _DISPLAY_WIDTH = 488;
  static const int _LINES_PER_SCREEN = 5;
  static const int _MAX_CHUNK_SIZE = 176;
  int _textSeqNum = 0;

  List<List<int>> _createTextWallChunks(String text) {
    int margin = 5;

    // Get width of single space character
    int spaceWidth = _calculateTextWidth(" ");

    // Calculate effective display width after accounting for margins
    int marginWidth = margin * spaceWidth;
    int effectiveWidth = _DISPLAY_WIDTH - (2 * marginWidth);

    // Split text into lines based on effective display width
    List<String> lines = _splitIntoLines(text, effectiveWidth);

    // Calculate total pages (hardcoded to 1 for now)
    //int totalPages = 1;
    int totalPages =
        (lines.length / _LINES_PER_SCREEN).ceil(); // 5 lines per page

    print("Total pages: $totalPages");

    List<List<int>> allChunks = [];

    for (int i = 0; i < totalPages; i++) {
      // Process the single page
      int page = i;

      // Get lines for current page
      int startLine = page * _LINES_PER_SCREEN;
      int endLine = (startLine + _LINES_PER_SCREEN).clamp(0, lines.length);
      List<String> pageLines = lines.sublist(startLine, endLine);

      // Combine lines for this page with proper indentation
      StringBuffer pageText = StringBuffer();

      for (String line in pageLines) {
        // Add the exact number of spaces for indentation
        String indentation = " " * margin;
        pageText.write(indentation + line + "\n");
      }

      List<int> textBytes = pageText.toString().codeUnits;
      int totalChunks = (textBytes.length / _MAX_CHUNK_SIZE).ceil();

      // Create chunks for this page
      for (int i = 0; i < totalChunks; i++) {
        int start = i * _MAX_CHUNK_SIZE;
        int end = (start + _MAX_CHUNK_SIZE).clamp(0, textBytes.length);
        List<int> payloadChunk = textBytes.sublist(start, end);

        // Create header with protocol specifications
        int screenStatus = 0x71; // New content (0x01) + Text Show (0x70)
        List<int> header = [
          _TEXT_COMMAND, // Command type
          _textSeqNum, // Sequence number
          totalChunks, // Total packages
          i, // Current package number
          screenStatus, // Screen status
          0x00, // new_char_pos0 (high)
          0x00, // new_char_pos1 (low)
          page, // Current page number
          totalPages // Max page number
        ];

        // Combine header and payload
        List<int> chunk = [...header, ...payloadChunk];
        allChunks.add(chunk);
      }

      // Increment sequence number for next page
      _textSeqNum = (_textSeqNum + 1) % 256;
    }

    return allChunks;
  }

  int _calculateTextWidth(String text) {
    // Simplified width calculation - in a real implementation,
    // this would use actual font metrics
    return text.length * 12; // Approximate character width
  }

  List<String> _splitIntoLines(String text, int maxDisplayWidth) {
    // Replace specific symbols
    text = text.replaceAll("⬆", "^").replaceAll("⟶", "-");

    List<String> lines = [];

    // Handle empty or single space case
    if (text.isEmpty || text == " ") {
      lines.add(text);
      return lines;
    }

    // Split by newlines first
    List<String> rawLines = text.split("\n");

    for (String rawLine in rawLines) {
      // Add empty lines for newlines
      if (rawLine.isEmpty) {
        lines.add("");
        continue;
      }

      int lineLength = rawLine.length;
      int startIndex = 0;

      while (startIndex < lineLength) {
        // Get maximum possible end index
        int endIndex = lineLength;

        // Calculate width of the entire remaining text
        int lineWidth = _calculateSubstringWidth(rawLine, startIndex, endIndex);

        // If entire line fits, add it and move to next line
        if (lineWidth <= maxDisplayWidth) {
          lines.add(rawLine.substring(startIndex));
          break;
        }

        // Binary search to find the maximum number of characters that fit
        int left = startIndex + 1;
        int right = lineLength;
        int bestSplitIndex = startIndex + 1;

        while (left <= right) {
          int mid = left + ((right - left) / 2).floor();
          int width = _calculateSubstringWidth(rawLine, startIndex, mid);

          if (width <= maxDisplayWidth) {
            bestSplitIndex = mid;
            left = mid + 1;
          } else {
            right = mid - 1;
          }
        }

        // Now find a good place to break (preferably at a space)
        int splitIndex = bestSplitIndex;

        // Look for a space to break at
        bool foundSpace = false;
        for (int i = bestSplitIndex; i > startIndex; i--) {
          if (rawLine[i - 1] == ' ') {
            splitIndex = i;
            foundSpace = true;
            break;
          }
        }

        // If we couldn't find a space in a reasonable range, use the calculated split point
        if (!foundSpace && bestSplitIndex - startIndex > 2) {
          splitIndex = bestSplitIndex;
        }

        // Add the line
        String line = rawLine.substring(startIndex, splitIndex).trim();
        lines.add(line);

        // Skip any spaces at the beginning of the next line
        while (splitIndex < lineLength && rawLine[splitIndex] == ' ') {
          splitIndex++;
        }

        startIndex = splitIndex;
      }
    }

    return lines;
  }

  int _calculateSubstringWidth(String text, int start, int end) {
    return _calculateTextWidth(text.substring(start, end));
  }

  Future<void> _sendChunks(
      List<List<int>> chunks, Duration delay, bool clearOnComplete) async {
    final currentOperation = _currentTextOperation;
    
    // Send each chunk with a delay between sends
    for (int i = 0; i < chunks.length; i++) {
      // Check if operation was cancelled
      if (currentOperation != null && currentOperation.isCompleted) {
        debugPrint('Text operation cancelled at chunk ${i + 1}/${chunks.length}');
        return;
      }
      
      await sendCommandToGlasses(chunks[i]);
      
      // Only delay if not the last chunk or if we need to clear
      if (i < chunks.length - 1 || clearOnComplete) {
        await Future.delayed(delay);
      }
    }
    
    if (clearOnComplete) {
      // Check one more time before clearing
      if (currentOperation != null && currentOperation.isCompleted) {
        debugPrint('Text operation cancelled before clear');
        return;
      }
      clearScreen();
    }
  }

  Future<void> setDashboardLayout(List<int> option) async {
    // concat the command with the option
    List<int> command = DashboardLayout.DASHBOARD_CHANGE_COMMAND.toList();
    command.addAll(option);

    await sendCommandToGlasses(command);
  }

  Future<void> sendNote(Note note) async {
    List<int> noteBytes = note.buildAddCommand();
    await sendCommandToGlasses(noteBytes);
  }

  Future<void> sendBitmap(Uint8List bitmap) async {
    List<Uint8List> textBytes = Utils.divideUint8List(bitmap, 194);

    List<List<int>?> sentPackets = [];

    debugPrint("Transmitting BMP");
    for (int i = 0; i < textBytes.length; i++) {
      sentPackets.add(await _sendBmpPacket(dataChunk: textBytes[i], seq: i));
      await Future.delayed(Duration(milliseconds: 100));
    }

    debugPrint("Send end packet");
    await _sendPacketEndPacket();
    await Future.delayed(Duration(milliseconds: 500));

    List<int> concatenatedList = [];
    for (var packet in sentPackets) {
      if (packet != null) {
        concatenatedList.addAll(packet);
      }
    }
    Uint8List concatenatedPackets = Uint8List.fromList(concatenatedList);

    debugPrint("Sending CRC for mitmap");
    // Send CRC
    await _sendCRCPacket(packets: concatenatedPackets);
  }

  // Send a notification to the glasses
  Future<void> sendNotification(NCSNotification notification) async {
    G1Notification notif = G1Notification(ncsNotification: notification);
    List<Uint8List> notificationChunks = await notif.constructNotification();

    for (Uint8List chunk in notificationChunks) {
      await sendCommandToGlasses(chunk);
      await Future.delayed(
          Duration(milliseconds: 50)); // Small delay between chunks
    }
  }

  Future<String> _getAppDisplayName(String packageName) async {
    final pm = AndroidPackageManager();
    final name = await pm.getApplicationLabel(packageName: packageName);

    return name ?? packageName;
  }

  void _handleAndroidNotification(ServiceNotificationEvent notification) async {
    debugPrint(
        'Received notification: ${notification.toString()} from ${notification.packageName}');
    if (isConnected) {
      NCSNotification ncsNotification = NCSNotification(
        msgId: (notification.id ?? 1) + DateTime.now().millisecondsSinceEpoch,
        action: 0,
        type: 0,
        appIdentifier: notification.packageName ?? 'dev.maartje.fahrplan',
        title: notification.title ?? '',
        subtitle: '',
        message: notification.content ?? '',
        displayName: await _getAppDisplayName(notification.packageName ?? ''),
      );

      sendNotification(ncsNotification);
    }
  }

  Future<List<int>?> _sendBmpPacket({
    required Uint8List dataChunk,
    int seq = 0,
  }) async {
    BmpPacket result = BmpPacket(
      seq: seq,
      data: dataChunk,
    );

    List<int> bmpCommand = result.build();

    if (seq == 0) {
      // Insert the 4 required bytes
      bmpCommand.insertAll(2, [0x00, 0x1c, 0x00, 0x00]);
    }

    try {
      sendCommandToGlasses(bmpCommand);
      return bmpCommand;
    } catch (e) {
      return null;
    }
  }

  int _crc32(Uint8List data) {
    var crc = Crc32();
    crc.add(data);
    return crc.close();
  }

  Future<List<int>?> _sendCRCPacket({
    required Uint8List packets,
  }) async {
    Uint8List crcData = Uint8List.fromList([...packets]);

    int crc32Checksum = _crc32(crcData) & 0xFFFFFFFF;
    Uint8List crc32Bytes = Uint8List(4);
    crc32Bytes[0] = (crc32Checksum >> 24) & 0xFF;
    crc32Bytes[1] = (crc32Checksum >> 16) & 0xFF;
    crc32Bytes[2] = (crc32Checksum >> 8) & 0xFF;
    crc32Bytes[3] = crc32Checksum & 0xFF;

    CrcPacket result = CrcPacket(
      data: crc32Bytes,
    );

    List<int> crcCommand = result.build();

    try {
      await leftGlass!.sendData(crcCommand);
      // wait for a reply to be sent over the crcReplies stream
      //await leftGlass!.replies.stream.firstWhere((d) => d[0] == Commands.CRC);
      debugPrint('CRC reply received from left glass');

      await rightGlass!.sendData(crcCommand);
      //await rightGlass!.replies.stream.firstWhere((d) => d[0] == Commands.CRC);
      debugPrint('CRC reply received from right glass');

      return crcCommand;
    } catch (e) {
      return null;
    }
  }

  Future<bool?> _sendPacketEndPacket() async {
    try {
      await leftGlass!.sendData([0x20, 0x0d, 0x0e]);
      //await leftGlass!.replies.stream.firstWhere((d) => d[0] == 0x20);
      await rightGlass!.sendData([0x20, 0x0d, 0x0e]);
      //await rightGlass!.replies.stream.firstWhere((d) => d[0] == 0x20);
    } catch (e) {
      debugPrint('Error in sendTextPacket: $e');
      return false;
    }
    return null;
  }

  Future<void> sync() async {
    await _sync();
  }

  Future<void> _sync() async {
    if (!isConnected) {
      return;
    }

    final notes = await fahrplanDashboard.generateDashboardItems();
    for (var note in notes) {
      await sendNote(note);
    }

    // remove other notes if there are less than 4
    // so old notes are not shown
    if (notes.length < 4) {
      for (int i = notes.length; i < 4; i++) {
        final note = Note(
          noteNumber: i + 1,
          name: 'Empty',
          text: '',
        );
        await sendCommandToGlasses(note.buildDeleteCommand());
      }
    }

    final dash = await dashboardController.updateDashboardCommand();
    for (var command in dash) {
      await sendCommandToGlasses(command);
    }

    // every 10 minutes sync G1Setup
    if (DateTime.now().minute % 10 == 0) {
      final setup = await G1Setup.generateSetup().constructSetup();
      for (var command in setup) {
        await sendCommandToGlasses(command);
      }
    }
  }

  Future<void> setMicrophone(bool open) async {
    final subCommand = open ? 0x01 : 0x00;

    // for an unknown issue the microphone will not close when sent to the left side
    // to work around this we send the command to the right side only
    await rightGlass!.sendData([Commands.OPEN_MIC, subCommand]);
  }

  Future<void> clearScreen() async {
    await sendCommandToGlasses([0x18]);
  }
}
