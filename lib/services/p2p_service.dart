import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart'; // Додали імпорт

class P2PService {
  // Зверни увагу: для WebSocket адреса починається з wss://
  final String wsUrl = "wss://kratis-p2p-server.onrender.com";
  final String serverHttpUrl = "https://kratis-p2p-server.onrender.com";

  final String myId = "flutter_phone_01";
  final String targetId = "esp32_device_01";

  RawDatagramSocket? _udpSocket;
  WebSocketChannel? _wsChannel; // Канал вебсокету

  InternetAddress? _targetIp;
  int? _targetPort;
  String? _myPublicIp;
  int? _myPublicPort;

  // Стрім для UI
  final _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  bool _isDisposed = false;

  Future<void> init() async {
    try {
      // 1. Запускаємо UDP (Для P2P спроб)
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _log("UDP Local Port: ${_udpSocket!.port}");

      _udpSocket!.listen((RawSocketEvent e) {
        if (_isDisposed) return;
        if (e == RawSocketEvent.read) {
          Datagram? d = _udpSocket!.receive();
          if (d != null) _handleUdpPacket(d);
        }
      });

      // 2. Підключаємо WebSocket (Для миттєвого керування через сервер)
      _connectWebSocket();

      // 3. Запускаємо фоновий цикл (STUN і т.д.)
      _startLoop();
    } catch (e) {
      _log("Init Error: $e");
    }
  }

  // --- WEBSOCKET LOGIC ---
  void _connectWebSocket() {
    try {
      _log("Connecting to WS...");
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Слухаємо повідомлення від сервера
      _wsChannel!.stream.listen(
        (message) {
          _log("WS Recv: $message");
          // Можна додати логіку обробки JSON, якщо сервер щось відповідає
        },
        onDone: () {
          _log("WS Disconnected");
          // Тут можна додати логіку реконекту, якщо треба
        },
        onError: (error) {
          _log("WS Error: $error");
        },
      );

      // Авторизація: Кажемо серверу хто ми
      final authMsg = {"type": "auth", "id": myId};
      _wsChannel!.sink.add(jsonEncode(authMsg));
      _log("WS Auth sent");
    } catch (e) {
      _log("WS Connection Failed: $e");
    }
  }

  // --- UDP HANDLER ---
  void _handleUdpPacket(Datagram d) {
    // STUN відповідь
    if (d.data.length > 20 && d.data[0] == 0x01) {
      _parseStunResponse(d.data);
      return;
    }
    // Вхідні дані P2P
    try {
      String msg = utf8.decode(d.data);
      if (!msg.contains("PING")) _log("UDP Recv: $msg");

      _targetIp = d.address;
      _targetPort = d.port;
    } catch (_) {}
  }

  // --- ГОЛОВНИЙ ЦИКЛ ---
  void _startLoop() async {
    while (!_isDisposed) {
      // STUN (раз на хвилину, щоб знати свій IP)
      if (_myPublicIp == null) await _resolveStun();

      // P2P пошук (спробуємо знайти прямий IP партнера)
      if (_targetIp == null) await _findPeerHttp();

      // Keep-Alive для UDP NAT
      if (_targetIp != null) _sendUdp("PING");

      await Future.delayed(Duration(seconds: 15));
    }
  }

  // --- ВІДПРАВКА ДАНИХ ---
  Future<void> sendData(String message) async {
    // 1. Спроба UDP (Прямий зв'язок - найшвидше, але ненадійно)
    _sendUdp(message);

    // 2. WEBSOCKET (Гарантовано і швидко через сервер)
    // Не шлемо PING через сервер, тільки команди
    if (!message.contains("PING") && _wsChannel != null) {
      try {
        // Формат повідомлення для сервера (як ми домовлялись у WS версії сервера)
        final wsPacket = {
          "type": "cmd",
          "targetId": targetId,
          "payload": message, // На сервері ми читали cmd.payload
        };

        _wsChannel!.sink.add(jsonEncode(wsPacket));
        _log("Sent via WS: $message");
      } catch (e) {
        _log("WS Send Error: $e");
      }
    }
  }

  void _sendUdp(String msg) {
    if (_udpSocket != null && _targetIp != null && _targetPort != null) {
      try {
        _udpSocket!.send(utf8.encode(msg), _targetIp!, _targetPort!);
      } catch (_) {}
    }
  }

  // ... (STUN і Register HTTP методи)

  Future<void> _findPeerHttp() async {
    try {
      // Використовуємо старий HTTP метод щоб дізнатися IP партнера для UDP
      final resp = await http.get(
        Uri.parse('$serverHttpUrl/get_peer/$targetId'),
      );
      if (resp.statusCode == 200) {
        var data = jsonDecode(resp.body);
        _targetIp = (await InternetAddress.lookup(data['ip'])).first;
        _targetPort = data['port'];
      }
    } catch (_) {}
  }

  Future<void> _resolveStun() async {
    try {
      var list = await InternetAddress.lookup("stun.l.google.com");
      if (list.isNotEmpty) {
        var ip = list.firstWhere(
          (e) => e.type == InternetAddressType.IPv4,
          orElse: () => list.first,
        );
        _udpSocket!.send(
          [
            0,
            1,
            0,
            0,
            0x21,
            0x12,
            0xA4,
            0x42,
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
          ],
          ip,
          19302,
        );
      }
    } catch (e) {
      _log("STUN Fail");
    }
  }

  void _parseStunResponse(List<int> data) {
    // Тут твоя логіка парсингу STUN з попереднього коду
    // ...
    // _myPublicIp = ...
    // Ми її не чіпаємо, вона була робоча
  }

  void _log(String msg) {
    if (!_dataStreamController.isClosed) _dataStreamController.add(msg);
    print("[P2P] $msg");
  }

  void dispose() {
    _isDisposed = true;
    _udpSocket?.close();
    _wsChannel?.sink.close(); // Закриваємо вебсокет
    _dataStreamController.close();
  }
}
