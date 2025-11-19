import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Generate a 1-bit monochrome BMP from image data
///
/// [imageData] - Raw image bytes (PNG, JPG, etc.)
/// [width] - Target canvas width
/// [height] - Target canvas height
/// [backgroundColor] - Canvas background color (default: white)
/// [scaleToFit] - If true, scales image to fit height and centers horizontally
Future<Uint8List> generateBMPFromImageData(
  Uint8List imageData, {
  int width = 576,
  int height = 136,
  ui.Color backgroundColor = const ui.Color(0xFFFFFFFF),
  bool scaleToFit = true,
  String? debugFileName,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Draw background
  final backgroundPaint = ui.Paint()..color = backgroundColor;
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      backgroundPaint);

  // Decode and draw the image
  final codec = await ui.instantiateImageCodec(imageData);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  if (scaleToFit) {
    // Scale to fit height and center horizontally
    final scale = height / image.height;
    final dstRect = ui.Rect.fromLTWH(
      (width - image.width * scale) / 2,
      0,
      image.width * scale,
      height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dstRect,
      ui.Paint(),
    );
  } else {
    // Draw at original size
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
  }

  // Draw DEBUG text
  final textStyle = ui.TextStyle(
    color: ui.Color(0xFF000000), // Black text
    fontSize: 20,
  );
  final paragraphStyle = ui.ParagraphStyle(textAlign: ui.TextAlign.left);
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(textStyle)
    ..addText("DEBUG");
  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: width.toDouble()));
  canvas.drawParagraph(paragraph, ui.Offset(10, 10));

  // Convert to an image
  final picture = recorder.endRecording();
  final byteData = await (await picture.toImage(width, height))
      .toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgbaData = byteData!.buffer.asUint8List();

  // Invert RGB channels (leave alpha unchanged) so this generated BMP is color-inverted
  final invertedRgba = Uint8List(rgbaData.length);
  for (int i = 0; i < rgbaData.length; i += 4) {
    // R,G,B
    invertedRgba[i] = 255 - rgbaData[i];
    invertedRgba[i + 1] = 255 - rgbaData[i + 1];
    invertedRgba[i + 2] = 255 - rgbaData[i + 2];
    // Preserve alpha
    invertedRgba[i + 3] = rgbaData[i + 3];
  }

  // Convert inverted RGBA to 1-bit monochrome (0=black, 1=white)
  final bmpData = _convertRgbaTo1Bit(invertedRgba, width, height);

  // Build the BMP headers and combine
  final bmpBytes = _build1BitBmp(width, height, bmpData);

  // Save BMP temporarily to disk for debugging if filename provided
  if (debugFileName != null) {
    print('generateBMPFromImageData: ${width}x${height}, file: $debugFileName');
    await _saveBitmapToDisk(bmpBytes, debugFileName);
  }

  //return generateDemoBMP(
  //  canvasWidth: width,
  //  canvasHeight: height,
  //);

  return bmpBytes;
}

/// Legacy wrapper for Bad Apple demo - loads frame from assets
Future<Uint8List> generateBadAppleBMP(int frameNumber) async {
  final frameStr = frameNumber.toString().padLeft(3, '0');
  final ByteData data = await rootBundle.load('assets/badapple/$frameStr.jpg');
  final bytes = data.buffer.asUint8List();

  return generateBMPFromImageData(
    bytes,
    debugFileName: 'badapple_$frameStr.bmp',
  );
}

Future<Uint8List> generateDemoBMP(
    {int canvasWidth = 576, int canvasHeight = 136}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Draw background (black)
  final backgroundPaint = ui.Paint()
    ..color = const ui.Color.fromARGB(255, 255, 255, 255);
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      backgroundPaint);

  // Draw text in white
  final textStyle =
      ui.TextStyle(color: ui.Color.fromARGB(255, 0, 0, 0), fontSize: 24);
  final paragraphStyle = ui.ParagraphStyle(textAlign: ui.TextAlign.center);
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(textStyle)
    ..addText("Hello World!");

  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: canvasWidth.toDouble()));
  canvas.drawParagraph(paragraph, ui.Offset(0, canvasHeight / 2));

  // Convert to an image
  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasWidth, canvasHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgbaData = byteData!.buffer.asUint8List();

  // Convert RGBA to 1-bit monochrome (0=black, 1=white)
  final bmpData = _convertRgbaTo1Bit(rgbaData, canvasWidth, canvasHeight);

  // Build the BMP headers and combine
  final bmpBytes = _build1BitBmp(canvasWidth, canvasHeight, bmpData);

  // Save BMP temporarily to disk for debugging
  //_saveBitmapToDisk(bmpBytes, 'demo.bmp');

  return bmpBytes;
}

Future<Uint8List> generateNavigationBMP(
    String maneuver, double distance) async {
  const canvasWidth = 576;
  const canvasHeight = 136;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Draw background (black)
  final backgroundPaint = ui.Paint()..color = const ui.Color(0xFF000000);
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      backgroundPaint);

  // Draw icon
  final iconData = await _loadManeuverIcon(maneuver);
  if (iconData != null) {
    final ui.Image image = await decodeImage(iconData);
    final iconSize = 80.0;
    final iconRect = ui.Rect.fromCenter(
      center: ui.Offset(canvasWidth / 2, canvasHeight / 3),
      width: iconSize,
      height: iconSize,
    );
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      iconRect,
      ui.Paint(),
    );
  }

  // Draw distance text in white
  final textStyle = ui.TextStyle(color: ui.Color(0xFFFFFFFF), fontSize: 24);
  final paragraphStyle = ui.ParagraphStyle(textAlign: ui.TextAlign.center);
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(textStyle)
    ..addText("${distance.toStringAsFixed(1)} m");
  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: canvasWidth.toDouble()));
  canvas.drawParagraph(paragraph, ui.Offset(0, canvasHeight * 0.7));

  // Convert to an image
  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasWidth, canvasHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgbaData = byteData!.buffer.asUint8List();

  // Convert RGBA to 1-bit monochrome (0=black, 1=white)
  final bmpData = _convertRgbaTo1Bit(rgbaData, canvasWidth, canvasHeight);

  // Build the BMP headers and combine
  final bmpBytes = _build1BitBmp(canvasWidth, canvasHeight, bmpData);

  // Save BMP temporarily to disk for debugging
  await _saveBitmapToDisk(bmpBytes, 'navigation.bmp');

  return bmpBytes;
}

// Load and decode image
Future<ui.Image> decodeImage(Uint8List imageData) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(imageData, completer.complete);
  return completer.future;
}

Future<Uint8List?> _loadManeuverIcon(String maneuver) async {
  final iconPath = 'assets/icons/$maneuver.png';
  try {
    final data = await rootBundle.load(iconPath);
    return data.buffer.asUint8List();
  } catch (e) {
    print("Error loading icon: $e");
    return null;
  }
}

/// Save bitmap to disk for debugging purposes
/// On Android, saves to /storage/emulated/0/Download/ which is accessible via adb pull
Future<void> _saveBitmapToDisk(Uint8List bmpData, String fileName) async {
  try {
    Directory? directory;
    if (Platform.isAndroid) {
      // Use Downloads directory on Android for easy adb pull access
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final filePath = '${directory!.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bmpData);
    print('Bitmap saved at $filePath');
  } catch (e) {
    print('Error saving bitmap to disk: $e');
  }
}

/// Convert RGBA to 1-bit (threshold at ~50% brightness)
Uint8List _convertRgbaTo1Bit(Uint8List rgba, int width, int height) {
  final bytesPerRow = width ~/ 8;
  final output = Uint8List(bytesPerRow * height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      final r = rgba[index];
      final g = rgba[index + 1];
      final b = rgba[index + 2];

      final brightness = (r + g + b) / 3;
      final bit = brightness > 128 ? 1 : 0;

      final invertedY = (height - 1 - y);
      final outRowStart = invertedY * bytesPerRow;
      final byteIndex = outRowStart + (x ~/ 8);
      final bitOffset = 7 - (x % 8);
      output[byteIndex] |= (bit << bitOffset);
    }
  }
  return output;
}

/// Build a 1-bit BMP file with a monochrome palette
Uint8List _build1BitBmp(int width, int height, Uint8List bmpData) {
  final headerSize = 62;
  final bytesPerRow = width ~/ 8;
  final imageSize = bytesPerRow * height;
  final fileSize = headerSize + imageSize;

  final file = BytesBuilder();

  file.addByte(0x42); // 'B'
  file.addByte(0x4D); // 'M'
  file.add(_int32le(fileSize));
  file.add(_int16le(0)); // reserved
  file.add(_int16le(0)); // reserved
  file.add(_int32le(headerSize)); // offset to pixels

  file.add(_int32le(40)); // biSize
  file.add(_int32le(width));
  file.add(_int32le(height));
  file.add(_int16le(1));
  file.add(_int16le(1));
  file.add(_int32le(0));
  file.add(_int32le(imageSize));
  file.add(_int32le(0));
  file.add(_int32le(0));
  file.add(_int32le(2));
  file.add(_int32le(2));

  file.add([0x00, 0x00, 0x00, 0x00]);
  file.add([0xFF, 0xFF, 0xFF, 0x00]);

  file.add(bmpData);

  return file.toBytes();
}

Uint8List _int32le(int value) {
  final b = Uint8List(4);
  final bd = b.buffer.asByteData();
  bd.setInt32(0, value, Endian.little);
  return b;
}

Uint8List _int16le(int value) {
  final b = Uint8List(2);
  final bd = b.buffer.asByteData();
  bd.setInt16(0, value, Endian.little);
  return b;
}
