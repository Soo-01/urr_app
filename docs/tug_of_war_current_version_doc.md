# Tug of War — Current Implementation

**File**: `lib/games/games/tug_of_war_game.dart` (+ setup UI in `lib/games/game_hub.dart`)
**Last Updated**: 2026-09-08

This document describes what is actually implemented right now, in plain terms — not the full design plan. For the target design, see `tug_of_war_build_guide.md`.

Against the 8-step per-game build order in `claude_code_game_dev_guide.md §6`, steps 1–4 are done, step 5 (PNG sprites) is **not** started (everything is procedural `Canvas` drawing), and steps 6 (particles/effects), 7 (HUD) and 8 (difficulty binding) are now covered. Motor/round-system items from the build guide's Phase 2–4 that require the physical robot are out of scope here.

---

## Two Force Modes

The clinician picks one of two ways to generate rope-pulling force on the **setup screen** (`줄다리기 방식`, shown only for this game), passed to the game as `mode`:

- **Cycle (`반복 당기기`)** — repeated elbow flex→extend; the original mechanic. See *Pull Detection (Cycle)* below.
- **Hold (`버티기 / 자세 유지`)** — an isometric sustained contraction. See *Pull Detection (Hold)* below.

If `config.motorMode` is set to isometric the setup screen still lets the clinician override; the explicit chip choice wins. The active mode is shown as a badge in the HUD.

---

## Pull Detection (Cycle)

A pull is not read from a static joint angle but from a full motion cycle: the arm must flex and then extend again for one pull to count. The game watches the normalized position rise past a small threshold (start of flex), then fall past that same threshold (flex complete) — one pull recorded.

Pull strength scales with how far and how fast the joint moved, and now also with **ROM quality**: how much of the stage-derived target range (`_romTarget`, from `config.romRatio`) the cycle covered — a token 35% is always credited, a full-range pull gets the whole gain. A cycle only increments the pull counter if it covered at least ~40% of the target range. Accumulated pull power decays over time (`_pullPower *= (1 - dt * 0.6)`), so continuous repetition is required.

The completion check requires the motion to clearly reverse past a small buffer rather than ending on a momentary pause, so uneven slider drags or sensor noise are not misread.

---

## Pull Detection (Hold)

Instead of counting cycles, the game reads *how far a flexed posture is held* and turns that directly into pulling force (isometric):

- `held` = current position mapped against a stage-scaled span (deeper flexion required at higher Brunnstrom stages, via `_romTarget`).
- Target force = `held × _holdMaxPull (18) × _playerPowerMul`.
- `_pullPower` eases toward that target — rising slowly while held, collapsing quickly when released.
- Let go and the force falls to zero, so the opponent takes the rope. In simulation the slider **auto-returns to the left (0.0)** at ~0.55/s (a `Timer.periodic` in the Flutter wrapper); with a real motor the constant isotonic resistance does the same job physically.
- "Held seconds" accumulate for scoring (2 s held ≈ one rep).

The cycle-mode power decay is skipped in hold mode (the force is re-derived from posture every frame).

---

## Adaptive Animal AI

The opponent's pulling force is recomputed every frame from four factors:

1. **Base strength by animal** — Chimpanzee 7, Orangutan 11, Gorilla 15.
2. **Difficulty multiplier** `_aiStrengthMul` — from the 1–5 in-stage difficulty slider: 0.82 (level 1) → 1.18 (level 5).
3. **Adaptive factor** — if the player is winning (rope > 0.3) the opponent strengthens 15%; if losing (rope < −0.3) it weakens 15%. Damps runaway matches.
4. **Animal-specific wave** — Chimpanzee tugs fast/erratic, Orangutan slow/steady, Gorilla holds steady with occasional heavy bursts.

`_aiPower = base × _aiStrengthMul × adaptiveFactor × (1 + wave)`. This value drives the rope physics and (with a motor) is sent as isotonic resistance.

"AI" here is the game-dev sense: fixed constants + one performance rule, re-evaluated per frame. Nothing learns across sessions.

---

## Win / Lose Logic

Rope position runs −1 (full loss) … 0 (centre) … +1 (full win). Each frame `(_pullPower − _aiPower)` shifts it. Reaching +1 wins, −1 loses.

**Time limit** — `config.gameDuration` sets `_timeLimit`. When it elapses the match resolves immediately to whoever leads the rope (a dead tie goes to the player). A HUD timer counts this down.

On a decision the losing fighter is dragged to the centre of the bridge and a 4-stage fall plays (stagger → foot-slip + dust → fall → splash in the river) before the result screen. Still a single round — no best-of-three yet.

---

## Difficulty & Cognitive Binding

- **Brunnstrom stage** picks the animal once at load: 2–3 Chimpanzee, 4 Orangutan, 5–6 Gorilla. It also sets `_romTarget` (`config.romRatio × 0.5`, clamped) — the range a pull/hold must cover for full credit, so higher stages demand fuller ROM.
- **Difficulty slider (1–5)** is the secondary knob: `_aiStrengthMul` 0.82→1.18 and `_playerPowerMul` 1.20→0.88, so higher = stronger opponent and less assist.
- **CognitiveLevel** drives visual load:
  - `bgComplexity` 0/1/2 → scene detail tiers. Simple = gradient sky + river + cliffs + bridge only. Moderate adds mist band, river ripples, cliff-edge grass. Rich adds distant canopy silhouettes + hanging vines.
  - `particleCount` caps effect particle counts (`_fxCount`).
  - `showTimer` / `showCombo` (level ≥ 2) gate the HUD timer, force readouts and progress line.

---

## Scene & Characters (procedural)

All drawing is `Canvas` primitives — no sprites yet.

- **Canyon background** — vertical jungle gradient, hazy canopy silhouettes, mist band, and a river at the bottom of the gorge with animated ripples (the fall/splash target).
- **Two cliffs** — rock masses with jagged inner edges, grassy lips with dangling blades, swaying vines.
- **Rope bridge** — catenary handrail + foot ropes between the cliff posts, wooden planks that tilt along the sag, hanger cords. `_standY(x)` is the shared terrain height: flat on cliff tops, sagging on the span. Fighters, rope-hand anchors, HUD label and fall dust all sit on it.
- **The tug rope** — two quadratic-bézier segments (hand → knot → hand) that droop like a catenary; tighter (less sag, less wobble) the harder both sides pull; only the fallen side's segment goes slack. Twist ticks along the curve.
- **Centre knot ("nut")** — a round wrapped-rope bulge with a small pennant flag, sliding toward whichever side is *winning* (the one reeling the rope in).
- **Losing side is dragged** toward the centre (`_playerCenterX` / `_opponentCenterX`) as the rope turns against them, then falls toward the river.
- **Human player** — bracing stance, both arms gripping the rope, hair/nose for facing.
- **Three distinct animals** — small hunched chimp with big ears and long arms; round shaggy orangutan with cheek flanges and a fur fringe; massive black gorilla with broad shoulders, a silver back patch and a crested head.
- **Effort visualisation** — as the player pulls harder *or* falls further behind, the figure leans deeper, trembles, digs the front foot in, reddens, clenches its teeth and emits motion lines + a sweat drop. Same for the animal when it is losing.

---

## HUD (step 7) — `_drawHud`

- **Advantage gauge** (top centre): a bar from −1 (you) to +1 (opponent) with a centre tick, a fill growing from centre toward the leading side (blue = you, orange = animal) and a knot marker at the rope position. `나` / animal-name (`침팬지`/`오랑우탄`/`고릴라`) at the ends.
- **Mode badge** — `반복` or `버티기`.
- **Timer** `M:SS` — counts down from the time limit (or up if none). Shown at CognitiveLevel ≥ 2.
- **Force readouts** — `당기는 힘` / `상대 힘`. **Progress** — `당긴 횟수` (cycle) or `버틴 시간` (hold). Both at CognitiveLevel ≥ 2.
- The HUD is drawn after the screen-shake transform is released, so it never jitters.

---

## Effects (step 6) — `_Particle` system

One generalised particle list (position, velocity, gravity, fade rate, optional rotating rect):

- **Victory confetti** rains from the top when the opponent falls.
- **Effort puffs** at the player's hands — on each completed pull (cycle), or every ~0.45 s while holding.
- **Tension sparks** burst from the knot on a strong pull.
- **Screen shake** (`_shake`, self-decaying) on strong pulls, the fall trigger, and the splash impact — applied to the world layer only.
- **Win / lose flash** — a brief green/red full-screen tint on the result.
- Fall dust + water splash from the 4-stage fall (unchanged).
- All particle counts are capped by `CognitiveLevel.particleCount`.

---

## Start Countdown

A 3-2-1 countdown freezes all game logic (no pull detection, no opponent force, rope fixed) so the match can't be lost before the player has interacted. Effects and shake still settle during it.

---

## Score

`score = _pullCount × 8 + (won ? 40 : 0)`, clamped to `maxPossibleScore = 100`. `_pullCount` is completed cycles (cycle mode) or `heldSeconds / 2` (hold mode). Accuracy is 1.0 on a win, 0.0 otherwise.

---

## Motor / Bluetooth Integration (hardware)

When a device is connected the game selects the configured joint and starts isotonic (constant-resistance) motor mode for **both** force modes — in hold mode that constant pull toward extension *is* the resistance the patient holds against. `_aiPower` is re-sent every 500 ms so felt resistance tracks the in-game opponent. A watchdog stops the motor if telemetry drops; `onFallTriggered` stops it immediately on a decision. Manual pause, stop (counts as a loss) and emergency-stop are available.

---

## Simulation Mode & Controls

With no device, a slider simulates joint position. In **hold mode** the slider starts at 0.0 and continuously drifts left, so the tester must keep dragging right to sustain force. In **cycle mode** it behaves as a normal input slider. Pause / stop / emergency-stop work regardless of connection.
