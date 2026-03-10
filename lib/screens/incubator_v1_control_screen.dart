import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/kratis_models.dart';
import '../services/http_service.dart'; // Підключаємо наш сервіс
import 'incubator_v1_calibration.dart';

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
  Timer? _tickTimer;

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

  // PID / Авто-температура
  bool _pidEnabled = false;
  double _targetTemp = 37.7;

  // Авто-вологість
  bool _autoHumEnabled = false;
  double _targetHum = 50.0;

  // Інкубація
  DateTime? _incubationStart;
  static const _kStartFile = 'kratis_incubation_start.txt';

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

    // 4. Відновлюємо час старту інкубації (якщо є)
    _loadStartTime();
  }

  void _fetchData() {
    // Викликаємо сервіс з конкретним ID цього інкубатора
    _httpService.getSensorData(widget.device.id);
  }

  // --- ІНКУБАЦІЯ: збереження/завантаження через dart:io ---
  File _getStartFile() {
    return File('${Directory.systemTemp.path}/$_kStartFile');
  }

  Future<void> _loadStartTime() async {
    try {
      final file = _getStartFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final ms = int.tryParse(content.trim());
        if (ms != null && mounted) {
          setState(() {
            _incubationStart = DateTime.fromMillisecondsSinceEpoch(ms);
          });
          _startTickTimer();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveStartTime(DateTime dt) async {
    try {
      await _getStartFile().writeAsString(dt.millisecondsSinceEpoch.toString());
    } catch (_) {}
  }

  Future<void> _deleteStartTime() async {
    try {
      final file = _getStartFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startIncubation() {
    final now = DateTime.now();
    setState(() => _incubationStart = now);
    _saveStartTime(now);
    _startTickTimer();
  }

  void _stopIncubation() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Зупинити інкубацію?'),
        content: const Text('Таймер буде скинуто. Продовжити?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Зупинити', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() => _incubationStart = null);
        _deleteStartTime();
        _tickTimer?.cancel();
      }
    });
  }

  String _formatElapsed() {
    if (_incubationStart == null) return '';
    final elapsed = DateTime.now().difference(_incubationStart!);
    final d = elapsed.inDays;
    final h = (elapsed.inHours % 24).toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '${d}д $h:$m:$s';
  }

  // --- Команди авто-керування ---
  void _sendPidEn(bool val) {
    _httpService.sendCommand(widget.device.id, 'PID_EN:${val ? 1 : 0}');
  }

  void _sendPidTemp(double val) {
    _httpService.sendCommand(
      widget.device.id,
      'PID_TEMP:${val.toStringAsFixed(1)}',
    );
  }

  void _sendHumEn(bool val) {
    _httpService.sendCommand(widget.device.id, 'HUM_EN:${val ? 1 : 0}');
  }

  void _sendHumTarget(double val) {
    _httpService.sendCommand(
      widget.device.id,
      'HUM_TARGET:${val.toStringAsFixed(1)}',
    );
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
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _watchdogTimer?.cancel();
    _tickTimer?.cancel();
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
          IconButton(
            icon: const Icon(Icons.build_outlined),
            tooltip: 'Калібровка',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    IncubatorV1CalibrationScreen(device: widget.device),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _httpService.deviceDataStream,
        builder: (context, snapshot) {
          // Якщо прийшли нові дані - оновлюємо змінні
          if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data['temp'] != null) {
              currentTemp = (data['temp'] as num).toDouble();
              currentHum = (data['hum'] as num).toDouble();
              lastDataTime = DateTime.now();
              if (!isOnline) {
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
                // 0. Таймер інкубації
                _buildIncubationCard(),
                const SizedBox(height: 16),

                // 1. Основні показники
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
                      '${currentHum.toStringAsFixed(1)}%',
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

                // 3. Інфо панель
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

                // 4. Керування
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
                      'Ручне керув.',
                      Icons.build,
                      Colors.grey,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IncubatorV1CalibrationScreen(
                            device: widget.device,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 5. Авто керування
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ' Авто керування',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                _buildAutoControlCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncubationCard() {
    final started = _incubationStart != null;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: started ? Colors.teal.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.egg_outlined,
                  color: started ? Colors.tealAccent : Colors.grey,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  started ? 'Інкубація триває' : 'Інкубація не розпочата',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: started ? Colors.tealAccent : Colors.grey,
                  ),
                ),
                const Spacer(),
                if (started)
                  TextButton.icon(
                    onPressed: _stopIncubation,
                    icon: const Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Стоп',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _startIncubation,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Старт'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            if (started) ...[
              const SizedBox(height: 8),
              Text(
                _formatElapsed(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Старт: ${_incubationStart!.day.toString().padLeft(2, '0')}'
                '.${_incubationStart!.month.toString().padLeft(2, '0')}'
                '.${_incubationStart!.year}'
                ' о ${_incubationStart!.hour.toString().padLeft(2, '0')}'
                ':${_incubationStart!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

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

  Widget _buildAutoControlCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- PID ТЕМПЕРАТУРА ---
            Row(
              children: [
                const Icon(Icons.thermostat, color: Colors.orange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Авто-температура (PID)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _pidEnabled,
                  activeColor: Colors.orange,
                  onChanged: (val) {
                    setState(() => _pidEnabled = val);
                    _sendPidEn(val);
                  },
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _pidEnabled
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ціль:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        '${_targetTemp.toStringAsFixed(1)} °C',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _targetTemp,
                    min: 20.0,
                    max: 45.0,
                    divisions: 250,
                    label: '${_targetTemp.toStringAsFixed(1)}°C',
                    activeColor: Colors.orange,
                    inactiveColor: Colors.orange.withOpacity(0.3),
                    onChanged: (val) => setState(() => _targetTemp = val),
                    onChangeEnd: _sendPidTemp,
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),

            const Divider(height: 24),

            // --- АВТО-ВОЛОГІСТЬ ---
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blueAccent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Авто-вологість',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _autoHumEnabled,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    setState(() => _autoHumEnabled = val);
                    _sendHumEn(val);
                  },
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _autoHumEnabled
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ціль:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        '${_targetHum.toStringAsFixed(1)} %',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _targetHum,
                    min: 10.0,
                    max: 95.0,
                    divisions: 170,
                    label: '${_targetHum.toStringAsFixed(1)}%',
                    activeColor: Colors.blueAccent,
                    inactiveColor: Colors.blueAccent.withOpacity(0.3),
                    onChanged: (val) => setState(() => _targetHum = val),
                    onChangeEnd: _sendHumTarget,
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
