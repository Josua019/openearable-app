import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'head_gesture_recognizer.dart';

enum GameState {
  idle,
  playing,
  gameOver,
}

class ChickenGameEngine extends ChangeNotifier {
  final Wearable wearable;
  final HeadGestureRecognizer _recognizer = HeadGestureRecognizer();

  GameState _state = GameState.idle;
  int _score = 0;
  bool _foxActive = false;
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
  int get score => _score;
  bool get foxActive => _foxActive;
  double get headTurn => _headTurn;

  @override
  void dispose() {
    _foxTimer?.cancel();
    _gameLoopTimer?.cancel();
    _gameOverTimer?.cancel();
    _peckController.close();
    super.dispose();
  }

  ChickenGameEngine(this.wearable);

  void startGame() {
    _score = 0;
    _state = GameState.playing;
    _foxActive = false;
    _headTurn = 0.0;
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

  void _handleGesture(HeadGesture gesture) {
    if (gesture != HeadGesture.none) {
      print("Gesture: $gesture");
    }
    if (_foxActive) {
      if (gesture == HeadGesture.lookLeft || gesture == HeadGesture.lookRight) {
        _foxActive = false;
        _gameOverTimer?.cancel(); // Cancel game over if fox is scared away
        notifyListeners();
      }
    } else {
      if (gesture == HeadGesture.peck) {
        _score++;
        _peckController.add(null);
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

    int randomDelay = Random().nextInt(4) + 2; // 2-5 seconds
    print("Fox coming in $randomDelay seconds");
    _foxTimer = Timer(Duration(seconds: randomDelay), () {
      if (_state == GameState.playing) {
        _foxActive = true;
        notifyListeners();

        // Give 2 seconds to react
        _gameOverTimer?.cancel();
        _gameOverTimer = Timer(Duration(seconds: 2), () {
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
    notifyListeners();
  }
}
