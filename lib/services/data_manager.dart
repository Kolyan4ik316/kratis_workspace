import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/kratis_models.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  List<Building> _buildings = [];
  List<Building> get buildings => _buildings;

  final String _fileName = "kratis_data_v1.json";

  // --- ОТРИМАННЯ ШЛЯХУ (Чистий Dart, без path_provider) ---
  Future<String> _getFilePath() async {
    String directoryPath;

    if (Platform.isWindows) {
      // Використовуємо змінну середовища APPDATA на Windows
      // Це дозволяє писати файли без прав адміна
      final appData = Platform.environment['APPDATA'];
      directoryPath = '$appData\\KratisOS';
    } else {
      // Фолбек для інших систем (наприклад, поточна папка)
      directoryPath = Directory.current.path;
    }

    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return '$directoryPath\\$_fileName';
  }

  // --- ЗАВАНТАЖЕННЯ ---
  Future<void> loadData() async {
    try {
      final path = await _getFilePath();
      final file = File(path);

      if (await file.exists()) {
        final String content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _buildings = jsonList.map((e) => Building.fromJson(e)).toList();
        print("✅ Дані завантажено з $path");
      } else {
        print("📂 Файлу немає, створюємо демо-дані...");
        _buildings = _getDemoData();
        await saveData();
      }
    } catch (e) {
      print("❌ Помилка завантаження: $e");
      _buildings = _getDemoData(); // Фолбек на демо
    }
  }

  // --- ЗБЕРЕЖЕННЯ ---
  Future<void> saveData() async {
    try {
      final path = await _getFilePath();
      final file = File(path);

      String jsonString = jsonEncode(
        _buildings.map((e) => e.toJson()).toList(),
      );
      await file.writeAsString(jsonString);
      print("💾 Дані збережено в $path");
    } catch (e) {
      print("❌ Помилка збереження: $e");
    }
  }

  // --- ЛОГІКА CRUD ---

  void addBuilding(String name, IconData icon) {
    final newBuilding = Building(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      iconCodePoint: icon.codePoint,
      rooms: [],
    );
    _buildings.add(newBuilding);
    saveData();
  }

  void deleteBuilding(String id) {
    _buildings.removeWhere((b) => b.id == id);
    saveData();
  }

  void addRoom(String buildingId, String name, IconData icon) {
    final building = _buildings.firstWhere((b) => b.id == buildingId);
    final newRoom = Room(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      iconCodePoint: icon.codePoint,
      devices: [],
    );
    building.rooms.add(newRoom);
    saveData();
  }

  void deleteRoom(String buildingId, String roomId) {
    final building = _buildings.firstWhere((b) => b.id == buildingId);
    building.rooms.removeWhere((r) => r.id == roomId);
    saveData();
  }

  void addDevice(String buildingId, String roomId, Device device) {
    final building = _buildings.firstWhere((b) => b.id == buildingId);
    final room = building.rooms.firstWhere((r) => r.id == roomId);
    room.devices.add(device);
    saveData();
  }

  void deleteDevice(String buildingId, String roomId, String deviceId) {
    final building = _buildings.firstWhere((b) => b.id == buildingId);
    final room = building.rooms.firstWhere((r) => r.id == roomId);
    room.devices.removeWhere((d) => d.id == deviceId);
    saveData();
  }

  void moveDevice(
    String deviceId,
    String fromBuildId,
    String fromRoomId,
    String toBuildId,
    String toRoomId,
  ) {
    final oldBuild = _buildings.firstWhere((b) => b.id == fromBuildId);
    final oldRoom = oldBuild.rooms.firstWhere((r) => r.id == fromRoomId);
    final device = oldRoom.devices.firstWhere((d) => d.id == deviceId);

    oldRoom.devices.remove(device);

    final newBuild = _buildings.firstWhere((b) => b.id == toBuildId);
    final newRoom = newBuild.rooms.firstWhere((r) => r.id == toRoomId);
    newRoom.devices.add(device);

    saveData();
  }

  List<Building> _getDemoData() {
    return [
      Building(
        id: 'b1',
        name: 'Мій Дім',
        iconCodePoint: Icons.home.codePoint,
        rooms: [
          Room(
            id: 'r1',
            name: 'Вітальня',
            iconCodePoint: Icons.weekend.codePoint,
            devices: [],
          ),
        ],
      ),
    ];
  }
}
