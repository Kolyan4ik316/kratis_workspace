import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import '../services/data_manager.dart';
import 'rooms_screen.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  // Отримуємо посилання на наш Singleton менеджер
  final DataManager _dataManager = DataManager();

  @override
  Widget build(BuildContext context) {
    // Беремо список будівель (він може бути пустим, якщо файл json пустий)
    final buildings = _dataManager.buildings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KRATIS: МОЇ ОБ’ЄКТИ'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Кнопка додавання нової нерухомості
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBuildingDialog(context),
          ),
        ],
      ),
      body: buildings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  const Text(
                    "У вас поки немає об'єктів.\nНатисніть + щоб додати.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Адаптивність
                int crossAxisCount = 2;
                if (constraints.maxWidth > 900)
                  crossAxisCount = 4;
                else if (constraints.maxWidth > 600)
                  crossAxisCount = 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: buildings.length,
                  itemBuilder: (context, index) {
                    final building = buildings[index];
                    return _buildBuildingCard(context, building);
                  },
                );
              },
            ),
    );
  }

  Widget _buildBuildingCard(BuildContext context, Building building) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Перехід до кімнат обраної будівлі
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoomsScreen(buildingId: building.id),
            ),
          ).then((_) => setState(() {})); // Оновити екран при поверненні
        },
        onLongPress: () => _showDeleteConfirm(context, building),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                building.icon, // Використовуємо наш гетер
                size: 40,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              building.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${building.rooms.length} приміщень',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // --- ДІАЛОГИ ---

  void _showAddBuildingDialog(BuildContext context) {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.home;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Щоб оновлювати стан всередині діалогу (іконку)
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Новий Об'єкт"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Назва (напр. Дача)",
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
                          Icons.home,
                          Icons.apartment,
                          Icons.store,
                          Icons.garage,
                          Icons.agriculture,
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
                      _dataManager.addBuilding(
                        nameController.text,
                        selectedIcon,
                      );
                      setState(() {}); // Оновити головний екран
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("СТВОРИТИ"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, Building building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Видалити '${building.name}'?"),
        content: const Text(
          "Всі кімнати та пристрої всередині також будуть видалені! Цю дію не можна скасувати.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("НІ"),
          ),
          TextButton(
            onPressed: () {
              _dataManager.deleteBuilding(building.id);
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
