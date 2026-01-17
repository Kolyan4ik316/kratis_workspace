import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import '../services/data_manager.dart';
import 'wifi_setup_screen.dart';
import 'incubator_v1_control_screen.dart';
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
    Room? foundRoom;
    try {
      final building = _dataManager.buildings.firstWhere(
        (b) => b.id == widget.buildingId,
      );
      foundRoom = building.rooms.firstWhere((r) => r.id == widget.roomId);
    } catch (e) {
      foundRoom = null;
    }

    if (foundRoom == null) {
      return const Scaffold(
        body: Center(child: Text("Помилка: Кімнату не знайдено")),
      );
    }

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.id.substring(0, 8)}...'),
            if (device.type != 'unknown')
              Text(
                'Тип: ${device.type}',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (device.type == 'incubator_v1' ||
              device.name.toLowerCase().contains('інкубатор')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IncubatorV1ControlScreen(device: device),
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
    // 1. Отримуємо дані від WifiSetupScreen (включаючи device_id, якщо успішно)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WifiSetupScreen()),
    );

    // 2. Якщо є успіх і device_id
    if (result != null && result is Map && result['success'] == true) {
      final String realDeviceId = result['device_id'];
      _showAddDeviceDialog(context, realDeviceId);
    }
  }

  void _showAddDeviceDialog(BuildContext context, String realDeviceId) {
    final nameController = TextEditingController();

    // Дефолтні налаштування
    String selectedType = "incubator_v1";
    Color selectedColor = Colors.orange;
    IconData selectedIcon = Icons.egg;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Новий Пристрій"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ID: $realDeviceId",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
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
                      "Тип:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(
                          "Інкубатор",
                          Icons.egg,
                          Colors.orange,
                          selectedType == "incubator_v1",
                          () {
                            setDialogState(() {
                              selectedType = "incubator_v1";
                              selectedColor = Colors.orange;
                              selectedIcon = Icons.egg;
                            });
                          },
                        ),
                        _choiceChip(
                          "Інше",
                          Icons.device_hub,
                          Colors.blue,
                          selectedType == "other",
                          () {
                            setDialogState(() {
                              selectedType = "other";
                              selectedColor = Colors.blue;
                              selectedIcon = Icons.device_hub;
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
                      // Створюємо пристрій з РЕАЛЬНИМ ID, який прийшов від ESP32
                      final newDevice = Device(
                        id: realDeviceId,
                        name: nameController.text,
                        iconCodePoint: selectedIcon.codePoint,
                        colorValue: selectedColor.value,
                        mqttTopic: "farm/device",
                        type: selectedType,
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
                  child: const Text("ЗБЕРЕГТИ"),
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
        children: [Icon(icon, size: 16), SizedBox(width: 4), Text(label)],
      ),
      selected: selected,
      onSelected: (_) => onSelect(),
      selectedColor: color.withOpacity(0.3),
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
                title: const Text("Перемістити"),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveDialog(context, device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Видалити",
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
            child: const Text("ТАК", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
