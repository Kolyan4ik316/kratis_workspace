import 'package:flutter/material.dart';

class Device {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String mqttTopic;
  String status;

  Device({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.mqttTopic,
    this.status = 'Offline',
  });
}

class Room {
  final String name;
  final IconData icon;
  final List<Device> devices;

  Room({required this.name, required this.icon, required this.devices});
}

class Building {
  final String name;
  final IconData icon;
  final List<Room> rooms;

  Building({required this.name, required this.icon, required this.rooms});
}
