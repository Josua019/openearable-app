import 'dart:math';
import 'package:open_earable_flutter/open_earable_flutter.dart';

enum HeadGesture {
  none,
  peck,
  lookLeft,
  lookRight,
}

class HeadGestureRecognizer {
  // Thresholds
  static const double peckPitchThreshold = 0.5;
  static const double lookYawThreshold = 0.5;

  // State
  DateTime _lastPeckTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLookTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Yaw Integration State
  double _yawIntegration = 0.0; // Current accumulated Yaw (rad)
  int _lastGyroTimestamp = 0;

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
    if (pitch > peckPitchThreshold) {
      if (now.difference(_lastPeckTime).inMilliseconds > 400) {
        detected = HeadGesture.peck;
        _lastPeckTime = now;
      }
    }
    return detected;
  }

  // Handle Gyro Data for Turn Detection
  HeadGesture processGyro(SensorDoubleValue gyroData) {
    // Check if we pecked recently (Accel detected)
    if (DateTime.now().difference(_lastPeckTime).inMilliseconds < 500) {
      return HeadGesture.none;
    }

    double zRate = gyroData.values[2]; // Yaw rate
    int currentTimestamp = gyroData.timestamp;

    // Calculate dt and integrate Yaw
    if (_lastGyroTimestamp != 0) {
      double dt = (currentTimestamp - _lastGyroTimestamp) / 1000.0;
      if (dt > 0 && dt < 1.0) {
        _yawIntegration += zRate * dt;
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
