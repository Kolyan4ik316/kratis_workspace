import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WifiSetupScreen extends StatefulWidget {
  @override
  _WifiSetupScreenState createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();

  String _statusMessage = "";
  bool _isLoading = false;

  // Унікальний ID телефону (можна генерувати UUID, тут для прикладу статичний)
  // В реальному додатку краще використовувати пакет device_info_plus або uuid
  final String _myPhoneId = "android_user_001";

  Future<void> _saveConfig() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Підключення до інкубатора...";
    });

    final ssid = _ssidController.text;
    final pass = _passController.text;

    try {
      // 1. Стукаємо на адресу ESP32 в режимі AP
      final uri = Uri.parse("http://192.168.4.1/save");

      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"}, // Важливо для ESP32
            body: jsonEncode({
              "ssid": ssid,
              "pass": pass,
              "user_id": _myPhoneId, // Відправляємо ID для прив'язки
            }),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = "✅ Збережено! Пристрій перезавантажується...";
        });

        // Повертаємось назад через 2 секунди
        Future.delayed(Duration(seconds: 2), () {
          Navigator.pop(context, true); // true означає успіх
        });
      } else {
        setState(() {
          _statusMessage = "Помилка ESP: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            "❌ Не можу знайти пристрій!\nПереконайтесь, що ви підключені до WiFi 'Smart-Incubator'";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Налаштування WiFi")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.wifi_tethering, size: 80, color: Colors.blue),
              SizedBox(height: 20),

              Text(
                "Крок 1: Увімкніть режим налаштування",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "Затисніть кнопку на платі на 3 секунди, поки не з'явиться 'APP SETUP MODE'.",
              ),
              SizedBox(height: 15),

              Text(
                "Крок 2: Підключіться до WiFi",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "Зайдіть в налаштування телефону і підключіться до мережі 'Smart-Incubator' (Пароль: 12345678).",
              ),
              SizedBox(height: 15),

              Text(
                "Крок 3: Введіть дані вашого Роутера",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),

              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: "Назва WiFi (SSID)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Пароль WiFi",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),

              SizedBox(height: 20),

              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveConfig,
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Text("ЗБЕРЕГТИ І ПРИВ'ЯЗАТИ"),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),

              SizedBox(height: 20),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains("❌")
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
