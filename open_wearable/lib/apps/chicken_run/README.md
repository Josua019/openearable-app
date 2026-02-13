# 🐔 Chicken Run

**Chicken Run** is a motion-controlled game for the [OpenEarable](https://open-earable.teco.edu/) platform. The player controls a chicken by physically moving their head while wearing the earable device. The goal is to collect as many grains as possible while avoiding foxes.

## Idea

The app uses the earable's **accelerometer** and **gyroscope** sensors to translate head movements into in-game actions:

| Action | Head Movement | Sensor Used |
|---|---|---|
| **Peck** (collect grain) | Nod head forward | Accelerometer (pitch) |
| **Dodge fox** | Turn head left or right | Gyroscope (yaw integration) |

This creates an immersive, physical gaming experience that goes beyond simple button presses.

## Sensors & Data Processing

### Accelerometer — Peck Detection

The accelerometer provides 3-axis acceleration values (`x`, `y`, `z`). We compute the **pitch angle** using:

```
pitch = atan2(x, sqrt(y² + z²))
```

- **Resting state**: The head at rest gives a pitch of approximately **-1.0 radians** (~-57°).
- **Peck detection**: A forward nod raises the pitch above **-0.9 radians** (~-51°).
- **Edge detection**: We use a state machine (`_peckTriggered` flag) to ensure only the *transition* into the threshold zone triggers a peck — not sustained head-down positions.
- **Cooldown**: A 400ms cooldown prevents duplicate detections from a single nod.

### Gyroscope — Turn Detection (Yaw Integration)

The gyroscope provides angular velocity. We integrate the **yaw rate** over time to estimate head rotation:

```
yawIntegration += yawRate × dt
```

- **Decay**: The integrated yaw decays by 5% each frame (`× 0.95`) to drift back to center, preventing unbounded accumulation.
- **Threshold**: A turn is detected when the accumulated yaw exceeds **±30°**.
- **Peck suppression**: Turn detection is suppressed for 500ms after a peck to prevent false positives from the rotational component of nodding.
- **Visual feedback**: The raw yaw value (normalized to `-1.0` … `1.0`) is used directly to animate the chicken's body turn in the UI, creating a 2.5D parallax effect.

## Game Mechanics

### Scoring & Day/Night Cycle

- Each peck increments the score by 1.
- The **day/night cycle** progresses every 45 points:
  - **Day** (0–14): Bright sky, yellow sun.
  - **Sunset** (15–29): Orange sky, setting sun.
  - **Night** (30–44): Dark sky, white moon.
- The cycle repeats indefinitely, with **difficulty scaling** tied to each phase.

### Fox AI & Difficulty Scaling

- After each peck, there is a **1-in-5 chance** a fox appears.
- The fox approach delay depends on the current day cycle:

| Cycle | Fox Delay | Reaction Time |
|---|---|---|
| Day | 3–6 seconds | 2 seconds |
| Sunset | 2–5 seconds | 2 seconds |
| Night | 1–3 seconds | 2 seconds |

- **Player must turn their head** left or right to scare off the fox before the reaction timer expires.
- If the fox is not scared away in time → **Game Over**.

### Tutorial System

- On the first game, the player sees **"Nod head to PECK!"**.
- After the first successful peck, the message disappears.
- On the **first fox encounter**, the player sees **"Turn head SIDEWAYS to HIDE!"** and gets **5 seconds** (instead of 2) to react.

### High Score

- The highest score is persisted locally using `SharedPreferences`.
- Displayed above the current score during gameplay.

## Architecture

```
chicken_run/
├── chicken_run_app.dart              # Main game screen & layout
├── README.md                         # This file
├── models/
│   ├── chicken_game_engine.dart      # Game logic, state management (ChangeNotifier)
│   └── head_gesture_recognizer.dart  # Signal processing, gesture detection
├── painters/
│   └── chicken_body_painter.dart     # CustomPainter for the chicken avatar
└── widgets/
    └── fox_overlay.dart              # Fox attack overlay with vignette & glowing eyes
```

### Component Responsibilities

| Component | Role |
|---|---|
| `HeadGestureRecognizer` | Pure signal processing. Converts raw sensor data into `HeadGesture` events. |
| `ChickenGameEngine` | Game state machine. Manages score, fox AI, day cycle, tutorial, and high score. |
| `ChickenRunApp` | Main Flutter UI. Renders layout, score, tutorial text, and celestial bodies. Subscribes to sensors. |
| `ChickenBodyPainter` | `CustomPainter` that draws the chicken with parallax-based turning and rotation-based peck animation. |
| `fox_overlay.dart` | Standalone widget functions for the fox attack overlay (red vignette, glowing eyes). |
