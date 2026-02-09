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

class _ChickenRunAppState extends State<ChickenRunApp>
    with SingleTickerProviderStateMixin {
  late ChickenGameEngine _engine;
  final List<StreamSubscription> _sensorSubscriptions = [];
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _engine = ChickenGameEngine(widget.wearable);
    _setupSensors();

    _controller = AnimationController(
        duration: const Duration(milliseconds: 150), vsync: this);

    _animation = Tween<double>(begin: 0, end: 30).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _engine.onPeck.listen((_) {
      _controller.forward().then((_) => _controller.reverse());
    });
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
        backgroundColor: _engine.state == GameState.gameOver
            ? Color(0xFFFFC2C2)
            : Color(0xFFF5F2E8),
        appBar: PlatformAppBar(
          title:
              Text("Chicken Run", style: TextStyle(color: Color(0xFF333333))),
          backgroundColor: _engine.state == GameState.gameOver
              ? Color(0xFFFFC2C2)
              : Color(0xFFF5F2E8),
          cupertino: (_, __) => CupertinoNavigationBarData(
            border: Border(bottom: BorderSide.none),
          ),
          material: (_, __) => MaterialAppBarData(
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF333333)),
          ),
        ),
        body: Consumer<ChickenGameEngine>(
          builder: (context, engine, child) {
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Score Display
                      Text(
                        "${engine.score}",
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        "GRAINS",
                        style: TextStyle(
                          fontSize: 20,
                          letterSpacing: 2.0,
                          color: Color(0xFF888888),
                        ),
                      ),

                      SizedBox(height: 40),

                      // Chicken Avatar
                      _buildChickenAvatar(engine),

                      SizedBox(height: 60),

                      // Instructions / Status
                      if (engine.state == GameState.idle)
                        _buildButton("START", () => engine.startGame())
                      else if (engine.state == GameState.gameOver)
                        Column(
                          children: [
                            Text("GAME OVER",
                                style: TextStyle(
                                    color: Color(0xFFE57373),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 20),
                            _buildButton("RETRY", () => engine.startGame()),
                          ],
                        ),
                    ],
                  ),
                ),

                // Fox Overlay
                if (engine.foxActive && engine.state == GameState.playing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.red.withValues(alpha: 0.3),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "FOX!",
                              style: TextStyle(
                                color: Color(0xFFD84315),
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black12,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChickenAvatar(ChickenGameEngine engine) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 220,
          width: 220,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: ChickenBodyPainter(
              isFoxActive: engine.foxActive,
              peckOffset: _animation.value,
            ),
            size: Size(220, 220),
          ),
        );
      },
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
          color: Color(0xFF333333),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class ChickenBodyPainter extends CustomPainter {
  final bool isFoxActive;
  final double peckOffset; // 0 to 30

  ChickenBodyPainter({required this.isFoxActive, this.peckOffset = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Draw Shadow
    paint.color = Colors.black.withValues(alpha: 0.1);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height - 10),
            width: 140,
            height: 20),
        paint);

    // Draw Legs
    paint.color = Color(0xFFFFB74D);
    paint.strokeWidth = 6;
    paint.strokeCap = StrokeCap.round;
    // Left leg
    canvas.drawLine(Offset(size.width / 2 - 20, size.height - 40),
        Offset(size.width / 2 - 20, size.height - 10), paint);
    // Foot
    canvas.drawLine(Offset(size.width / 2 - 20, size.height - 10),
        Offset(size.width / 2 - 10, size.height - 5), paint);
    canvas.drawLine(Offset(size.width / 2 - 20, size.height - 10),
        Offset(size.width / 2 - 17, size.height + 1), paint);
    canvas.drawLine(Offset(size.width / 2 - 20, size.height - 10),
        Offset(size.width / 2 - 28, size.height - 5), paint);

    // Right leg
    canvas.drawLine(Offset(size.width / 2 + 20, size.height - 40),
        Offset(size.width / 2 + 20, size.height - 10), paint);
    // Foot
    canvas.drawLine(Offset(size.width / 2 + 20, size.height - 10),
        Offset(size.width / 2 + 34, size.height - 5), paint);
    canvas.drawLine(Offset(size.width / 2 + 20, size.height - 10),
        Offset(size.width / 2 + 28, size.height + 1), paint);
    canvas.drawLine(Offset(size.width / 2 + 20, size.height - 10),
        Offset(size.width / 2 + 17, size.height + 1), paint);

    paint.strokeWidth = 0;

    // BODY
    paint.color = Colors.white;
    // Main body oval
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2 + 20),
            width: 140,
            height: 120),
        paint);

    // WING (Slightly darker or same color with shadow)
    paint.color = Color(0xFFF0F0F0);
    // Wing shape
    Path wingPath = Path();
    wingPath.moveTo(size.width / 2 - 30, size.height / 2 + 10);
    wingPath.quadraticBezierTo(size.width / 2 + 10, size.height / 2 + 10,
        size.width / 2 + 20, size.height / 2 + 40);
    wingPath.quadraticBezierTo(size.width / 2 - 10, size.height / 2 + 60,
        size.width / 2 - 40, size.height / 2 + 40);
    canvas.drawPath(wingPath, paint);

    // HEAD GROUP (With Rotation for Peck)
    canvas.save();

    // Pivot point (Neck area approx)
    double pivotX = size.width / 2 + 20;
    double pivotY = size.height / 2 - 20;

    canvas.translate(pivotX, pivotY);
    // Rotate checks
    // peckOffset 0 -> 0 rotation
    // peckOffset 30 -> ~45 degrees down?
    double rotation = (peckOffset / 30.0) * (3.14159 / 4); // Max 45 deg
    canvas.rotate(rotation);
    canvas.translate(-pivotX, -pivotY);

    // HEAD
    // Adjusted offsets because of rotation pivot
    // Original center was: size.width / 2 + 30, size.height / 2 - 40
    paint.color = Colors.white;
    canvas.drawCircle(
        Offset(size.width / 2 + 30, size.height / 2 - 40), 45, paint);

    // COMB (Red)
    paint.color = Color(0xFFE57373);
    canvas.drawCircle(
        Offset(size.width / 2 + 20, size.height / 2 - 75), 10, paint);
    canvas.drawCircle(
        Offset(size.width / 2 + 35, size.height / 2 - 82), 12, paint);
    canvas.drawCircle(
        Offset(size.width / 2 + 50, size.height / 2 - 78), 10, paint);

    // BEAK (Orange)
    paint.color = Color(0xFFFFB74D);
    Path beakPath = Path();
    beakPath.moveTo(size.width / 2 + 70, size.height / 2 - 45);
    beakPath.lineTo(size.width / 2 + 90, size.height / 2 - 40);
    beakPath.lineTo(size.width / 2 + 70, size.height / 2 - 35);
    canvas.drawPath(beakPath, paint);

    // WATTLE (Red under beak)
    paint.color = Color(0xFFE57373);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2 + 65, size.height / 2 - 25),
            width: 10,
            height: 15),
        paint);

    // EYE (Black)
    paint.color = Color(0xFF333333);
    canvas.drawCircle(Offset(size.width / 2 + 50, size.height / 2 - 50),
        isFoxActive ? 6 : 4, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChickenBodyPainter oldDelegate) {
    return oldDelegate.isFoxActive != isFoxActive ||
        oldDelegate.peckOffset != peckOffset;
  }
}
