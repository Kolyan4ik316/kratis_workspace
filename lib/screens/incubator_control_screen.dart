import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/kratis_models.dart';

class IncubatorControlScreen extends StatefulWidget {
  final Device device;
  const IncubatorControlScreen({super.key, required this.device});

  @override
  State<IncubatorControlScreen> createState() => _IncubatorControlScreenState();
}

class _IncubatorControlScreenState extends State<IncubatorControlScreen> {
  bool isLightOn = false;
  bool showCharts = false;
  String selectedMode = 'Кури';
  double turnDistance = 4.5; // Відстань у см
  int day = 12;

  // Дані для графіків (X - це час у годинах, наприклад 0.5 = 30 хв)
  List<FlSpot> tempHistory = [
    const FlSpot(0, 37.2),
    const FlSpot(0.5, 37.4),
    const FlSpot(1, 37.5),
    const FlSpot(1.5, 37.8),
    const FlSpot(2, 37.7),
    const FlSpot(2.5, 37.8),
  ];

  List<FlSpot> humidityHistory = [
    const FlSpot(0, 50),
    const FlSpot(0.5, 52),
    const FlSpot(1, 55),
    const FlSpot(1.5, 54),
    const FlSpot(2, 55),
    const FlSpot(2.5, 56),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: Icon(
              showCharts ? Icons.show_chart : Icons.show_chart_outlined,
            ),
            onPressed: () => setState(() => showCharts = !showCharts),
            tooltip: 'Графіки',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Основні показники
            Row(
              children: [
                _buildMetricCard(
                  'Температура',
                  '37.8°C',
                  Icons.thermostat,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Вологість',
                  '55%',
                  Icons.water_drop,
                  Colors.blue,
                ),
              ],
            ),

            // 2. Оновлений інтерактивний графік
            if (showCharts) ...[
              const SizedBox(height: 16),
              _buildAdvancedChart(),
            ],

            const SizedBox(height: 16),

            // 3. Інформаційна панель
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Режим інкубації', selectedMode, Icons.pets),
                    const Divider(height: 24),

                    _buildInfoRow(
                      'День циклу',
                      '$day-й день',
                      Icons.calendar_today,
                    ),
                    const Divider(height: 24),

                    // Новий показник: Відстань повороту (розмір яйця)
                    _buildInfoRow(
                      'Відстань повороту',
                      '$turnDistance см',
                      Icons.straighten,
                      color: Colors.tealAccent,
                    ),
                    const Divider(height: 24),

                    // Показник наявності води
                    _buildInfoRow(
                      'Наявність води',
                      'У нормі',
                      Icons.waves,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Керування та Нові кнопки
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
                  'Поворот яєць',
                  Icons.sync,
                  Colors.orange,
                  () {},
                ),
                _buildActionButton(
                  'Провітрювання',
                  Icons.air,
                  Colors.blue,
                  () {},
                ),
                _buildToggleButton('Освітлення', Icons.lightbulb, isLightOn, (
                  val,
                ) {
                  setState(() => isLightOn = val);
                }),
                _buildActionButton(
                  'Історія інкубацій',
                  Icons.history,
                  Colors.purple,
                  () {
                    print('Відкриваємо архів');
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Кнопка завершення (винесена окремо для важливості)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.all(15),
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => _confirmFinish(context),
                icon: const Icon(Icons.stop_circle),
                label: const Text(
                  'ЗАВЕРШИТИ ІНКУБАЦІЮ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Спеціальний віджет для розширеного графіка
  Widget _buildAdvancedChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Температура та Вологість (24г)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Row(
                children: [
                  _chartLegend('T°', Colors.orange),
                  const SizedBox(width: 10),
                  _chartLegend('H%', Colors.blue),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final time = spot.x;
                        final hour = time.floor();
                        final min = (time % 1 == 0) ? "00" : "30";
                        return LineTooltipItem(
                          '$hour:$min\n${spot.y}${spot.barIndex == 0 ? '°C' : '%'}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(
                  show: false,
                ), // Для чистоти поки вимкнемо осі
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Лінія Температури
                  LineChartBarData(
                    spots: tempHistory,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                  ),
                  // Лінія Вологості
                  LineChartBarData(
                    spots: humidityHistory,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  // Вікно підтвердження завершення
  void _confirmFinish(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершити процес?'),
        content: const Text(
          'Ви впевнені, що хочете зупинити інкубацію? Усі налаштування будуть скинуті.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('СКАСУВАТИ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              print('Інкубація завершена');
            },
            child: const Text(
              'ТАК, ЗАВЕРШИТИ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // --- Копії допоміжних методів з попереднього кроку ---
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
