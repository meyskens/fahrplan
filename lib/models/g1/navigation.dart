import 'dart:typed_data';

class Navigation {
  // Singleton instance
  static final Navigation _instance = Navigation._internal();

  // Private constructor
  Navigation._internal();

  // Factory constructor to return the singleton instance
  factory Navigation() => _instance;

  int _seqId = 0;
  int _pollerSeqId = 1;

  /// Initialize navigation mode
  Uint8List initData() {
    final part = <int>[0x00, _seqId, 0x00, 0x01];
    final data = <int>[0x0A, part.length + 2, ...part];
    _seqId = (_seqId + 1) % 256;
    return Uint8List.fromList(data);
  }

  /// Send navigation directions with distance and speed information
  Uint8List directionsData({
    required String totalDuration,
    required String totalDistance,
    required String direction,
    required String distance,
    required String speed,
    required int directionTurn,
    List<int>? customX,
    int customY = 0x00,
  }) {
    const unknown1 = 0x01;
    final x = customX ?? [0x00, 0x00];
    final y = customY;

    final totalDurationData = _stringToUint8List(totalDuration);
    final totalDistanceData = _stringToUint8List(totalDistance);
    final directionData = _stringToUint8List(direction);
    final distanceData = _stringToUint8List(distance);
    final speedData = _stringToUint8List(speed);

    final part0 = <int>[0x00, _seqId, unknown1, directionTurn, ...x, y, 0x00];
    final part = <int>[
      ...part0,
      ...totalDurationData,
      0x00,
      ...totalDistanceData,
      0x00,
      ...directionData,
      0x00,
      ...distanceData,
      0x00,
      ...speedData,
      0x00,
    ];

    final data = <int>[0x0A, part.length + 2, ...part];
    _seqId = (_seqId + 1) % 256;
    return Uint8List.fromList(data);
  }

  /// Send primary navigation image (136x136 pixels)
  /// Both image and overlay must be 136*136 = 18496 bits (booleans)
  List<Uint8List> primaryImageData({
    required List<int> image,
    required List<int> overlay,
  }) {
    const partType2 = 0x02;
    final combinedBits = [...image, ...overlay];
    final imageBytes = _runLengthEncode(combinedBits);

    const maxLength = 185;
    final chunks = _chunkList(imageBytes, maxLength);
    final packetCount = chunks.length;

    final result = <Uint8List>[];
    for (int i = 0; i < chunks.length; i++) {
      final packetNum = i + 1;
      final part = <int>[
        0x00,
        _seqId,
        partType2,
        packetCount,
        0x00,
        packetNum,
        0x00,
        ...chunks[i],
      ];
      _seqId = (_seqId + 1) % 256;
      result.add(Uint8List.fromList([0x0A, part.length + 2, ...part]));
    }

    return result;
  }

  /// Send secondary navigation image (488x136 pixels)
  /// Both image and overlay must be 488*136 = 66368 bits (booleans)
  List<Uint8List> secondaryImageData({
    required List<int> image,
    required List<int> overlay,
  }) {
    const partType3 = 0x03;
    final imageBytes = [...image, ...overlay];

    const maxLength = 185;
    final chunks = _chunkList(imageBytes, maxLength);
    final packetCount = chunks.length;

    final result = <Uint8List>[];
    for (int i = 0; i < chunks.length; i++) {
      final packetNum = i + 1;
      final part = <int>[
        0x00,
        _seqId,
        partType3,
        packetCount,
        0x00,
        packetNum,
        0x00,
        0x00,
        ...chunks[i],
      ];
      _seqId = (_seqId + 1) % 256;
      result.add(Uint8List.fromList([0x0A, part.length + 2, ...part]));
    }

    return result;
  }

  /// Send navigation poller data
  Uint8List pollerData() {
    const partType4 = 0x04;
    final part = <int>[0x00, _seqId, partType4, _pollerSeqId];
    _seqId = (_seqId + 1) % 256;
    _pollerSeqId = (_pollerSeqId + 1) % 256;
    return Uint8List.fromList([0x0A, part.length + 2, ...part]);
  }

  /// End navigation mode
  Uint8List endData() {
    const partType5 = 0x05;
    final part = <int>[0x00, _seqId, partType5, 0x01];
    _seqId = (_seqId + 1) % 256;
    return Uint8List.fromList([0x0A, part.length + 2, ...part]);
  }

  /// Helper: Convert string to UTF-8 bytes
  List<int> _stringToUint8List(String text) {
    return text.codeUnits;
  }

  /// Helper: Run-length encoding for image compression
  List<int> _runLengthEncode(List<int> data) {
    if (data.isEmpty) return [];

    final encoded = <int>[];
    int count = 1;
    int current = data[0];

    for (int i = 1; i < data.length; i++) {
      if (data[i] == current && count < 255) {
        count++;
      } else {
        encoded.add(count);
        encoded.add(current);
        current = data[i];
        count = 1;
      }
    }

    // Add the last run
    encoded.add(count);
    encoded.add(current);

    return encoded;
  }

  /// Helper: Chunk a list into smaller sublists
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}

/// Direction turn types for navigation
class DirectionTurn {
  static const int straightDot = 0x01;
  static const int straight = 0x02;
  static const int right = 0x03;
  static const int left = 0x04;
  static const int slightRight = 0x05;
  static const int slightLeft = 0x06;
  static const int strongRight = 0x07;
  static const int strongLeft = 0x08;
  static const int uTurnLeft = 0x09;
  static const int uTurnRight = 0x0A;
  static const int merge = 0x0B;
  static const int rightLaneRightStrongAtRoundabout = 0x0C;
  static const int leftLaneRightStrongAtRoundabout = 0x0D;
  static const int rightLaneRightAtRoundabout = 0x0E;
  static const int leftLaneRightAtRoundabout = 0x0F;
  static const int rightLaneSlightRightAtRoundabout = 0x10;
  static const int leftLaneSlightRightAtRoundabout = 0x11;
  static const int rightLaneStraightAtRoundabout = 0x12;
  static const int leftLaneStraightAtRoundabout = 0x13;
  static const int rightLaneSlightLeftAtRoundabout = 0x14;
  static const int leftLaneSlightLeftAtRoundabout = 0x15;
  static const int rightLaneLeftAtRoundabout = 0x16;
  static const int leftLaneLeftAtRoundabout = 0x17;
  static const int rightLaneStrongLeftAtRoundabout = 0x18;
  static const int leftLaneStrongLeftAtRoundabout = 0x19;
  static const int rightLaneUTurnAtRoundabout = 0x1A;
  static const int leftLaneUTurnAtRoundabout = 0x1B;
  static const int rightLaneEnterRoundabout = 0x1C;
  static const int leftLaneEnterRoundabout = 0x1D;
  static const int rightLaneExitRoundabout = 0x1E;
  static const int leftLaneExitRoundabout = 0x1F;
  static const int rightOfframp = 0x20;
  static const int leftOfframp = 0x21;
  static const int slightRightAtFork = 0x22;
  static const int slightLeftAtFork = 0x23;
}
