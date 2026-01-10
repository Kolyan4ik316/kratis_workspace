import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import 'incubator_control_screen.dart';

class DevicesScreen extends StatelessWidget {
  final Room room;

  const DevicesScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Пристрої: ${room.name}')),
      body: room.devices.isEmpty
          ? const Center(child: Text('У цьому приміщенні поки немає пристроїв'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: room.devices.length,
              itemBuilder: (context, index) {
                final device = room.devices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
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
                    subtitle: Text('Статус: ${device.status}'),
                    trailing: const Icon(
                      Icons.settings_remote,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      if (device.name.contains('Інкубатор')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                IncubatorControlScreen(device: device),
                          ),
                        );
                      } else {
                        _showDeviceControl(context, device);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  // Тимчасова функція для виклику пульта (пізніше замінимо на окремий екран)
  void _showDeviceControl(BuildContext context, Device device) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Відкриваємо пульт керування: ${device.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
