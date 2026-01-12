import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpControlService {
  // АДРЕСА ТВОГО NODE.JS СЕРВЕРА
  final String serverBaseUrl = "https://kratis-p2p-server.onrender.com";
  final String deviceId = "esp32_device_01";

  String? _cachedLocalIp;

  // Потік для даних, щоб оновлювати UI
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logs => _logController.stream;

  // --- 1. ОТРИМАННЯ ДАНИХ (ТЕМПЕРАТУРА/ВОЛОГА) ---
  // Цю функцію ми будемо викликати кожні 5 секунд
  Future<void> getSensorData() async {
    bool success = false;

    // СПРОБА А: ЛОКАЛЬНО (Direct LAN)
    // Це пріоритет. Якщо працює - ми отримуємо дані миттєво і тримаємо ESP в Local Mode.
    if (_cachedLocalIp != null) {
      success = await _fetchLocalStatus();
    }

    // Якщо локального IP немає або він змінився/відпав
    if (!success) {
      // Спробуємо оновити IP через хмару і заодно забрати дані звідти
      await _syncWithCloud();
    }
  }

  // --- 2. ЛОКАЛЬНИЙ ЗАПИТ ---
  Future<bool> _fetchLocalStatus() async {
    try {
      // Таймаут 2 секунди.
      final uri = Uri.parse("http://$_cachedLocalIp/status");
      final response = await http.get(uri).timeout(Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _parseAndNotify(data, "LAN 🏠");
        return true; // Успіх
      }
    } catch (e) {
      // Якщо помилка - можливо IP змінився або ми вийшли з дому
      // _log("LAN fail: $e");
    }
    return false;
  }

  // --- 3. ХМАРНИЙ ЗАПИТ ---
  Future<void> _syncWithCloud() async {
    try {
      final uri = Uri.parse("$serverBaseUrl/api/status?id=$deviceId");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Оновлюємо кешований IP, якщо він там є
        if (data['local_ip'] != null) {
          _cachedLocalIp = data['local_ip'];
        }

        // Якщо в базі є дані сенсорів
        if (data['data'] != null) {
          _parseAndNotify(data['data'], "CLOUD ☁️");
        } else {
          _log("[CLOUD] Connected. Waiting for data...");
        }
      }
    } catch (e) {
      _log("❌ Offline");
    }
  }

  // --- 4. ВІДПРАВКА КОМАНДИ ---
  Future<void> sendCommand(String cmd) async {
    _log("Sending: $cmd...");

    // Спроба локально
    if (_cachedLocalIp != null) {
      try {
        final uri = Uri.parse("http://$_cachedLocalIp/cmd?val=$cmd");
        final response = await http.get(uri).timeout(Duration(seconds: 1));
        if (response.statusCode == 200) {
          _log("✅ Sent via LAN");
          // Одразу оновимо дані після команди
          getSensorData();
          return;
        }
      } catch (e) {}
    }

    // Спроба через хмару
    try {
      final uri = Uri.parse("$serverBaseUrl/api/command");
      await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"targetId": deviceId, "cmd": cmd}),
      );
      _log("✅ Queued via Cloud");
    } catch (e) {
      _log("❌ Error sending command");
    }
  }

  // Допоміжна функція для парсингу JSON і виводу на екран
  void _parseAndNotify(dynamic data, String source) {
    var t = data['temp'];
    var h = data['hum'];
    // Форматуємо рядок для UI
    String info = "[$source]\nT: $t°C  H: $h%";
    _logController.add(info);
  }

  void _log(String msg) {
    print("[HttpService] $msg");
    _logController.add(msg);
  }

  void dispose() {
    _logController.close();
  }
}
