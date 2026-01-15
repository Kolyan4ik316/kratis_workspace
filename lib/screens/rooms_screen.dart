import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import '../services/data_manager.dart';
import 'devices_screen.dart';

class RoomsScreen extends StatefulWidget {
  final String buildingId;

  const RoomsScreen({super.key, required this.buildingId});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final DataManager _dataManager = DataManager();

  @override
  Widget build(BuildContext context) {
    // 1. Безпечний пошук будівлі
    Building? building;
    try {
      building = _dataManager.buildings.firstWhere(
        (b) => b.id == widget.buildingId,
      );
    } catch (e) {
      building = null;
    }

    // 2. Якщо будівлю видалили або ID неправильний
    if (building == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Помилка")),
        body: const Center(child: Text("Об'єкт не знайдено")),
      );
    }

    // 3. Відображення
    return Scaffold(
      appBar: AppBar(
        title: Text(building.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRoomDialog(context),
          ),
        ],
      ),
      body: building.rooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 64,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Тут поки немає кімнат.\nНатисніть + щоб додати.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: building!
                      .rooms
                      .length, // building! безпечно, бо ми перевірили вище
                  itemBuilder: (context, index) {
                    final room = building!.rooms[index];
                    return _buildRoomCard(context, room);
                  },
                );
              },
            ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DevicesScreen(buildingId: widget.buildingId, roomId: room.id),
            ),
          ).then((_) => setState(() {}));
        },
        onLongPress: () => _showDeleteRoomConfirm(context, room),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(room.icon, size: 45, color: Colors.tealAccent),
            const SizedBox(height: 12),
            Text(
              room.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${room.devices.length} пристроїв',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.bedroom_parent;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Нова Кімната"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Назва (напр. Кухня)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Оберіть іконку:"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 15,
                    children:
                        [
                          Icons.bedroom_parent,
                          Icons.kitchen,
                          Icons.weekend,
                          Icons.bathroom,
                          Icons.child_care,
                          Icons.egg_outlined,
                        ].map((icon) {
                          return InkWell(
                            onTap: () =>
                                setDialogState(() => selectedIcon = icon),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedIcon == icon
                                    ? Colors.teal.withOpacity(0.2)
                                    : null,
                                border: selectedIcon == icon
                                    ? Border.all(color: Colors.teal)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 30),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("СКАСУВАТИ"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      _dataManager.addRoom(
                        widget.buildingId,
                        nameController.text,
                        selectedIcon,
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

  void _showDeleteRoomConfirm(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Видалити '${room.name}'?"),
        content: const Text("Пристрої в цій кімнаті також будуть видалені."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("НІ"),
          ),
          TextButton(
            onPressed: () {
              _dataManager.deleteRoom(widget.buildingId, room.id);
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
