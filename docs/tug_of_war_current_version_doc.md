# Tug of War — Current Implementation

**File**: `lib/games/games/tug_of_war_game.dart`
**Last Updated**: 2026-09-01

This document describes what is actually implemented right now, in plain terms — not the full design plan. For the target design, see `tug_of_war_build_guide.md`.

---

## Pull Detection Algorithm (Cycle Counting)

A pull is not read from a static joint angle but from a full motion cycle: the arm must flex (bend) and then extend (straighten) again for one pull to count. The game tracks the joint's normalized position every frame and watches for it to increase past a small threshold — this marks the start of a flex. Once the position turns and decreases past that same threshold, the flex is considered complete, and one pull is recorded.

The strength of that pull depends on how far the joint moved and how quickly it moved, so a longer, faster motion contributes more pulling power than a small, slow one. Accumulated pulling power also decays gradually over time, so continuous, repeated pulling is required to keep pushing the rope in the player's favor.

The completion check requires the motion to clearly reverse past a small buffer, rather than ending the moment it merely pauses for an instant. This avoids mistaking natural, slightly uneven input — a manual slider drag or minor sensor noise — for the end of a pull.

The general pull power can be adjusted by setting the value multiplied by dt in the following line:

```dart
_pullPower *= (1 - dt * 0.7).clamp(0.0, 1.0);
```

---



## Adaptive Animal AI Algorithm

The opponent's pulling force is recalculated every frame from three combined factors:

1. **Base strength by animal** — each animal has a fixed baseline force: Chimpanzee = 7, Orangutan = 11, Gorilla = 15.
2. **Adaptive factor based on player performance** — the algorithm checks how far the rope has drifted toward either side. If the player is winning, the opponent's strength increases by 15%. If the player is losing, it decreases by 15%. This keeps the match from snowballing too quickly in either direction.
3. **Animal-specific pulling pattern (wave)** — instead of a constant pull, each animal's force oscillates over time in a way that matches its character: the Chimpanzee tugs fast and erratically, the Orangutan pulls slowly and steadily, and the Gorilla mostly holds steady but occasionally unleashes a sharp, heavy burst.

The final opponent force is the base strength multiplied by the performance factor and the pulling-pattern factor. This combined value both drives the rope's physics each frame and, when a physical motor is connected, is sent to it as the resistance the patient feels.

Note on terminology: this is not machine learning or anything that learns or adapts across sessions. It is the common game-development use of "AI" for any non-player-controlled opponent behavior — here, a fixed set of constants and one simple performance-based rule, re-evaluated every frame.

---



## Win / Lose Logic

The tug-of-war is tracked as a single rope position ranging from -1 (full loss) to +1 (full win), starting at the center (0). Each frame, the difference between the player's pulling power and the opponent's current strength shifts the rope toward one side. If the rope reaches +1, the player wins; if it reaches -1, the player loses. The match ends immediately once either threshold is hit, and a result (score, accuracy, duration, and other session data) is recorded. There is currently only one round — no best-of-three or multi-round structure yet.

---



## Difficulty & Animal Selection

The opponent animal is chosen once, when the game loads, based on the patient's Brunnstrom recovery stage (set by the clinician at game setup) — not the separate 1–5 difficulty slider. Stages 2–3 face the Chimpanzee, stage 4 faces the Orangutan, and stages 5–6 face the Gorilla. This mirrors how other games in the app scale their core difficulty from Brunnstrom stage rather than the secondary difficulty slider.

---



## Start Countdown

Before gameplay begins, a 3-2-1 countdown freezes all game logic — no pulling is detected, the opponent doesn't pull, and the rope cannot move. This prevents the match from being lost automatically before the player has had any chance to interact, since the opponent's force would otherwise start acting on the rope immediately.

---



## Motor / Bluetooth Integration

When a physical device is connected, the game selects the configured joint on the robot and starts an isotonic (constant-resistance) motor mode, matching the mode used by other games with active motor control. The opponent's current strength is periodically re-sent to the motor as its resistance value, so the physical resistance felt by the patient loosely tracks the in-game AI difficulty. A watchdog automatically stops the motor if data stops arriving, and manual pause, stop, and emergency-stop controls are available during play.

---



## Simulation Mode & Controls

When no physical device is connected, a slider lets a tester manually simulate the joint's position in place of live sensor data. Regardless of connection status, players can pause the game, stop it early (counted as a loss), or use an emergency-stop button that immediately halts both the game and the motor.