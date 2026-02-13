import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:provider/provider.dart';
import 'models/chicken_game_engine.dart';

/// Main widget for the Chicken Run game.
///
/// Connects to the [Wearable] device's sensors, sets up the game engine,
/// and provides the reactive UI including the chicken avatar, score display,
/// day/night cycle background, tutorial text, and fox overlay.
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

  /// Discovers and subscribes to accelerometer and gyroscope sensor streams.
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
      child: Consumer<ChickenGameEngine>(
        builder: (context, engine, child) {
          return Stack(
            children: [
              PlatformScaffold(
                backgroundColor:
                    _getBackgroundColor(engine.dayCycle, engine.state),
                appBar: PlatformAppBar(
                  title: Text("Chicken Run",
                      style: TextStyle(color: _getTextColor(engine.dayCycle))),
                  backgroundColor:
                      _getBackgroundColor(engine.dayCycle, engine.state),
                  cupertino: (_, __) => CupertinoNavigationBarData(
                    border: Border(bottom: BorderSide.none),
                  ),
                  material: (_, __) => MaterialAppBarData(
                    elevation: 0,
                    iconTheme:
                        IconThemeData(color: _getTextColor(engine.dayCycle)),
                  ),
                ),
                body: Stack(
                  children: [
                    // Celestial Body (Sun/Moon - Behind everything)
                    _buildCelestialBody(engine),

                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // High Score Display
                          Text(
                            "High Score: ${engine.highScore}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getTextColor(engine.dayCycle)
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(height: 10),

                          // Score Display
                          Text(
                            "${engine.score}",
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              color: _getTextColor(engine.dayCycle),
                            ),
                          ),
                          Text(
                            "GRAINS",
                            style: TextStyle(
                              fontSize: 20,
                              letterSpacing: 2.0,
                              color: _getTextColor(engine.dayCycle)
                                  .withValues(alpha: 0.6),
                            ),
                          ),

                          SizedBox(height: 40),

                          // Chicken Avatar
                          _buildChickenAvatar(engine),

                          SizedBox(height: 20),

                          // Tutorial Text (In-flow, Fixed Height)
                          SizedBox(
                            height: 80,
                            child: Center(
                              child: (engine.tutorialMessage != null &&
                                      engine.state == GameState.playing)
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Text(
                                        engine.tutorialMessage!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _getTextColor(engine.dayCycle),
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ),
                          ),

                          SizedBox(height: 10),

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
                  ],
                ),
              ),

              // Fox Overlay (On top of game, including AppBar)
              _buildFoxOverlay(engine),
            ],
          );
        },
      ),
    );
  }

  /// Builds the animated chicken avatar with peck and turn animations.
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
              headTurn: engine.headTurn, // Pass turned state
            ),
            size: Size(220, 220),
          ),
        );
      },
    );
  }

  /// Builds a styled game button (START / RETRY).
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

  /// Returns text color adapted to the current day cycle for readability.
  Color _getTextColor(DayCycle cycle) {
    return cycle == DayCycle.night ? Colors.white : Color(0xFF333333);
  }

  /// Builds an animated sun/moon positioned based on the current day cycle.
  Widget _buildCelestialBody(ChickenGameEngine engine) {
    // Day: Sun Top-Right
    // Sunset: Sun Bottom-Left (Setting)
    // Night: Moon Top-Left

    double top = -100;
    double left = -100;
    double right = -100;
    double bottom = -100;
    Color color = Colors.transparent;
    double size = 80;
    BoxShape shape = BoxShape.circle;

    switch (engine.dayCycle) {
      case DayCycle.day:
        top = 60;
        right = 40;
        color = Color(0xFFFFD54F); // Yellow Sun
        break;
      case DayCycle.sunset:
        top = 120;
        left = 70;
        color = Color(0xFFFF7043); // Orange Sun
        break;
      case DayCycle.night:
        top = 60;
        left = 40;
        color = Color(0xFFE0E0E0); // White Moon
        break;
    }

    return AnimatedPositioned(
      duration: Duration(seconds: 1),
      curve: Curves.easeInOut,
      top: top != -100 ? top : null,
      bottom: bottom != -100 ? bottom : null,
      left: left != -100 ? left : null,
      right: right != -100 ? right : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: shape,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
      ),
    );
  }

  /// Returns the background color based on day cycle and game state.
  Color _getBackgroundColor(DayCycle cycle, GameState state) {
    if (state == GameState.gameOver) return Color(0xFFFFC2C2);

    switch (cycle) {
      case DayCycle.day:
        return Color(0xFF87CEEB);
      case DayCycle.sunset:
        return Color(0xFFFFB74D);
      case DayCycle.night:
        return Color(0xFF1A237E);
    }
  }
}

/// Custom painter to draw the Chicken avatar.
/// Handles the "peck" animation (vertical rotation) and the "turn" animation (horizontal shifts).
class ChickenBodyPainter extends CustomPainter {
  final bool isFoxActive; // Changes eye size
  final double peckOffset; // 0 to 30, controls peck rotation
  final double headTurn; // -1.0 to 1.0, controls horizontal turn of body parts

  ChickenBodyPainter(
      {required this.isFoxActive, this.peckOffset = 0.0, this.headTurn = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Turn shifts: Calculate horizontal offsets for different body parts to create a 2.5D parallax effect.
    // Head moves most, body less, legs least.
    double headShift = headTurn * 20.0;
    double bodyShift = headTurn * 12.0;
    double legShift = headTurn * 8.0;

    // Draw Shadow
    paint.color = Colors.black.withValues(alpha: 0.1);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2 + legShift * 0.5, size.height - 10),
            width: 140,
            height: 20),
        paint);

    // Draw Legs
    paint.color = Color(0xFFE65100); // Dark Orange for contrast
    paint.strokeWidth = 6;
    paint.strokeCap = StrokeCap.round;
    // Left leg
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 40),
        Offset(size.width / 2 - 20 + legShift, size.height - 10), paint);
    // Foot
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 10),
        Offset(size.width / 2 - 10 + legShift, size.height - 5), paint);
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 10),
        Offset(size.width / 2 - 17 + legShift, size.height + 1), paint);
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 10),
        Offset(size.width / 2 - 28 + legShift, size.height - 5), paint);

    // Right leg
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 40),
        Offset(size.width / 2 + 20 + legShift, size.height - 10), paint);
    // Foot
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 10),
        Offset(size.width / 2 + 34 + legShift, size.height - 5), paint);
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 10),
        Offset(size.width / 2 + 28 + legShift, size.height + 1), paint);
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 10),
        Offset(size.width / 2 + 17 + legShift, size.height + 1), paint);

    paint.strokeWidth = 0;

    // BODY
    paint.color = Colors.white;
    // Main body oval
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2 + bodyShift, size.height / 2 + 20),
            width: 140,
            height: 120),
        paint);

    // WING (Slightly darker or same color with shadow)
    paint.color = Color(0xFFF0F0F0);
    // Wing shape
    Path wingPath = Path();
    double wingShift = bodyShift * 1.2;
    wingPath.moveTo(size.width / 2 - 30 + wingShift, size.height / 2 + 10);
    wingPath.quadraticBezierTo(
        size.width / 2 + 10 + wingShift,
        size.height / 2 + 10,
        size.width / 2 + 20 + wingShift,
        size.height / 2 + 40);
    wingPath.quadraticBezierTo(
        size.width / 2 - 10 + wingShift,
        size.height / 2 + 60,
        size.width / 2 - 40 + wingShift,
        size.height / 2 + 40);
    canvas.drawPath(wingPath, paint);

    // HEAD GROUP (With Rotation for Peck)
    canvas.save();

    // Pivot point (Neck area approx)
    double pivotX = size.width / 2 + 20 + bodyShift;
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
        Offset(size.width / 2 + 30 + headShift, size.height / 2 - 40),
        45,
        paint);

    // COMB (Red)
    paint.color = Color(0xFFE57373);
    canvas.drawCircle(
        Offset(size.width / 2 + 20 + headShift, size.height / 2 - 75),
        10,
        paint);
    canvas.drawCircle(
        Offset(size.width / 2 + 35 + headShift, size.height / 2 - 82),
        12,
        paint);
    canvas.drawCircle(
        Offset(size.width / 2 + 50 + headShift, size.height / 2 - 78),
        10,
        paint);

    // BEAK (Orange)
    paint.color = Color(0xFFE65100); // Dark Orange for contrast
    Path beakPath = Path();
    // Beak should pivot slightly to show direction
    beakPath.moveTo(size.width / 2 + 70 + headShift * 1.5,
        size.height / 2 - 45); // Tip moves more
    beakPath.lineTo(
        size.width / 2 + 90 + headShift * 1.5, size.height / 2 - 40);
    beakPath.lineTo(
        size.width / 2 + 70 + headShift * 1.5, size.height / 2 - 35);
    canvas.drawPath(beakPath, paint);

    // WATTLE (Red under beak)
    paint.color = Color(0xFFE57373);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(
                size.width / 2 + 65 + headShift * 1.3, size.height / 2 - 25),
            width: 10,
            height: 15),
        paint);

    // EYE (Black)
    paint.color = Color(0xFF333333);
    // Move eye less than beak for parallax
    canvas.drawCircle(
        Offset(size.width / 2 + 50 + headShift, size.height / 2 - 50),
        isFoxActive ? 6 : 4,
        paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChickenBodyPainter oldDelegate) {
    return oldDelegate.isFoxActive != isFoxActive ||
        oldDelegate.peckOffset != peckOffset ||
        oldDelegate.headTurn != headTurn;
  }
}

/// Builds the full-screen fox attack overlay with red vignette and glowing eyes.
Widget _buildFoxOverlay(ChickenGameEngine engine) {
  if (!engine.foxActive || engine.state != GameState.playing) {
    return SizedBox.shrink();
  }

  return Positioned.fill(
    child: Container(
      decoration: BoxDecoration(
          gradient: RadialGradient(
        colors: [
          Colors.transparent,
          Colors.red.withValues(alpha: 0.6), // Vignette
        ],
        radius: 1.0,
      )),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Eyes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFoxEye(),
                SizedBox(width: 40),
                _buildFoxEye(),
              ],
            ),
            SizedBox(height: 20),
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
  );
}

/// Builds a single glowing fox eye with slit pupil.
Widget _buildFoxEye() {
  return Container(
    width: 40,
    height: 20,
    decoration: BoxDecoration(
      color: Colors.yellow,
      borderRadius: BorderRadius.circular(20), // Oval shape
      boxShadow: [
        BoxShadow(
          color: Colors.red,
          blurRadius: 15,
          spreadRadius: 5,
        )
      ],
    ),
    child: Center(
      child: Container(
        width: 5,
        height: 15,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle, // Pupil
        ),
      ),
    ),
  );
}
