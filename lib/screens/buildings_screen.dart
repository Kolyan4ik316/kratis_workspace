import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import '../data/app_data.dart';
import 'rooms_screen.dart';

class BuildingsScreen extends StatelessWidget {
  const BuildingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KRATIS: МОЇ ОБ’ЄКТИ'),
        centerTitle: true,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Адаптивність: 2 колонки для телефона, 3-4 для планшета/ПК
          int crossAxisCount = 2;
          if (constraints.maxWidth > 900) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3;
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0, // Квадратні картки
            ),
            itemCount: myKratisWorld.length,
            itemBuilder: (context, index) {
              final building = myKratisWorld[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomsScreen(building: building),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Акцентна іконка у кружечку, як ми робили в демці
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          building.icon,
                          size: 40,
                          color: Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        building.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${building.rooms.length} приміщень',
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
