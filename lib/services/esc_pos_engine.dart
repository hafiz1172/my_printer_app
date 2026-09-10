import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class EscPosEngine {
  // ESC/POS Basic Commands
  static const List<int> initPrinter = [0x1B, 0x40];
  static const List<int> cutPaper = [0x1D, 0x56, 0x42, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> lineFeed = [0x0A];

  /// Render Urdu or complex text into a Monochrome Bitmap (ESC/POS compatible)
  static Future<Uint8List> textToThermalBytes({
    required String text,
    required int paperWidthDots, // 384 for 58mm, 576 for 80mm
    double fontSize = 24.0,
    TextAlign align = TextAlign.center,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.white;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: align,
      textDirection: TextDirection.rtl, // RTL support for Urdu
    );

    textPainter.layout(maxWidth: paperWidthDots.toDouble());
    
    // Draw background
    final height = textPainter.height.ceilToDouble() + 10;
    canvas.drawRect(Rect.fromLTWH(0, 0, paperWidthDots.toDouble(), height), paint);
    textPainter.paint(canvas, const Offset(0, 5));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(paperWidthDots, height.toInt());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    
    if (byteData == null) return Uint8List(0);

    final rawImage = img.Image.fromBytes(
      width: paperWidthDots,
      height: height.toInt(),
      bytes: byteData.buffer,
      order: img.ChannelOrder.rgba,
    );

    return imageToRasterBytes(rawImage);
  }

  /// Converts standard image to ESC/POS 'GS v 0' raster bit image
  static Uint8List imageToRasterBytes(img.Image src) {
    final grayscale = img.grayscale(src);
    final width = grayscale.width;
    final height = grayscale.height;
    final widthBytes = (width + 7) ~/ 8;

    List<int> bytes = [];
    bytes.addAll(initPrinter);
    
    // GS v 0 m xL xH yL yH
    bytes.addAll([
      0x1D, 0x76, 0x30, 0x00,
      widthBytes % 256, (widthBytes ~/ 256) % 256,
      height % 256, (height ~/ 256) % 256,
    ]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < widthBytes; x++) {
        int byte = 0;
        for (int b = 0; b < 8; b++) {
          int pixelX = x * 8 + b;
          if (pixelX < width) {
            final pixel = grayscale.getPixel(pixelX, y);
            // Luminance thresholding (Floyd-Steinberg can be applied here)
            if (pixel.luminance < 128) {
              byte |= (1 << (7 - b));
            }
          }
        }
        bytes.add(byte);
      }
    }

    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);
    return Uint8List.fromList(bytes);
  }
}
