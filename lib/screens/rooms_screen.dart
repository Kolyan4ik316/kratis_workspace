import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import 'devices_screen.dart';

class RoomsScreen extends StatelessWidget {
  final Building building;

  const RoomsScreen({super.key, required this.building});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(building.name), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Адаптивність: 2 колонки для телефона, 3 для планшета/ПК
          int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: building.rooms.length,
            itemBuilder: (context, index) {
              final room = building.rooms[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DevicesScreen(room: room),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(room.icon, size: 45, color: Colors.tealAccent),
                      const SizedBox(height: 12),
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${room.devices.length} пристроїв',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
