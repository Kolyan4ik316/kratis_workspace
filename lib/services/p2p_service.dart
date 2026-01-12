import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class P2PService {
  final String wsUrl = "wss://kratis-p2p-server.onrender.com";
  final String myId = "flutter_phone_01";
  final String targetId = "esp32_device_01";
  final String stunHost = 'stun.l.google.com';
  final int stunPort = 19302;

  WebSocketChannel? _wsChannel;
  RawDatagramSocket? _udpSocket;

  // Адреси телефону
  String? _myPublicIp;
  int? _myPublicPort;
  String? _myLocalIp;
  int? _myLocalPort;

  // Адреса цілі (ESP32)
  InternetAddress? _targetIp;
  int? _targetPort;

  final _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  bool _isDisposed = false;

  // Стан з'єднання
  bool _gotUdpPacket = false;
  Timer? _connectionWatchdog; // Таймер для виявлення втрати з'єднання

  // Для дедуплікації логів
  String _lastWsLog = "";

  // Лічильник для чергування IP
  int _strategyTick = 0;

  Future<void> init() async {
    _log("--- SERVICE STARTED (HYBRID MODE: WEIGHTED IP) ---");

    try {
      // 1. Визначаємо локальну IP
      _myLocalIp = await _getLocalIpAddress();
      _log("Detected Local IP: $_myLocalIp");

      // 2. UDP (Слухаємо порт)
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _myLocalPort = _udpSocket!.port;
      _log("UDP Local Port: $_myLocalPort");

      _udpSocket!.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          Datagram? d = _udpSocket!.receive();
          if (d != null) _handleUdp(d);
        }
      });

      // 3. WS (Тільки для сигналізації!)
      _connectWebSocket();

      // 4. Головний цикл (Signaling)
      _loop();
    } catch (e) {
      _log("CRITICAL ERROR: $e");
    }
  }

  // Отримання локальної IP
  Future<String?> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _loop() async {
    while (!_isDisposed) {
      // 1. Оновлюємо свою Public IP (STUN), якщо ще не знаємо
      if (_myPublicIp == null) {
        await _sendStunRequest();
      }
      // 2. Логіка з'єднання
      else {
        // Якщо ще не з'єднались - спамимо IP на сервер
        if (!_gotUdpPacket) {
          // ЧЕРГУВАННЯ СТРАТЕГІЙ (PRIORITY PUBLIC):
          // Відправляємо Публічну IP частіше (4 рази з 5), щоб ESP тримала правильну ціль для Інтернету.
          // Локальну IP шлемо рідше (1 раз з 5), щоб підхопити, якщо ми в одній кімнаті.
          if (_strategyTick % 5 != 0) {
            _sendIpToEsp(_myPublicIp!, _myPublicPort!, "PUBLIC");
          } else if (_myLocalIp != null && _myLocalPort != null) {
            _sendIpToEsp(_myLocalIp!, _myLocalPort!, "LOCAL");
          }
          _strategyTick++;
        }

        // ВАЖЛИВО: Шлемо UDP PING завжди, якщо знаємо куди.
        if (_targetIp != null) {
          _punchHoleToEsp();
        }
      }

      // Затримка 200мс
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  // --- UDP LOGIC (ОСНОВНИЙ КАНАЛ) ---
  void _handleUdp(Datagram d) {
    // STUN
    if (d.data.length > 20 && d.data[0] == 0x01) {
      _parseStun(d.data);
      return;
    }

    try {
      String msg = utf8.decode(d.data);
      String sender = "${d.address.address}:${d.port}";

      // СКИДАЄМО ТАЙМЕР ВТРАТИ З'ЄДНАННЯ
      // Якщо ми отримали пакет - ми онлайн.
      _resetWatchdog();

      // ВАЖЛИВО: Оновлюємо ціль на ту, з якої реально прийшов пакет!
      if (_targetIp?.address != d.address.address || _targetPort != d.port) {
        _targetIp = d.address;
        _targetPort = d.port;
        _log("🎯 UPDATED TARGET from incoming UDP: $sender");
      }

      if (!_gotUdpPacket) {
        _log("🚀!!! P2P ESTABLISHED with $sender !!!🚀");
        _gotUdpPacket = true;
      }

      // Обробка даних (ТІЛЬКИ ТУТ)
      if (msg.contains("sensor")) {
        var json = jsonDecode(msg);
        _toUi(json, "UDP DIRECT ⚡");
      } else {
        // Логуємо сирі дані поки немає з'єднання, щоб бачити HELLO/PING
        if (!_gotUdpPacket) {
          _log("UDP RAW ($sender): $msg");
        }
      }
    } catch (e) {
      // _log("UDP Parse Err: $e");
    }
  }

  // Таймер "смерті" з'єднання
  void _resetWatchdog() {
    _connectionWatchdog?.cancel();
    _connectionWatchdog = Timer(Duration(seconds: 5), () {
      if (_gotUdpPacket) {
        _gotUdpPacket = false;
        _log("⚠️ P2P LOST. Resuming Search...");
      }
    });
  }

  // --- WS LOGIC (СИГНАЛІЗАЦІЯ) ---
  void _connectWebSocket() {
    _log("WS Connecting...");
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.stream.listen(
        (msg) {
          try {
            // ДЕДУПЛІКАЦІЯ ЛОГІВ
            if (!msg.toString().contains("status") &&
                msg.toString() != _lastWsLog) {
              _log("WS RX: $msg");
              _lastWsLog = msg.toString();
            }

            var data = jsonDecode(msg);
            if (data['type'] == 'status') return;

            if (data['type'] == 'cmd' && data['cmd'] != null) {
              var payload = data['cmd'];

              // 1. ОТРИМАННЯ IP ESP32 (Сигналізація)
              if (payload['type'] == 'p2p_info') {
                String ip = payload['ip'];
                int port = payload['port'];
                _targetIp = InternetAddress(ip);
                _targetPort = port;

                // АГРЕСИВНИЙ СТАРТ
                _punchBurst();
              }
            }
          } catch (e) {
            _log("WS Processing Error: $e");
          }
        },
        onDone: () {
          _log("WS Disconnected. Retry in 5s...");
          Future.delayed(Duration(seconds: 5), _connectWebSocket);
        },
      );

      var auth = {"type": "auth", "id": myId};
      _wsChannel!.sink.add(jsonEncode(auth));
    } catch (e) {
      _log("WS Err: $e");
    }
  }

  // --- HELPERS ---

  void _punchHoleToEsp() {
    if (_udpSocket != null && _targetIp != null && _targetPort != null) {
      try {
        _udpSocket!.send(utf8.encode("PING"), _targetIp!, _targetPort!);
      } catch (_) {}
    }
  }

  void _punchBurst() async {
    for (int i = 0; i < 5; i++) {
      _punchHoleToEsp();
      await Future.delayed(Duration(milliseconds: 20));
    }
  }

  // Універсальна функція відправки IP
  void _sendIpToEsp(String ip, int port, String type) {
    if (_wsChannel == null) return;

    var msg = {
      "type": "cmd",
      "targetId": targetId,
      "payload": {"type": "p2p_info", "ip": ip, "port": port},
    };
    try {
      _wsChannel!.sink.add(jsonEncode(msg));
      // _log("Sent $type IP ($ip) to ESP"); // Можна розкоментувати для дебагу
    } catch (e) {}
  }

  Future<void> _sendStunRequest() async {
    try {
      var stunIp = (await InternetAddress.lookup(stunHost)).first;
      List<int> packet = [
        0x00,
        0x01,
        0x00,
        0x00,
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
      ];
      _udpSocket!.send(packet, stunIp, stunPort);
    } catch (e) {
      _log("STUN DNS Err: $e");
    }
  }

  void _parseStun(List<int> data) {
    for (int i = 20; i < data.length - 4; i++) {
      if (data[i] == 0x00 && data[i + 1] == 0x20) {
        int port = ((data[i + 6] << 8) | data[i + 7]) ^ 0x2112;
        int ip1 = data[i + 8] ^ 0x21;
        int ip2 = data[i + 9] ^ 0x12;
        int ip3 = data[i + 10] ^ 0xA4;
        int ip4 = data[i + 11] ^ 0x42;
        String ip = "$ip1.$ip2.$ip3.$ip4";

        if (_myPublicIp != ip) {
          _myPublicIp = ip;
          _myPublicPort = port;
          _log("MY PUBLIC IP: $ip:$port");
        }
        return;
      }
    }
  }

  void _toUi(Map data, String source) {
    String t = data['temp']?.toString() ?? "--";
    String h = data['hum']?.toString() ?? "--";
    String time = DateTime.now().toString().split(' ')[1].substring(0, 8);
    _dataStreamController.add("[$time] $source\nT:$t  H:$h");
  }

  void _log(String msg) {
    String time = DateTime.now().toString().split(' ')[1].substring(0, 8);
    print("[$time] $msg");
    _dataStreamController.add("LOG: $msg");
  }

  void sendServoCommand(int angle) {
    if (_isDisposed) return;
    String cmd = "SERVO:$angle";
    if (_gotUdpPacket && _targetIp != null && _targetPort != null) {
      _udpSocket!.send(utf8.encode(cmd), _targetIp!, _targetPort!);
    } else {
      _log("Cannot send command: No P2P Connection");
    }
  }

  void dispose() {
    _isDisposed = true;
    _connectionWatchdog?.cancel();
    _wsChannel?.sink.close();
    _udpSocket?.close();
    _dataStreamController.close();
  }
}
