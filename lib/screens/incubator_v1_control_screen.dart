import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/kratis_models.dart';
import '../services/http_service.dart'; // Підключаємо наш сервіс

class IncubatorV1ControlScreen extends StatefulWidget {
  final Device device;
  const IncubatorV1ControlScreen({super.key, required this.device});

  @override
  State<IncubatorV1ControlScreen> createState() =>
      _IncubatorV1ControlScreenState();
}

class _IncubatorV1ControlScreenState extends State<IncubatorV1ControlScreen> {
  // Сервіс для спілкування
  final HttpControlService _httpService = HttpControlService();

  Timer? _pollingTimer;
  Timer? _watchdogTimer;

  // Останні отримані дані
  double currentTemp = 0.0;
  double currentHum = 0.0;
  DateTime lastDataTime = DateTime.now();
  bool isOnline = false;

  // UI змінні
  bool isLightOn = false;
  bool showCharts = false;
  String selectedMode = 'Кури';
  double turnDistance = 4.5;
  int day = 12;

  // Дані для графіків (демо)
  List<FlSpot> tempHistory = [const FlSpot(0, 37.5)];
  List<FlSpot> humidityHistory = [const FlSpot(0, 55)];

  @override
  void initState() {
    super.initState();

    // 1. Перший запит
    _fetchData();

    // 2. Запуск регулярного опитування (кожні 3 сек)
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchData();
    });

    // 3. Watchdog (перевірка активності кожну хвилину)
    _watchdogTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkConnectionStatus();
    });
  }

  void _fetchData() {
    // Викликаємо сервіс з конкретним ID цього інкубатора
    _httpService.getSensorData(widget.device.id);
  }

  void _checkConnectionStatus() {
    final difference = DateTime.now().difference(lastDataTime);
    // Якщо даних немає більше 5 хвилин
    if (difference.inMinutes >= 5) {
      if (mounted && isOnline) {
        setState(() {
          isOnline = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Зв'язок втрачено! (Немає даних > 5 хв)"),
            backgroundColor: Colors.red,
          ),
        );
        // Тут можна додати логіку видалення пари, якщо це критично:
        // Navigator.pop(context, 'delete');
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _watchdogTimer?.cancel();
    _httpService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name, style: const TextStyle(fontSize: 16)),
            Text(
              isOnline ? "Онлайн" : "Офлайн / Очікування...",
              style: TextStyle(
                fontSize: 10,
                color: isOnline ? Colors.greenAccent : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              showCharts ? Icons.show_chart : Icons.show_chart_outlined,
            ),
            onPressed: () => setState(() => showCharts = !showCharts),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _httpService.deviceDataStream,
        builder: (context, snapshot) {
          // Якщо прийшли нові дані - оновлюємо змінні
          if (snapshot.hasData) {
            final data = snapshot.data!;
            // Оновлюємо тільки якщо дані валідні
            if (data['temp'] != null) {
              currentTemp = (data['temp'] as num).toDouble();
              currentHum = (data['hum'] as num).toDouble();
              lastDataTime = DateTime.now();
              if (!isOnline) {
                // Якщо були офлайн - стали онлайн
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => isOnline = true);
                });
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. Основні показники (З даними з Streams)
                Row(
                  children: [
                    _buildMetricCard(
                      'Температура',
                      '${currentTemp.toStringAsFixed(1)}°C',
                      Icons.thermostat,
                      Colors.orange,
                    ),
                    _buildMetricCard(
                      'Вологість',
                      '${currentHum.toStringAsFixed(0)}%',
                      Icons.water_drop,
                      Colors.blue,
                    ),
                  ],
                ),

                // 2. Графік
                if (showCharts) ...[
                  const SizedBox(height: 16),
                  _buildAdvancedChart(),
                ],

                const SizedBox(height: 16),

                // 3. Інфо панель (статична поки що)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow('Режим', selectedMode, Icons.pets),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'День',
                          '$day-й день',
                          Icons.calendar_today,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Поворот',
                          '$turnDistance см',
                          Icons.straighten,
                          color: Colors.tealAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Керування (відправка команд)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ' Керування',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildActionButton(
                      'Поворот',
                      Icons.sync,
                      Colors.orange,
                      () {
                        _httpService.sendCommand(widget.device.id, "SERVO:90");
                      },
                    ),
                    _buildActionButton(
                      'Стоп Мотор',
                      Icons.stop,
                      Colors.redAccent,
                      () {
                        _httpService.sendCommand(widget.device.id, "SERVO:0");
                      },
                    ),
                    _buildToggleButton('Світло', Icons.lightbulb, isLightOn, (
                      val,
                    ) {
                      setState(() => isLightOn = val);
                      _httpService.sendCommand(
                        widget.device.id,
                        val ? "LIGHT:ON" : "LIGHT:OFF",
                      );
                    }),
                    _buildActionButton(
                      'Калібровка',
                      Icons.build,
                      Colors.grey,
                      () {
                        // Тут можна відкрити діалог калібровки
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ... (Решта методів побудови UI: _buildMetricCard, _buildAdvancedChart і т.д. залишаються такими ж, як були) ...
  // Я їх скорочу для економії місця, але вони мають бути тут (скопіюйте їх з попереднього incubator_control_screen.dart)

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedChart() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          "Графік (Live Data coming soon)",
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.tealAccent),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    String label,
    IconData icon,
    bool state,
    Function(bool) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: state ? Colors.yellow.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () => onChanged(!state),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: state ? Colors.yellow : Colors.grey, size: 24),
            Text(label, style: const TextStyle(fontSize: 11)),
            Text(
              state ? 'Увімкн.' : 'Вимкн.',
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
