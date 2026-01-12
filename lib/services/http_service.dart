import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpControlService {
  final String serverBaseUrl = "https://kratis-p2p-server.onrender.com";
  final String deviceId = "esp32_device_01";

  // IP зберігається тільки в оперативній пам'яті.
  // При перезапуску додатка він скидається, і ми знову питаємо сервер.
  String? _cachedLocalIp;
  bool _isLanConnected = false;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logs => _logController.stream;

  // --- ГОЛОВНИЙ ЦИКЛ (Викликається таймером кожні 5 сек) ---
  Future<void> getSensorData() async {
    // 1. Спроба LAN (Пріоритет)
    // Працює, тільки якщо ми вже дізналися IP під час цієї сесії
    if (_cachedLocalIp != null) {
      bool success = await _fetchLocalStatus();
      if (success) {
        _isLanConnected = true;
        return; // Якщо LAN ок - сервер не чіпаємо
      }
    }

    // 2. Якщо IP ще не знаємо або LAN відпав -> Йдемо в Хмару
    _isLanConnected = false;
    await _syncWithCloud();

    // 3. Якщо Хмара дала нам IP -> Спробуємо LAN ще раз (фоново)
    if (!_isLanConnected && _cachedLocalIp != null) {
      _fetchLocalStatus();
    }
  }

  // --- ЛОКАЛЬНИЙ ЗАПИТ ---
  Future<bool> _fetchLocalStatus() async {
    try {
      final uri = Uri.parse("http://$_cachedLocalIp/status");
      // Короткий таймаут (1.5с)
      final response = await http
          .get(uri)
          .timeout(Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _parseAndNotify(data, "LAN 🏠");
        return true;
      }
    } catch (e) {
      // LAN помилка
    }
    return false;
  }

  // --- ХМАРНИЙ ЗАПИТ ---
  Future<void> _syncWithCloud() async {
    try {
      final uri = Uri.parse("$serverBaseUrl/api/status?id=$deviceId");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Оновлюємо IP в пам'яті
        if (data['local_ip'] != null && data['local_ip'] != _cachedLocalIp) {
          _cachedLocalIp = data['local_ip'];
          _log("New IP found in Cloud: $_cachedLocalIp");
        }

        if (data['data'] != null) {
          _parseAndNotify(data['data'], "CLOUD ☁️");
        } else {
          _log("[CLOUD] Waiting for device...");
        }
      }
    } catch (e) {
      _log("❌ Network Error");
    }
  }

  // --- ВІДПРАВКА КОМАНДИ ---
  Future<void> sendCommand(String cmd) async {
    _log("Sending: $cmd...");

    // Спроба локально
    if (_cachedLocalIp != null) {
      try {
        final uri = Uri.parse("http://$_cachedLocalIp/cmd?val=$cmd");
        final response = await http.get(uri).timeout(Duration(seconds: 1));
        if (response.statusCode == 200) {
          _log("✅ Sent via LAN");
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
      _log("❌ Cmd Failed");
    }
  }

  void _parseAndNotify(dynamic data, String source) {
    var t = data['temp'];
    var h = data['hum'];
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

  Future<void> init() async {
    // Тут було завантаження shared_preferences.
    // Зараз просто повертаємось, бо зберігати нічого не треба.
    return;
  }
}
