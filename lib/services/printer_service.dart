import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

enum ConnectionType { bluetooth, wifi }

class PrinterService {
  Socket? _wifiSocket;
  ConnectionType activeType = ConnectionType.bluetooth;

  Future<bool> isConnected() async {
    if (activeType == ConnectionType.bluetooth) {
      return await PrintBluetoothThermal.connectionStatus;
    } else {
      return _wifiSocket != null;
    }
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connectBluetooth(String macAddress) async {
    disconnect();
    final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    activeType = ConnectionType.bluetooth;
    return result;
  }

  Future<bool> connectWifi(String host, int port) async {
    disconnect();
    try {
      _wifiSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      activeType = ConnectionType.wifi;
      return true;
    } catch (e) {
      return false;
    }
  }

  void disconnect() {
    if (activeType == ConnectionType.bluetooth) {
      PrintBluetoothThermal.disconnect;
    }
    _wifiSocket?.destroy();
    _wifiSocket = null;
  }

  Future<void> sendBytes(List<int> bytes) async {
    if (activeType == ConnectionType.bluetooth) {
      await PrintBluetoothThermal.writeBytes(bytes);
    } else if (activeType == ConnectionType.wifi && _wifiSocket != null) {
      _wifiSocket!.add(bytes);
      await _wifiSocket!.flush();
    }
  }

  Future<List<int>> generateSampleReceipt({
    required PaperSize paperSize,
    required String title,
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(
      shopName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(title, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    for (var item in items) {
      bytes += generator.row([
        PosColumn(text: item['name'].toString(), width: 8),
        PosColumn(
          text: item['price'].toString(),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: total.toStringAsFixed(2),
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]);
    bytes += generator.feed(1);
    bytes += generator.qrcode('https://github.com', size: QRSize.size4, align: PosAlign.center);
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> generateUrduReceiptImage(String urduText, PaperSize paperSize) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 384.0;
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, 150), paint);

    final textSpan = TextSpan(
      text: urduText,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );

    textPainter.layout(maxWidth: width);
    textPainter.paint(canvas, const Offset(10, 40));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width.toInt(), 150);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) return [];

    final image = img.Image.fromBytes(
      width: width.toInt(),
      height: 150,
      bytes: byteData.buffer,
      order: img.ChannelOrder.rgba,
    );

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.imageRaster(image);
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }
}
