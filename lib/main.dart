import 'package:flutter/material.dart';
import 'services/esc_pos_engine.dart';
import 'services/print_socket_service.dart';
import 'services/local_http_server.dart';

void main() {
  runApp(const MaterialApp(
    home: ThermalUtilityDashboard(),
    debugShowCheckedModeBanner: false,
  ));
}

class ThermalUtilityDashboard extends StatefulWidget {
  const ThermalUtilityDashboard({super.key});

  @override
  State<ThermalUtilityDashboard> createState() => _ThermalUtilityDashboardState();
}

class _ThermalUtilityDashboardState extends State<ThermalUtilityDashboard> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.100');
  final TextEditingController _textController = TextEditingController(text: 'کاؤنٹر بل: 1,500 روپے\nشکریہ!');
  LocalHttpPrintServer? _httpServer;
  bool _serverRunning = false;
  String _logs = "Ready";

  @override
  void initState() {
    super.initState();
    _startLocalServer();
  }

  void _startLocalServer() async {
    _httpServer = LocalHttpPrintServer(onPrintRequested: (text) {
      _executePrint(text);
    });
    await _httpServer?.start();
    setState(() => _serverRunning = true);
  }

  Future<void> _executePrint(String text) async {
    setState(() => _logs = "Rendering bitmap with Urdu RTL...");
    
    // Convert Urdu/English text to ESC/POS Bit image (58mm = 384 dots)
    final printBytes = await EscPosEngine.textToThermalBytes(
      text: text,
      paperWidthDots: 384,
      fontSize: 26,
    );

    List<int> fullPayload = [];
    fullPayload.addAll(printBytes);
    fullPayload.addAll(EscPosEngine.cutPaper);

    setState(() => _logs = "Sending payload to ${_ipController.text}:9100...");
    final success = await PrintSocketService.sendBytesToPrinter(
      ipAddress: _ipController.text.trim(),
      data: fullPayload,
    );

    setState(() => _logs = success ? "Printed successfully!" : "Connection Failed.");
  }

  @override
  void dispose() {
    _httpServer?.stop();
    _ipController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Utility (RawBT Engine)'),
        backgroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.dns, color: _serverRunning ? Colors.green : Colors.red),
                title: const Text('Local Webhook Server'),
                subtitle: const Text('Listening on http://localhost:40213/print'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Printer IP Address (Port 9100)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Print Data (Supports Urdu / English)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt / Bitmap Test'),
              onPressed: () => _executePrint(_textController.text),
            ),
            const SizedBox(height: 20),
            Text('Logs: $_logs', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
