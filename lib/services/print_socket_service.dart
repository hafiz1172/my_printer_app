import 'dart:io';
import 'dart:typed_data';

class PrintSocketService {
  /// Sends raw ESC/POS bytes to network thermal printer on Port 9100
  static Future<bool> sendBytesToPrinter({
    required String ipAddress,
    int port = 9100,
    required List<int> data,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ipAddress, port, timeout: timeout);
      socket.add(Uint8List.fromList(data));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint("Socket Error: $e");
      socket?.destroy();
      return false;
    }
  }
}

void debugPrint(String message) => stdout.writeln(message);
