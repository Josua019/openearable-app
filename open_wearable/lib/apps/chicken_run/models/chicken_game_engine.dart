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
  Timer? _foxTimer;
  Timer? _gameLoopTimer;

  GameState get state => _state;
  int get score => _score;
  bool get foxActive => _foxActive;

  ChickenGameEngine(this.wearable);

  void startGame() {
    _score = 0;
    _state = GameState.playing;
    _foxActive = false;
    _startFoxTimer();
    notifyListeners();
  }

  void stopGame() {
    _state = GameState.idle;
    _foxTimer?.cancel();
    _gameLoopTimer?.cancel();
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
    _handleGesture(gesture);
  }

  void _handleGesture(HeadGesture gesture) {
    if (gesture != HeadGesture.none) {
      print("Gesture: $gesture");
    }
    if (_foxActive) {
      if (gesture == HeadGesture.lookLeft || gesture == HeadGesture.lookRight) {
        _foxActive = false;
        notifyListeners();
      }
    } else {
      if (gesture == HeadGesture.peck) {
        _score++;
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
        Future.delayed(Duration(seconds: 2), () {
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
    notifyListeners();
  }
}
