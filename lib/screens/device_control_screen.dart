import 'package:flutter/material.dart';
import '../services/p2p_service.dart'; // Імпортуємо наш сервіс

class DeviceControlScreen extends StatefulWidget {
  @override
  _DeviceControlScreenState createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final P2PService _p2pService = P2PService();

  @override
  void initState() {
    super.initState();
    _p2pService.init(); // Запускаємо з'єднання при старті екрану
  }

  @override
  void dispose() {
    _p2pService.dispose(); // Закриваємо з'єднання при виході
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Розумний Дім (P2P)")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ВІДОБРАЖЕННЯ ДАНИХ
            StreamBuilder<String>(
              stream: _p2pService.dataStream,
              initialData: "Waiting for connection...",
              builder: (context, snapshot) {
                // Тут ми отримуємо дані від ESP32
                String data = snapshot.data ?? "No Data";
                return Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    data,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            SizedBox(height: 50),

            // КНОПКИ КЕРУВАННЯ
            Text("Керування Сервоприводом"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Надсилаємо команду на ESP32
                    _p2pService.sendData("SERVO:0");
                  },
                  child: Text("Закрити (0°)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Надсилаємо команду на ESP32
                    _p2pService.sendData("SERVO:90");
                  },
                  child: Text("Відкрити (90°)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
