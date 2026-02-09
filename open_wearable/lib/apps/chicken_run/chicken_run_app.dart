import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'models/chicken_game_engine.dart';

class ChickenRunApp extends StatefulWidget {
  final Wearable wearable;

  const ChickenRunApp({super.key, required this.wearable});

  @override
  State<ChickenRunApp> createState() => _ChickenRunAppState();
}

class _ChickenRunAppState extends State<ChickenRunApp> {
  late ChickenGameEngine _engine;
  final List<StreamSubscription> _sensorSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _engine = ChickenGameEngine(widget.wearable);
    _setupSensors();
  }

  void _setupSensors() {
    if (widget.wearable is SensorManager) {
      SensorManager sensorManager = widget.wearable as SensorManager;

      if (sensorManager.sensors.isNotEmpty) {
        // Find Accel
        var accelSensor = sensorManager.sensors.firstWhere(
          (s) => s.sensorName.toLowerCase().contains("accelerometer"),
          orElse: () => sensorManager.sensors.first,
        );

        // Find Gyro
        var gyroSensor = sensorManager.sensors.firstWhere(
          (s) => s.sensorName.toLowerCase().contains("gyro"),
          orElse: () => sensorManager.sensors.last,
        );

        // Listen to Accel for Pecking
        _sensorSubscriptions.add(accelSensor.sensorStream.listen((data) {
          if (data is SensorDoubleValue) {
            _engine.processSensorData(data);
          }
        }));

        // Listen to Gyro for Looking Around
        if (gyroSensor != accelSensor) {
          _sensorSubscriptions.add(gyroSensor.sensorStream.listen((data) {
            if (data is SensorDoubleValue) {
              _engine.processGyroData(data);
            }
          }));
        }
      }
    }
  }

  @override
  void dispose() {
    for (var s in _sensorSubscriptions) {
      s.cancel();
    }
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _engine,
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          title: PlatformText("Chicken Run"),
        ),
        body: Consumer<ChickenGameEngine>(
          builder: (context, engine, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (engine.state == GameState.idle) ...[
                    PlatformText(
                      "Ready to Cluck?",
                      style: TextStyle(
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 20),
                    PlatformElevatedButton(
                      child: PlatformText("Start Game"),
                      onPressed: () => engine.startGame(),
                    )
                  ] else if (engine.state == GameState.playing) ...[
                    if (engine.foxActive)
                      Text(
                        "FOX!!! LOOK AROUND!",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text("Peck! Peck!", style: TextStyle(fontSize: 24)),
                    SizedBox(height: 40),
                    Text(
                      "Score: ${engine.score}",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else if (engine.state == GameState.gameOver) ...[
                    Text(
                      "GAME OVER",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Fox ate you!", style: TextStyle(fontSize: 20)),
                    Text(
                      "Score: ${engine.score}",
                      style: TextStyle(fontSize: 30),
                    ),
                    SizedBox(height: 20),
                    PlatformElevatedButton(
                      child: PlatformText("Try Again"),
                      onPressed: () => engine.startGame(),
                    )
                  ]
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
