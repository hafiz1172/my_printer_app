import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/printer_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = false;

  final TextEditingController _ipController =
      TextEditingController(text: "192.168.1.100");
  final TextEditingController _portController =
      TextEditingController(text: "9100");
  final TextEditingController _urduController =
      TextEditingController(text: "شکریہ! آپ کا آرڈر مکمل ہو گیا ہے۔");

  ConnectionType _selectedMode = ConnectionType.bluetooth;
  PaperSize _paperSize = PaperSize.mm58;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    _loadPairedDevices();
  }

  Future<void> _loadPairedDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _printerService.getBondedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      _showToast("Bluetooth load error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(msg: msg, backgroundColor: Colors.black87);
  }

  Future<void> _connect() async {
    setState(() => _isLoading = true);
    bool success = false;

    if (_selectedMode == ConnectionType.bluetooth) {
      if (_selectedDevice == null) {
        _showToast("Select a Bluetooth device first");
        setState(() => _isLoading = false);
        return;
      }
      success = await _printerService.connectBluetooth(_selectedDevice!.address);
    } else {
      final port = int.tryParse(_portController.text) ?? 9100;
      success =
          await _printerService.connectWifi(_ipController.text.trim(), port);
    }

    setState(() => _isLoading = false);
    _showToast(
        success ? "Connected Successfully!" : "Failed to connect printer");
  }

  Future<void> _printReceipt() async {
    if (!_printerService.isConnected) {
      _showToast("Printer not connected");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final bytes = await _printerService.generateSampleReceipt(
        paperSize: _paperSize,
        shopName: "THE CHANGER STORE",
        title: "SALE INVOICE",
        items: [
          {'name': 'Wireless Earbuds', 'price': 2500.0},
          {'name': 'Smart Watch T800', 'price': 1800.0},
          {'name': 'Fast Cable Type-C', 'price': 450.0},
        ],
        total: 4750.0,
      );
      await _printerService.sendBytes(bytes);
      _showToast("Printed successfully");
    } catch (e) {
      _showToast("Print error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printUrdu() async {
    if (!_printerService.isConnected) {
      _showToast("Printer not connected");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final bytes = await _printerService.generateUrduReceiptImage(
        _urduController.text,
        _paperSize,
      );
      await _printerService.sendBytes(bytes);
      _showToast("Urdu receipt printed");
    } catch (e) {
      _showToast("Print error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("RawBT Driver Utility"),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: _printerService.isConnected
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _printerService.isConnected ? "ONLINE" : "OFFLINE",
                    style: TextStyle(
                      color: _printerService.isConnected
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Type Selector
            SegmentedButton<ConnectionType>(
              segments: const [
                ButtonSegment(
                  value: ConnectionType.bluetooth,
                  label: Text("Bluetooth"),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: ConnectionType.wifi,
                  label: Text("Wi-Fi / LAN"),
                  icon: Icon(Icons.wifi),
                ),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (set) {
                setState(() => _selectedMode = set.first);
              },
            ),
            const SizedBox(height: 16),

            // Connection Inputs
            if (_selectedMode == ConnectionType.bluetooth) ...[
              Card(
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<BluetoothDevice>(
                        dropdownColor: const Color(0xFF2C2C2C),
                        value: _selectedDevice,
                        hint: const Text("Select Paired Device",
                            style: TextStyle(color: Colors.white70)),
                        isExpanded: true,
                        items: _devices.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text("${d.name ?? 'Unknown'} (${d.address})",
                                style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedDevice = val),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadPairedDevices,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh Paired Devices"),
                      )
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: "Printer IP Address",
                            hintText: "192.168.1.100",
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Port",
                            hintText: "9100",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Connect & Disconnect Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _connect,
                    icon: const Icon(Icons.link),
                    label: Text(_isLoading ? "Connecting..." : "Connect Printer"),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {
                    _printerService.disconnect();
                    setState(() {});
                  },
                  icon: const Icon(Icons.link_off),
                  tooltip: "Disconnect",
                )
              ],
            ),
            const SizedBox(height: 24),

            // Paper Size Settings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Thermal Paper Size:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButton<PaperSize>(
                  value: _paperSize,
                  dropdownColor: const Color(0xFF2C2C2C),
                  items: const [
                    DropdownMenuItem(
                        value: PaperSize.mm58, child: Text("58mm (2-inch)")),
                    DropdownMenuItem(
                        value: PaperSize.mm80, child: Text("80mm (3-inch)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paperSize = val);
                  },
                )
              ],
            ),
            const Divider(color: Colors.white24, height: 32),

            // Print Operations
            const Text("Quick Actions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _isLoading ? null : _printReceipt,
              icon: const Icon(Icons.receipt_long),
              label: const Text("Print Full Standard Invoice"),
            ),
            const SizedBox(height: 16),

            // Urdu / RTL Bitmap Print Section
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Urdu / Arabic (RTL) Print",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urduController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: "اردو عبارت درج کریں",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent,
                      ),
                      onPressed: _isLoading ? null : _printUrdu,
                      icon: const Icon(Icons.translate),
                      label: const Text("Print Urdu as Graphic Bitmap"),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
