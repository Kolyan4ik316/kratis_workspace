import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import '../services/data_manager.dart';
import 'wifi_setup_screen.dart';
import 'incubator_control_screen.dart';
import 'device_control_screen.dart';

class DevicesScreen extends StatefulWidget {
  final String buildingId;
  final String roomId;

  const DevicesScreen({
    super.key,
    required this.buildingId,
    required this.roomId,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DataManager _dataManager = DataManager();

  @override
  Widget build(BuildContext context) {
    // 1. Безпечний пошук кімнати
    Room? foundRoom;
    try {
      final building = _dataManager.buildings.firstWhere(
        (b) => b.id == widget.buildingId,
      );
      foundRoom = building.rooms.firstWhere((r) => r.id == widget.roomId);
    } catch (e) {
      foundRoom = null;
    }

    // 2. Якщо кімнату видалили
    if (foundRoom == null) {
      return const Scaffold(
        body: Center(child: Text("Помилка: Кімнату не знайдено")),
      );
    }

    // 3. Зберігаємо посилання
    final Room room = foundRoom;

    return Scaffold(
      appBar: AppBar(
        title: Text('Пристрої: ${room.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _startDeviceSetup(context),
            tooltip: "Додати пристрій",
          ),
        ],
      ),
      body: room.devices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.developer_board_off,
                    size: 64,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "У цій кімнаті немає пристроїв.\nНатисніть + щоб підключити.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: room.devices.length,
              itemBuilder: (context, index) {
                final device = room.devices[index];
                return _buildDeviceCard(context, device);
              },
            ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: device.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(device.icon, color: device.color, size: 28),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('ID: ${device.id.substring(0, 8)}...'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Тут перевіряємо не назву, а тип (або можна додати поле type в модель Device)
          // Поки що орієнтуємось на іконку або назву для демо
          if (device.iconCodePoint == Icons.agriculture.codePoint ||
              device.name.toLowerCase().contains('інкубатор')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IncubatorControlScreen(device: device),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DeviceControlScreen()),
            );
          }
        },
        onLongPress: () => _showDeviceOptions(context, device),
      ),
    );
  }

  // --- ЛОГІКА ДОДАВАННЯ ---

  void _startDeviceSetup(BuildContext context) async {
    // 1. Чекаємо результату від WifiSetupScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WifiSetupScreen()),
    );

    // 2. Показуємо діалог ТІЛЬКИ якщо result == true (успішне збереження)
    if (result == true && mounted) {
      _showAddDeviceDialog(context);
    }
  }

  void _showAddDeviceDialog(BuildContext context) {
    final nameController = TextEditingController();

    // Дефолтні значення
    String deviceType = "agro";
    Color selectedColor = Colors.orange;
    IconData selectedIcon = Icons.agriculture;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Реєстрація Пристрою"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "WiFi налаштовано! Тепер додайте пристрій у додаток.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Назва (напр. Інкубатор 1)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Тип пристрою:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(
                          "Сільське госп.",
                          Icons.agriculture,
                          Colors.orange,
                          deviceType == "agro",
                          () {
                            setDialogState(() {
                              deviceType = "agro";
                              selectedColor = Colors.orange;
                              selectedIcon = Icons.agriculture;
                            });
                          },
                        ),
                        _choiceChip(
                          "Розумна оселя",
                          Icons.home_filled,
                          Colors.blue,
                          deviceType == "smart_home",
                          () {
                            setDialogState(() {
                              deviceType = "smart_home";
                              selectedColor = Colors.blue;
                              selectedIcon = Icons.home_filled;
                            });
                          },
                        ),
                        _choiceChip(
                          "Побутові",
                          Icons.tv,
                          Colors.purple,
                          deviceType == "household",
                          () {
                            setDialogState(() {
                              deviceType = "household";
                              selectedColor = Colors.purple;
                              selectedIcon = Icons.tv;
                            });
                          },
                        ),
                        _choiceChip(
                          "Клімат",
                          Icons.thermostat,
                          Colors.teal,
                          deviceType == "climate",
                          () {
                            setDialogState(() {
                              deviceType = "climate";
                              selectedColor = Colors.teal;
                              selectedIcon = Icons.thermostat;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("СКАСУВАТИ"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final newDevice = Device(
                        id:
                            "esp32_" +
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        iconCodePoint: selectedIcon.codePoint,
                        colorValue: selectedColor.value,
                        mqttTopic: "farm/device",
                      );

                      _dataManager.addDevice(
                        widget.buildingId,
                        widget.roomId,
                        newDevice,
                      );
                      setState(() {});
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("ДОДАТИ"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _choiceChip(
    String label,
    IconData icon,
    Color color,
    bool selected,
    VoidCallback onSelect,
  ) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelect(),
      selectedColor: color,
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      elevation: selected ? 2 : 0,
      showCheckmark: false,
    );
  }

  // --- МЕНЮ ПРИСТРОЮ ---

  void _showDeviceOptions(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_move),
                title: const Text("Перемістити в іншу кімнату"),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveDialog(context, device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Видалити пристрій",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, device);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoveDialog(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Виберіть кімнату"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: _dataManager.buildings.length,
              itemBuilder: (context, bIndex) {
                final building = _dataManager.buildings[bIndex];
                return ExpansionTile(
                  title: Text(building.name),
                  leading: Icon(building.icon),
                  initiallyExpanded: true,
                  children: building.rooms.map((room) {
                    if (room.id == widget.roomId)
                      return const SizedBox.shrink();
                    return ListTile(
                      title: Text(room.name),
                      leading: const Icon(Icons.subdirectory_arrow_right),
                      onTap: () {
                        _dataManager.moveDevice(
                          device.id,
                          widget.buildingId,
                          widget.roomId,
                          building.id,
                          room.id,
                        );
                        setState(() {});
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "${device.name} переміщено в ${room.name}",
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("СКАСУВАТИ"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Видалити '${device.name}'?"),
        content: const Text("Це видалить пристрій з додатку."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("НІ"),
          ),
          TextButton(
            onPressed: () {
              _dataManager.deleteDevice(
                widget.buildingId,
                widget.roomId,
                device.id,
              );
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text(
              "ТАК, ВИДАЛИТИ",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
