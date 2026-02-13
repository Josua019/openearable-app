import 'dart:math';
import 'package:open_earable_flutter/open_earable_flutter.dart';

/// Represents a detected head gesture from sensor data.
enum HeadGesture {
  /// No gesture detected.
  none,

  /// A forward nod (peck), detected via accelerometer pitch.
  peck,

  /// A left head turn, detected via gyroscope yaw integration.
  lookLeft,

  /// A right head turn, detected via gyroscope yaw integration.
  lookRight,
}

/// Recognizes head gestures from raw accelerometer and gyroscope data.
///
/// Uses two independent processing pipelines:
/// - [process]: Analyzes accelerometer data to detect **peck** gestures via
///   pitch angle calculation and edge-detection state machine.
/// - [processGyro]: Integrates gyroscope yaw rate over time to detect
///   **left/right turn** gestures with exponential decay to center.
///
/// Both pipelines include cooldown timers to prevent duplicate detections
/// and cross-suppression logic (turns are suppressed briefly after pecks).
class HeadGestureRecognizer {
  /// Pitch threshold (radians) for peck detection.
  /// Resting head pitch is ~-1.0 rad. A forward nod raises pitch above this value.
  static const double peckPitchThreshold = -0.9;

  /// Yaw threshold (degrees, integrated) for turn detection.
  /// High value filters out wobble from pecking motion.
  static const double lookYawThreshold = 30.0;

  // State
  DateTime _lastPeckTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLookTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _peckTriggered = false;

  // Yaw Integration State
  double _yawIntegration = 0.0; // Current accumulated Yaw (rad)
  double get yaw => _yawIntegration;
  int _lastGyroTimestamp = 0;

  /// Processes accelerometer data to detect peck gestures.
  ///
  /// Computes pitch from the 3-axis acceleration vector and uses
  /// edge-detection (only triggers on threshold crossing) with a
  /// 400ms cooldown to prevent double-counting.
  HeadGesture process(SensorDoubleValue sensorData) {
    if (sensorData.values.length < 3) return HeadGesture.none;

    double x = sensorData.values[0];
    double y = sensorData.values[1];
    double z = sensorData.values[2];

    // Calculate Pitch from Accel (Rotation around Y-axis)
    double pitch = atan2(x, sqrt(y * y + z * z));

    HeadGesture detected = HeadGesture.none;
    DateTime now = DateTime.now();

    // Detect Peck (Pitch Down / Forward)
    // Uses edge-detection: Only trigger when WE ENTER the threshold zone (from below).
    // This prevents continuous triggering if the user just looks down and holds it.
    if (pitch > peckPitchThreshold) {
      if (!_peckTriggered) {
        if (now.difference(_lastPeckTime).inMilliseconds > 400) {
          detected = HeadGesture.peck;
          _lastPeckTime = now;
          _peckTriggered = true; // Mark as "holding" peck
        }
      }
    } else {
      _peckTriggered = false; // Reset when head goes back up
    }
    return detected;
  }

  /// Processes gyroscope data to detect left/right head turns.
  ///
  /// Integrates yaw rate over time with 5% exponential decay per frame.
  /// Suppresses detection for 500ms after a peck to avoid false positives.
  /// The accumulated [yaw] value is also exposed for continuous UI animation.
  HeadGesture processGyro(SensorDoubleValue gyroData) {
    // Check if we pecked recently (Accel detected)
    if (DateTime.now().difference(_lastPeckTime).inMilliseconds < 500) {
      return HeadGesture.none;
    }

    double xRate = gyroData.values[0]; // Yaw rate
    int currentTimestamp = gyroData.timestamp;

    // Calculate dt and integrate Yaw
    if (_lastGyroTimestamp != 0) {
      double dt = (currentTimestamp - _lastGyroTimestamp) / 1000.0;
      if (dt > 0 && dt < 1.0) {
        _yawIntegration += xRate * dt;
      }
    }
    _lastGyroTimestamp = currentTimestamp;

    // Decay to center
    _yawIntegration *= 0.95;

    DateTime now = DateTime.now();

    if (_yawIntegration.abs() > lookYawThreshold) {
      if (now.difference(_lastLookTime).inMilliseconds > 400) {
        _lastLookTime = now;
        return _yawIntegration > 0
            ? HeadGesture.lookLeft
            : HeadGesture.lookRight;
      }
    }
    return HeadGesture.none;
  }
}
