import 'package:flutter/material.dart';
import '../models/chicken_game_engine.dart';

/// Builds the full-screen fox attack overlay with red vignette and glowing eyes.
///
/// Returns [SizedBox.shrink] when the fox is not active or the game is not playing.
Widget buildFoxOverlay(ChickenGameEngine engine) {
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
