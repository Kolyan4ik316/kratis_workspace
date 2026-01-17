import 'dart:async';
import 'package:flutter/material.dart';
import '../services/http_service.dart';
import '../models/kratis_models.dart'; // Import Device model

class DeviceControlScreen extends StatefulWidget {
  // Add Device parameter to know which ID to control
  final Device? device;

  // If device is null, we can fallback to a test ID or show error
  const DeviceControlScreen({super.key, this.device});

  @override
  _DeviceControlScreenState createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final HttpControlService _httpService = HttpControlService();
  Timer? _pollingTimer;

  // Fallback ID if no device is passed (e.g. for testing)
  String get deviceId => widget.device?.id ?? "esp32_device_01";

  @override
  void initState() {
    super.initState();
    // No need to call init() on service as it's empty now
    _fetchData();

    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchData();
    });
  }

  void _fetchData() {
    _httpService.getSensorData(deviceId);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _httpService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device?.name ?? "Smart Control")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- ПАНЕЛЬ ДАНИХ ---
            Expanded(
              flex: 1,
              child: Center(
                child: StreamBuilder<String>(
                  stream: _httpService.logs,
                  initialData: "Connecting...",
                  builder: (context, snapshot) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        snapshot.data ?? "--",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14, // Reduced font size for logs
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // --- КНОПКИ ---
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Керування: $deviceId",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton(
                        Icons.power_settings_new,
                        "OFF",
                        Colors.redAccent,
                        "RELAY:0", // Generic command
                      ),
                      _buildButton(
                        Icons.power,
                        "ON",
                        Colors.green,
                        "RELAY:1", // Generic command
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, Color color, String cmd) {
    return ElevatedButton.icon(
      onPressed: () => _httpService.sendCommand(deviceId, cmd),
      icon: Icon(icon, size: 28),
      label: Text(label, style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
