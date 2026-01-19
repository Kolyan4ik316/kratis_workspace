import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpControlService {
  final String serverBaseUrl = "https://kratis-p2p-server.onrender.com";

  String? _cachedLocalIp;
  bool _isLanConnected = false;
  bool _isDisposed = false; // ✅ Додано прапорець стану

  // Потік для текстових логів
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logs => _logController.stream;

  // Потік для чистих даних (JSON)
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceDataStream => _dataController.stream;

  // --- ОТРИМАННЯ ДАНИХ ---
  Future<void> getSensorData(String targetDeviceId) async {
    if (_isDisposed) return; // ✅ Якщо сервіс знищено, не починаємо роботу

    // 1. Спроба LAN
    if (_cachedLocalIp != null) {
      bool success = await _fetchLocalStatus();
      if (success) {
        _isLanConnected = true;
        return;
      }
    }

    // 2. Якщо LAN немає -> Хмара
    _isLanConnected = false;
    await _syncWithCloud(targetDeviceId);

    // 3. Фонові спроби відновити LAN (тільки якщо не знищено)
    if (!_isLanConnected && _cachedLocalIp != null && !_isDisposed) {
      _fetchLocalStatus();
    }
  }

  // --- ЛОКАЛЬНИЙ ЗАПИТ ---
  Future<bool> _fetchLocalStatus() async {
    if (_isDisposed) return false;
    try {
      final uri = Uri.parse("http://$_cachedLocalIp/status");
      final response = await http
          .get(uri)
          .timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _processData(data, "LAN 🏠");
        return true;
      }
    } catch (e) {
      // LAN помилка
    }
    return false;
  }

  // --- ХМАРНИЙ ЗАПИТ ---
  Future<void> _syncWithCloud(String targetDeviceId) async {
    if (_isDisposed) return;
    try {
      final uri = Uri.parse("$serverBaseUrl/api/status?id=$targetDeviceId");
      final response = await http.get(uri);

      if (_isDisposed) return; // ✅ Перевірка після await

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Оновлюємо IP (якщо ESP повідомила новий локальний IP в хмару)
        if (data['local_ip'] != null && data['local_ip'] != _cachedLocalIp) {
          _cachedLocalIp = data['local_ip'];
          _log("New IP found: $_cachedLocalIp");
        }

        if (data['data'] != null) {
          _processData(data['data'], "CLOUD ☁️");
        }
      }
    } catch (e) {
      _log("❌ Network Error");
    }
  }

  // --- ВІДПРАВКА КОМАНДИ ---
  Future<void> sendCommand(String targetDeviceId, String cmd) async {
    if (_isDisposed) return;
    _log("Sending to $targetDeviceId: $cmd...");

    // 1. LAN
    if (_cachedLocalIp != null) {
      try {
        final uri = Uri.parse("http://$_cachedLocalIp/cmd?val=$cmd");
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 1));

        if (_isDisposed) return; // ✅ Перевірка після await

        if (response.statusCode == 200) {
          _log("✅ Sent via LAN");
          getSensorData(targetDeviceId);
          return;
        }
      } catch (e) {}
    }

    // 2. CLOUD
    try {
      final uri = Uri.parse("$serverBaseUrl/api/command");
      await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"targetId": targetDeviceId, "cmd": cmd}),
      );
      if (!_isDisposed) _log("✅ Queued via Cloud");
    } catch (e) {
      if (!_isDisposed) _log("❌ Cmd Failed");
    }
  }

  // Обробка вхідних даних
  void _processData(dynamic data, String source) {
    if (_isDisposed) return; // ✅ Захист

    if (data is Map<String, dynamic>) {
      // 1. Кидаємо в потік даних для UI (з перевіркою)
      if (!_dataController.isClosed) {
        _dataController.add(data);
      }

      // 2. Кидаємо в логи
      var t = data['temp'];
      var h = data['hum'];
      _log("[$source] T: $t°C  H: $h%");
    }
  }

  void _log(String msg) {
    print("[HttpService] $msg"); // Print працює завжди

    // ✅ А в Stream пишемо, тільки якщо він живий
    if (!_isDisposed && !_logController.isClosed) {
      _logController.add(msg);
    }
  }

  void dispose() {
    _isDisposed = true; // ✅ Ставимо мітку смерті
    _logController.close();
    _dataController.close();
  }

  Future<void> init() async {}
}
