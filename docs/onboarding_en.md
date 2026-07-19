# Welcome to the Rehab Game Project

**Last updated**: 2026-06-29  
**For**: New team members  
**Korean version**: [onboarding_kr.md](onboarding_kr.md)

---

## 1. Why This Project Matters

Every year, stroke leaves hundreds of thousands of people with hemiplegia — partial paralysis on one side of the body. Recovery depends heavily on repetitive, structured movement therapy. The problem is that traditional rehab is often monotonous, hard to measure, and difficult to maintain motivation through.

This project builds tablet-based games that make upper-limb rehabilitation engaging. Each game is connected to a motorized arm exoskeleton via Bluetooth. When a patient moves their arm, the game responds. When the game needs to assist or resist the movement, the motor does it automatically.

**Your code runs on a device held by a real patient in a clinic.** A smoother game means better therapy compliance. A bug means a patient gets confused and stops. Small contributions here have outsized real-world impact.

---

## 2. How the System Works

### Patient Recovery Stages (Brunnstrom Scale)

The app adapts to each patient's recovery stage. We use the Brunnstrom scale (Stages 2–6):

| Stage | Condition | Game Style |
|-------|-----------|-----------|
| 2 | Spasticity begins | Motor assists all movement (CPM mode) |
| 3 | Synergy patterns | Games within synergy range |
| **4** | **Synergy breaking begins** | **Key stage — games that push isolated control** |
| 5 | Independent joint movement | Precision + multi-joint games |
| 6 | Near-normal | ADL simulation games |

### Three Target Joints

All games are built around one (or more) of these joints:

| Code | Joint | Example daily use |
|------|-------|------------------|
| `lShoulderEF` | Shoulder flexion/extension | Reaching a shelf |
| `lShoulderRo` | Shoulder internal/external rotation | Turning a door handle |
| `lElbow` | Elbow flexion/extension | Eating, brushing teeth |

### Data Flow

```
Bluetooth sensor → raw angle (°)
  → AngleNormalizer (maps to 0.0–1.0)
    → GameConfig (applies Brunnstrom/cognitive/motor settings)
      → Game loop (Flutter + Flame engine)
        → Motor command (via GameMotorController)
```

### GameConfig — How Difficulty is Automated

You don't manually set difficulty. `GameConfig` (in `lib/games/game_base.dart`) computes everything from three inputs:

- **BrunnstromStage** (2–6): controls ROM range, speed, motor assist
- **CognitiveLevel** (1–3, based on MMSE score): controls object size, particle effects, timers shown
- **MotorMode**: `none` / `cpm` (passive) / `isometric` (hold) / `isotonic` (resist)

---

## 3. Games Built So Far

12 games are implemented across 3 joint categories.

### Shoulder Games

| ID | Game | Joint | Rehab Goal | ADL | Status |
|----|------|-------|-----------|-----|--------|
| S1 | Sky Gardener | Shoulder F/E | ROM expansion | Reaching a shelf | ⏳ |
| S2 | Cloud Painter | Shoulder full ROM | Uniform coverage | Writing on a board | ⏳ |
| S3 | Shield Guard | Shoulder F/E | Isometric hold | Holding arm up | 🔄 |
| S4 | Safe Cracker | Shoulder IR/ER | Synergy isolation | Turning door handles | ⏳ |
| S6 | Swimming Star | Shoulder F/E | Vertical repetition | Reaching up/down | ⏳ |

### Elbow Games

| ID | Game | Joint | Rehab Goal | ADL | Status |
|----|------|-------|-----------|-----|--------|
| E1 | Brick Breaker | Elbow F/E | Precise ROM | Table-top tasks | ⏳ |
| E2 | Carpenter | Elbow F/E | Repetitive ROM | Sawing / brushing | ⏳ |
| E3 | Potion Maker | Elbow F/E | Isometric hold | Holding a cup | ⏳ |

### Combined / Multi-joint Games

| ID | Game | Joints | Rehab Goal | ADL | Status |
|----|------|--------|-----------|-----|--------|
| C1 | Clock Reaching | Shoulder or Elbow | 8-direction reach | Free exploration | ⏳ |
| C2 | Meal Helper | Shoulder + Elbow | 2-step sequence | Eating | ⏳ |
| C3 | Bowling Master | Elbow (aim) + Shoulder (swing) | Multi-joint coordination | Throwing / pushing | ⏳ |

**Status key**: ✅ Complete · 🔄 In Progress · ⏳ Not Started

> **Shield Guard [S3]** is the most developed game — use it as your reference for code patterns.

---

## 4. What's Coming Next

| Game | Status | Notes |
|------|--------|-------|
| **Rhythm Action Game** | Next to build | Prioritized because it doesn't require custom art assets |
| Arm Wrestling Game | On hold | Asset generation strategy (composite sprite cropping) still being finalized |
| All remaining games | Phase 2 (until 2027-02) | One game every ~4 weeks |
| Robot exoskeleton integration | Phase 3 (2027-03~06) | Full hardware loop |

**Final deadline: 2027-06-30**

---

## 5. Your First Tasks

Start small. Each of these tasks is complete and meaningful on its own — you don't need to understand the whole codebase to do them.

---

### Task A — Play-test & Report (1–2 days)

**What**: Run every game in the app and write down anything that feels wrong.

Look for:
- Text that's hard to read or doesn't make sense
- Buttons that don't respond
- Games that crash or freeze
- Anything that would confuse a patient who has never seen a tablet before

**How to report**: Open a GitHub issue for each finding. Title it `[GameID] short description`, e.g. `[S3] Arrow appears behind shield`.

**Why it matters**: You'll be the first person to look at these games with fresh eyes. That's valuable. Clinical users (therapists, patients) can't give us this feedback until much later.

**Start here**: `docs/CHANGELOG.md` — check what's been changed recently before you test.

---

### Task B — Add Sound Effects to Shield Guard (3–5 days)

**What**: Shield Guard [S3] has no sound yet. Add hit sounds, a block sound, and a background track.

**Steps**:
1. Find or create `.mp3` audio files (royalty-free sources: freesound.org, kenney.nl)
2. Place them in `assets/audio/sheild_guard/` (note the typo in the folder name — keep it as-is)
3. Register the paths in `pubspec.yaml` under `flutter: assets:`
4. In `lib/games/games/shield_guard_game.dart`, call `FlameAudio.play('filename.mp3')` at the right game events

**Reference**: `docs/shield_guard_build_guide.md` has the full game structure explained.

**Why it matters**: Sound feedback is especially important for patients with cognitive impairment (Level 1). It reinforces correct movement without relying on reading.

---

### Task C — Multilingual Text in Result Screen (1 week)

**What**: The game result screen (`lib/games/game_result_screen.dart`) shows score and accuracy after each session. Add Korean/English switching to match the app's existing language setting.

**How**: The app already has a language preference stored — find how other screens use it (search for `AppLocalizations` or the locale variable), then apply the same pattern in the result screen.

**Why it matters**: This change applies to every game at once. Patients and therapists who prefer English will immediately benefit.

---

## 6. Key Files to Know

| File | What it does |
|------|-------------|
| `lib/games/game_base.dart` | Defines `BrunnstromStage`, `GameConfig`, `GameResult`, `AngleRecord` — the shared language of the whole system |
| `lib/games/games/shield_guard_game.dart` | Best reference for a complete game implementation |
| `lib/games/angle_normalizer.dart` | Converts raw Bluetooth angle to 0.0–1.0 |
| `lib/games/game_motor_controller.dart` | Sends motor commands over Bluetooth |
| `lib/games/game_result_screen.dart` | Shown after every game session |
| `docs/claude_code_game_dev_guide.md` | Development patterns and conventions for this project |
| `docs/CHANGELOG.md` | What changed and when — read this first |
| `docs/master_development_plan.md` | Full schedule and phase breakdown |

> **Do not modify on your own**: `game_base.dart` and `game_motor_controller.dart` affect every game. Changes require team agreement first.

---

## 7. How to Ask for Help

1. Check `docs/CHANGELOG.md` to understand the current state of the area you're working in
2. Read the relevant `docs/*_build_guide.md` for the game you're touching
3. Then ask — with a specific question, not "I'm confused about everything"

Good question: *"In shield_guard_game.dart line 82, `_holdTimer` resets when the arm drops below threshold — is that intentional or a bug?"*

Less helpful: *"I don't understand how the game works."*
