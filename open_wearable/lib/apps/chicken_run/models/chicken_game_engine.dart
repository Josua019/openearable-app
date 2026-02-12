import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'head_gesture_recognizer.dart';

enum GameState {
  idle,
  playing,
  gameOver,
}

enum DayCycle { day, sunset, night }

class ChickenGameEngine extends ChangeNotifier {
  final Wearable wearable;
  final HeadGestureRecognizer _recognizer = HeadGestureRecognizer();

  GameState _state = GameState.idle;
  int _score = 0;
  int get score => _score;

  int _highScore = 0;
  int get highScore => _highScore;

  bool _foxActive = false;
  // Tutorial State
  String? _tutorialMessage;
  bool _firstFox = true;

  DayCycle _dayCycle = DayCycle.day;

  // Normalized head turn value (-1.0 to 1.0) for UI rendering.
  // 0.0 is center, -1.0 is full left, 1.0 is full right.
  double _headTurn = 0.0;

  // Timers: Stored to be cancellable on dispose/stop.
  Timer? _foxTimer;
  Timer? _gameLoopTimer;
  Timer? _gameOverTimer;

  final _peckController = StreamController<void>.broadcast();
  Stream<void> get onPeck => _peckController.stream;

  GameState get state => _state;
  bool get foxActive => _foxActive;
  String? get tutorialMessage => _tutorialMessage;
  double get headTurn => _headTurn;
  DayCycle get dayCycle => _dayCycle;

  @override
  void dispose() {
    _foxTimer?.cancel();
    _gameLoopTimer?.cancel();
    _gameOverTimer?.cancel();
    _peckController.close();
    super.dispose();
  }

  ChickenGameEngine(this.wearable) {
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('chicken_run_highscore') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chicken_run_highscore', _highScore);
  }

  void startGame() {
    _score = 0;
    _state = GameState.playing;
    _foxActive = false;
    _headTurn = 0.0;
    _dayCycle = DayCycle.day;

    // Tutorial: Start
    _tutorialMessage = "Nod head to PECK!";
    _firstFox = true;

    _startFoxTimer();
    notifyListeners();
  }

  void stopGame() {
    _state = GameState.idle;
    _foxTimer?.cancel();
    _gameLoopTimer?.cancel();
    _gameOverTimer?.cancel();
    notifyListeners();
  }

  void processSensorData(SensorDoubleValue data) {
    if (_state != GameState.playing) return;

    HeadGesture gesture = _recognizer.process(data);
    _handleGesture(gesture);
  }

  void processGyroData(SensorDoubleValue data) {
    if (_state != GameState.playing) return;

    HeadGesture gesture = _recognizer.processGyro(data);

    // Update head turn based on continuous yaw
    // Threshold was 30.0 for Gesture, so we use 45.0 as max range for visual turn
    // Normalize yaw to a -1 to 1 range for the UI.
    double newHeadTurn = (_recognizer.yaw / 45.0).clamp(-1.0, 1.0);

    // Threshold to reduce repaints (optimization)
    if ((newHeadTurn - _headTurn).abs() > 0.05) {
      _headTurn = newHeadTurn;
      notifyListeners();
    }

    _handleGesture(gesture);
  }

  void _updateDayCycle() {
    // Cycle length: 45 points
    // 0-14: Day
    // 15-29: Sunset
    // 30-44: Night
    // 45-59: Day ...
    int cycleScore = _score % 45;

    DayCycle newCycle;
    if (cycleScore < 15) {
      newCycle = DayCycle.day;
    } else if (cycleScore < 30) {
      newCycle = DayCycle.sunset;
    } else {
      newCycle = DayCycle.night;
    }

    if (newCycle != _dayCycle) {
      _dayCycle = newCycle;
      // Could notify here, but we usually notify after score update anyway
    }
  }

  void _handleGesture(HeadGesture gesture) {
    if (gesture != HeadGesture.none) {
      print("Gesture: $gesture");
    }
    if (_foxActive) {
      if (gesture == HeadGesture.lookLeft || gesture == HeadGesture.lookRight) {
        _foxActive = false;

        // Tutorial: Fox Avoided
        if (_firstFox) {
          _firstFox = false;
          _tutorialMessage = null;
        }

        _gameOverTimer?.cancel(); // Cancel game over if fox is scared away
        notifyListeners();
      }
    } else {
      if (gesture == HeadGesture.peck) {
        _score++;
        _updateDayCycle();
        _peckController.add(null);

        // Tutorial: Peck Success
        if (_tutorialMessage == "Nod head to PECK!") {
          _tutorialMessage = null;
        }

        // Randomly trigger fox appearance (1 in 5 chance)
        if (Random().nextInt(5) == 0) {
          _startFoxTimer();
        }
        notifyListeners();
      }
    }
  }

  void _startFoxTimer() {
    // If a fox is already coming (timer active), do NOT reset it.
    if (_foxTimer != null && _foxTimer!.isActive) return;

    // Difficulty Scaling based on DayCycle
    int minDelay, maxDelay;
    switch (_dayCycle) {
      case DayCycle.day:
        minDelay = 3;
        maxDelay = 6;
        break;
      case DayCycle.sunset:
        minDelay = 2;
        maxDelay = 5;
        break;
      case DayCycle.night:
        minDelay = 1;
        maxDelay = 3;
        break;
    }

    int randomDelay = minDelay + Random().nextInt(maxDelay - minDelay + 1);

    // Tutorial: Force Fox early if it's the first time and score > 5?
    // Actually, asking user requests 'first appearance'.
    // We'll let random chance handle it, but when it happens:

    print("Fox coming in $randomDelay seconds (Cycle: $_dayCycle)");

    _foxTimer = Timer(Duration(seconds: randomDelay), () {
      if (_state == GameState.playing) {
        _foxActive = true;

        // Tutorial: First Fox
        int reactionTime = 2;
        if (_firstFox) {
          _tutorialMessage = "Turn head SIDEWAYS to HIDE!";
          reactionTime = 5; // Give extra time
        }

        notifyListeners();

        // Give time to react
        _gameOverTimer?.cancel();
        _gameOverTimer = Timer(Duration(seconds: reactionTime), () {
          if (_foxActive && _state == GameState.playing) {
            _gameOver();
          }
        });
      }
    });
  }

  void _gameOver() {
    _state = GameState.gameOver;
    _foxActive = false;
    _foxTimer?.cancel();
    _gameOverTimer?.cancel();

    if (_score > _highScore) {
      _highScore = _score;
      _saveHighScore();
    }

    notifyListeners();
  }
}
