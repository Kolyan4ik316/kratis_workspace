import 'package:flutter/material.dart';

class Device {
  final String id;
  String name;
  final int iconCodePoint; // Зберігаємо код іконки
  final int colorValue; // Зберігаємо колір як int
  final String mqttTopic; // Використовуємо як тип або шлях
  String status;
  String? ip; // IP для локального керування

  Device({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.mqttTopic,
    this.status = 'Offline',
    this.ip,
  });

  // Відновлюємо IconData з коду
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  // Відновлюємо Color з int
  Color get color => Color(colorValue);

  // --- JSON SERIALIZATION ---
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconCodePoint': iconCodePoint,
    'colorValue': colorValue,
    'mqttTopic': mqttTopic,
    'status': status,
    'ip': ip,
  };

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      iconCodePoint: json['iconCodePoint'],
      colorValue: json['colorValue'],
      mqttTopic: json['mqttTopic'],
      status: json['status'] ?? 'Offline',
      ip: json['ip'],
    );
  }
}

class Room {
  final String id;
  String name;
  final int iconCodePoint;
  final List<Device> devices;

  Room({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.devices,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconCodePoint': iconCodePoint,
    'devices': devices.map((d) => d.toJson()).toList(),
  };

  factory Room.fromJson(Map<String, dynamic> json) {
    var list = json['devices'] as List;
    List<Device> deviceList = list.map((i) => Device.fromJson(i)).toList();

    return Room(
      id: json['id'],
      name: json['name'],
      iconCodePoint: json['iconCodePoint'],
      devices: deviceList,
    );
  }
}

class Building {
  final String id;
  String name;
  final int iconCodePoint;
  final List<Room> rooms;

  Building({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.rooms,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconCodePoint': iconCodePoint,
    'rooms': rooms.map((r) => r.toJson()).toList(),
  };

  factory Building.fromJson(Map<String, dynamic> json) {
    var list = json['rooms'] as List;
    List<Room> roomList = list.map((i) => Room.fromJson(i)).toList();

    return Building(
      id: json['id'],
      name: json['name'],
      iconCodePoint: json['iconCodePoint'],
      rooms: roomList,
    );
  }
}
