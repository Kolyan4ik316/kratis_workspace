import 'dart:async';
import 'package:flutter/material.dart';
import '../models/kratis_models.dart';
import '../services/http_service.dart';

class IncubatorV1CalibrationScreen extends StatefulWidget {
  final Device device;

  const IncubatorV1CalibrationScreen({super.key, required this.device});

  @override
  State<IncubatorV1CalibrationScreen> createState() =>
      _IncubatorV1CalibrationScreenState();
}

class _IncubatorV1CalibrationScreenState
    extends State<IncubatorV1CalibrationScreen> {
  final HttpControlService _httpService = HttpControlService();
  StreamSubscription? _dataSub;
  Timer? _pollingTimer;

  // Поточні дані з датчиків
  double _currentTemp = 0.0;
  double _currentHum = 0.0;

  // Локальні стани для повзунків та перемикачів
  double _heaterPower = 0.0; // 0 - 100%
  double _fanSpeed = 0.0; // 0 - 100%
  double _servoAngle = 90.0; // 0 - 180 градусів
  bool _humidifierOn = false;
  bool _isGridMode = false;

  @override
  void initState() {
    super.initState();

    // Підписуємось на оновлення даних від пристрою
    _dataSub = _httpService.deviceDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentTemp = (data['temp'] ?? _currentTemp).toDouble();
          _currentHum = (data['hum'] ?? _currentHum).toDouble();

          // Якщо пристрій надсилає свій поточний стан, можна оновлювати повзунки тут
          // Але для калібрування краще залишити ручне управління
        });
      }
    });

    _fetchData();
    // Опитування датчиків кожні 5 секунд
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchData(),
    );
  }

  void _fetchData() {
    _httpService.getSensorData(widget.device.id);
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _pollingTimer?.cancel();
    _httpService.dispose();
    super.dispose();
  }

  // --- Функції відправки команд ---
  // Ми відправляємо команди у форматі "КЛЮЧ:ЗНАЧЕННЯ"

  void _sendHeaterCommand(double value) {
    _httpService.sendCommand(widget.device.id, "CAL_HEAT:${value.toInt()}");
  }

  void _sendFanCommand(double value) {
    _httpService.sendCommand(widget.device.id, "CAL_FAN:${value.toInt()}");
  }

  void _sendServoCommand(double value) {
    _httpService.sendCommand(widget.device.id, "CAL_SERVO:${value.toInt()}");
  }

  void _sendHumidifierCommand(bool isOn) {
    _httpService.sendCommand(widget.device.id, "CAL_HUM:${isOn ? 1 : 0}");
  }

  void _sendPowerModeCommand(bool isGrid) {
    _httpService.sendCommand(
      widget.device.id,
      'SET_POWER_MODE:${isGrid ? "grid" : "battery"}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Калібрування: ${widget.device.name}'),
        backgroundColor: Colors.teal[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Панель з поточними даними
            _buildDataCard(),
            const SizedBox(height: 20),

            // Налаштування нагрівача
            _buildControlCard(
              title: 'Потужність нагрівача',
              icon: Icons.whatshot,
              iconColor: Colors.orange,
              child: _buildSlider(
                value: _heaterPower,
                min: 0,
                max: 100,
                label: '${_heaterPower.toInt()}%',
                onChanged: (val) => setState(() => _heaterPower = val),
                onChangeEnd: _sendHeaterCommand,
              ),
            ),
            const SizedBox(height: 16),

            // Налаштування вентилятора
            _buildControlCard(
              title: 'Швидкість вентилятора',
              icon: Icons.air,
              iconColor: Colors.lightBlue,
              child: _buildSlider(
                value: _fanSpeed,
                min: 0,
                max: 100,
                label: '${_fanSpeed.toInt()}%',
                onChanged: (val) => setState(() => _fanSpeed = val),
                onChangeEnd: _sendFanCommand,
              ),
            ),
            const SizedBox(height: 16),

            // Налаштування сервоприводу (поворот лотків)
            _buildControlCard(
              title: 'Кут нахилу лотків (Серво)',
              icon: Icons.screen_rotation,
              iconColor: Colors.purpleAccent,
              child: _buildSlider(
                value: _servoAngle,
                min: 0,
                max: 180,
                label: '${_servoAngle.toInt()}°',
                onChanged: (val) => setState(() => _servoAngle = val),
                onChangeEnd: _sendServoCommand,
              ),
            ),
            const SizedBox(height: 16),

            // Керування зволожувачем
            _buildControlCard(
              title: 'Зволожувач',
              icon: Icons.water_drop,
              iconColor: Colors.blueAccent,
              child: SwitchListTile(
                title: Text(_humidifierOn ? 'УВІМКНЕНО' : 'ВИМКНЕНО'),
                value: _humidifierOn,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  setState(() => _humidifierOn = val);
                  _sendHumidifierCommand(val);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Режим живлення (Grid / Battery)
            _buildControlCard(
              title: 'Режим живлення',
              icon: Icons.bolt,
              iconColor: Colors.amber,
              child: SwitchListTile(
                title: Text(
                  _isGridMode ? 'МЕРЕЖА (9V)' : 'БАТАРЕЯ (5V)',
                  style: TextStyle(
                    color: _isGridMode ? Colors.amber : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _isGridMode
                      ? 'Підвищена потужність нагрівача та вентилятора'
                      : 'Стандартна потужність від акумулятора',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _isGridMode,
                activeColor: Colors.amber,
                secondary: Icon(
                  _isGridMode ? Icons.power : Icons.battery_full,
                  color: _isGridMode ? Colors.amber : Colors.greenAccent,
                ),
                onChanged: (val) {
                  setState(() => _isGridMode = val);
                  _sendPowerModeCommand(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.thermostat, color: Colors.redAccent, size: 32),
                const SizedBox(height: 8),
                Text(
                  '$_currentTemp°C',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Температура', style: TextStyle(color: Colors.grey)),
              ],
            ),
            Container(width: 1, height: 50, color: Colors.grey[700]),
            Column(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  color: Colors.blueAccent,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_currentHum%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Вологість', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        Text(
          min.toInt().toString(),
          style: const TextStyle(color: Colors.grey),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: max.toInt(),
            label: label,
            activeColor: Colors.teal,
            inactiveColor: Colors.teal.withOpacity(0.3),
            onChanged: onChanged,
            onChangeEnd:
                onChangeEnd, // Відправляємо команду лише коли користувач відпустив повзунок
          ),
        ),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
