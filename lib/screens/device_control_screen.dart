import 'dart:async'; // Потрібно для Timer
import 'package:flutter/material.dart';
import '../services/http_service.dart';

class DeviceControlScreen extends StatefulWidget {
  @override
  _DeviceControlScreenState createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final HttpControlService _httpService = HttpControlService();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Спочатку вантажимо збережений IP, потім запускаємо таймер
    _httpService.init().then((_) {
      _httpService.getSensorData();
    });

    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _httpService.getSensorData();
    });
  }

  @override
  void dispose() {
    // Обов'язково зупиняємо таймер, коли виходимо з екрану,
    // щоб не садити батарею телефону
    _pollingTimer?.cancel();
    _httpService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Smart Hybrid Control")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- ПАНЕЛЬ ДАНИХ ---
            Expanded(
              flex: 1, // Займає верхню частину
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
                          fontSize: 28,
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
                    "Керування Сервоприводом",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton(
                        Icons.lock_outline,
                        "Закрити (0°)",
                        Colors.redAccent,
                        "SERVO:0",
                      ),
                      _buildButton(
                        Icons.lock_open,
                        "Відкрити (90°)",
                        Colors.green,
                        "SERVO:90",
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
      onPressed: () => _httpService.sendCommand(cmd),
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
