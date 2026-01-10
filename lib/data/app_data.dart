import 'package:flutter/material.dart';
import '../models/kratis_models.dart';

final List<Building> myKratisWorld = [
  Building(
    name: 'Ферма "Світанок"',
    icon: Icons.agriculture,
    rooms: [
      Room(
        name: 'Інкубаторій',
        icon: Icons.egg_outlined,
        devices: [
          Device(
            id: 'inc_1',
            name: 'Інкубатор №1',
            icon: Icons.egg,
            color: Colors.orange,
            mqttTopic: 'farm1/inc1',
          ),
          Device(
            id: 'inc_2',
            name: 'Інкубатор №2',
            icon: Icons.egg,
            color: Colors.orange,
            mqttTopic: 'farm1/inc2',
          ),
        ],
      ),
      Room(
        name: 'Брудерна',
        icon: Icons.child_care,
        devices: [
          Device(
            id: 'br_1',
            name: 'Брудер Основний',
            icon: Icons.wb_incandescent,
            color: Colors.yellow,
            mqttTopic: 'farm1/br1',
          ),
        ],
      ),
    ],
  ),
  Building(
    name: 'Головний Будинок',
    icon: Icons.home,
    rooms: [
      Room(
        name: 'Кухня',
        icon: Icons.kitchen,
        devices: [
          Device(
            id: 'sink_1',
            name: 'Умивальник',
            icon: Icons.water_drop,
            color: Colors.blue,
            mqttTopic: 'home/sink',
          ),
        ],
      ),
    ],
  ),
];
