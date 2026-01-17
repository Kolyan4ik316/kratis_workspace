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

  final String _myPhoneId = "android_user_001";

  Future<void> _sendConfigToEsp() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Підключення до пристрою...";
    });

    final ssid = _ssidController.text;
    final pass = _passController.text;

    try {
      final uri = Uri.parse("http://192.168.4.1/save");

      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "ssid": ssid,
              "pass": pass,
              "user_id": _myPhoneId,
            }),
          )
          .timeout(Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Парсимо відповідь для отримання ID
        final respData = jsonDecode(response.body);
        final String realDeviceId = respData['device_id'];

        setState(() {
          _statusMessage = "✅ Успіх! Отримано ID: $realDeviceId";
        });

        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          // Повертаємо map з даними
          Navigator.pop(context, {
            'success': true,
            'device_id': realDeviceId,
            'ssid': ssid,
            'pass': pass,
          });
        }
      } else {
        setState(() {
          _statusMessage = "Помилка ESP: ${response.statusCode}";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            "❌ Не вдалося з'єднатися.\nПеревірте WiFi 'Smart-Incubator'";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

              _buildStep(
                1,
                "Увімкніть режим налаштування",
                "Затисніть кнопку на платі на 3 секунди (SETUP MODE).",
              ),
              SizedBox(height: 15),
              _buildStep(
                2,
                "Підключіться до WiFi",
                "Мережа: Smart-Incubator, Пароль: 12345678",
              ),
              SizedBox(height: 15),
              _buildStep(
                3,
                "Дані вашого WiFi",
                "Введіть назву та пароль вашого роутера.",
              ),

              SizedBox(height: 20),

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
                  onPressed: _sendConfigToEsp,
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Text("ЗБЕРЕГТИ НАЛАШТУВАННЯ"),
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

  Widget _buildStep(int num, String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Крок $num: $title",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }
}
