# Upper-Limb Rehabilitation Games for Stroke / Hemiplegia Patients
## A Comprehensive Review for Game Developers and Clinicians

**Compiled:** March 2026
**Scope:** Commercial/research robotic systems, game mechanics, clinical evidence, design principles, and open-source frameworks

---

## Table of Contents

1. [Clinical Systems Overview](#1-clinical-systems-overview)
   - 1.1 InMotion ARM (BIONIK / Interactive Motion Technologies)
   - 1.2 KINARM (BKIN Technologies, Kingston, Canada)
   - 1.3 Armeo Family (Hocoma)
   - 1.4 Tyromotion (Amadeo, Pablo, Diego)
   - 1.5 ReoGo / ReoGo-J (Motorika)
   - 1.6 YouGrabber (YouRehab)
   - 1.7 Rehabilitation Gaming System (RGS) — Barcelona
2. [Game Mechanics by System](#2-game-mechanics-by-system)
3. [Clinical Evidence](#3-clinical-evidence)
4. [Game Design Principles for Neurorehabilitation](#4-game-design-principles-for-neurorehabilitation)
5. [Open-Source and Academic Game Frameworks](#5-open-source-and-academic-game-frameworks)
6. [Summary Table](#6-summary-table)
7. [References](#7-references)

---

## 1. Clinical Systems Overview

### 1.1 InMotion ARM — BIONIK Laboratories (formerly Interactive Motion Technologies)

**Origin:** MIT-MANUS robot developed at MIT by Hermano Igo Krebs and Neville Hogan in the early 1990s; commercialized first as the InMotion2, later by BIONIK Laboratories.

**Hardware:**
- End-effector robot — patient grasps or is strapped to a handle that moves in the horizontal plane
- Two-DOF (shoulder + elbow in horizontal plane) primary module
- Separate wrist (3-DOF) and hand modules available
- Assist-as-needed (AAN) impedance control: the robot only provides force when the patient deviates from the target trajectory

**Joints Targeted:**
- Shoulder flexion/extension, internal/external rotation, protraction/retraction
- Elbow flexion/extension
- Wrist supination/pronation, flexion/extension (separate module)

**Game / Task Library:**
| Task Name | Movement Required | Cognitive Element |
|-----------|------------------|-------------------|
| Clock task (Reach-to-target) | Point-to-point reaching to 8–16 targets on a clock face | Visual target acquisition |
| Maze game | Continuous path-following | Sustained attention, visual tracking |
| Circle drawing | Circular reaching trajectories | Motor coordination |
| Reach & Squeeze | Reach + grip force at endpoint | Bimanual grasp simulation |
| Soccer / Pong variants | Reactive reaching | Reaction time, distractor avoidance |
| Cognitive skills overlay | Multi-step motor + cognitive cues | Alternating/sustained attention |

Approximately **1,000 movements per session** is achievable with the clock/reaching paradigm — the most-studied protocol in the literature.

**Patient Population / Severity:**
- Best evidence in moderate-to-severe upper limb impairment (FMA-UE < 30)
- Used from acute through chronic phases
- Over **900 stroke patients** enrolled across clinical trials; ~250 robots deployed worldwide as of 2023

---

### 1.2 KINARM — BKIN Technologies (Kingston, Canada)

**Origin:** Developed by Stephen Scott at Queen's University; two product lines are available.

**Hardware:**
- **KINARM Exoskeleton Lab:** shoulder and elbow exoskeleton supporting the arm in the horizontal plane; each joint can be independently driven
- **KINARM End-Point Lab:** two planar manipulandums; used when high stiffness and hand-based haptic feedback are required

**Joints Targeted:**
- Shoulder flexion/extension (horizontal plane)
- Elbow flexion/extension
- Independent joint-level torque sensing and control (unique feature vs. end-effector robots)

**Standardized Task / Game Library (KINARM Standard Tests):**
| Task | Description | Cognitive/Motor Demand |
|------|-------------|----------------------|
| Visually Guided Reaching (VGR) | Move to peripheral targets quickly and accurately | Visuomotor integration, multi-joint coordination |
| Ball on Bar | Bimanual: balance a virtual ball on a bar controlled by both hands | Bimanual coordination, force modulation |
| Object Hit | Hit objects falling toward the screen | Rapid motor planning, reaction time |
| Egg Frying / Window Cleaning | Move arm through functional postures | Spatial navigation, posture control |
| Shooting targets | Task-specific reaching with scoring | Visual attention, accuracy |

Sensor data is projected to a virtual display below a semi-silvered mirror, keeping the patient's arms out of view (pure proprioceptive + visual feedback dissociation possible).

**Difficulty Adaptation:**
- Target distance, speed, and number of distractors can be graded
- Kinematic outcome metrics (reaction time, path length, peak velocity) feed into assessment-driven difficulty progression

**Unique Strength:** Gold-standard kinematic assessment — provides joint torques, multi-joint coordination metrics, and proprioceptive evaluation alongside therapy.

---

### 1.3 Armeo Family — Hocoma (Zurich, Switzerland)

Hocoma offers a graded system for all impairment levels:

| Device | Mechanism | Target Severity |
|--------|-----------|-----------------|
| **Armeo Power** | Motorized exoskeleton, passive + active assistance | Severe (no voluntary movement) |
| **Armeo Spring** | Passive spring-balanced exoskeleton | Mild–moderate |
| **Armeo Spring Pro** | Enhanced spring system with more DOF | Mild–moderate |
| **Armeo Senso** | Sensor-only (wearable, no exoskeleton) | Mild |
| **Armeo Boom** | Counterbalanced arm support | Moderate |

**Joints Targeted:**
- Shoulder flexion/extension and abduction/adduction
- Elbow flexion/extension
- Forearm supination/pronation
- Wrist extension (Armeo Power / Spring Pro)
- Grip force (pressure-sensitive handgrip)

**Game / Exercise Library:**
| Exercise / Game | Movement Targeted | Difficulty Axis |
|----------------|-------------------|-----------------|
| Balloons | Shoulder elevation + elbow extension to pop ascending balloons | Target height, speed |
| Fly High Elbow | Isolated elbow extension | Range of motion threshold |
| The Goalkeeper | Rapid lateral shoulder movement to block incoming balls | Speed, number of balls |
| Pirate Adventure | Full 3D reaching across a virtual ship deck | Workspace size, obstacle complexity |
| Roll the Ball | Controlled forearm rotation + shoulder abduction | Precision, ball speed |
| Vertical Fishing | 1D shoulder elevation (severe patients) | Excursion distance |
| Horizontal Fishing | 1D horizontal reach (severe patients) | Excursion distance |
| Reaction Time (Abacus) | Multi-direction reaching | Response speed, target number |
| Wall | Push virtual object against resistance | Force threshold |
| Meteors (ArmeoSenso) | Lift arm + reach to catch falling meteors | Gravity compensation level, meteor speed |

**1D exercises** target single joints for severely affected patients; **2D/3D exercises** target multi-joint coordination for moderately affected patients.

**Difficulty Adaptation:**
- Spring tension (gravity compensation) adjustable — reducing support as patient improves
- Workspace size automatically tailored to patient ROM
- Exercises self-scale: target range, speed, number of objects, and obstacle density

**Key Clinical Evidence:**
- **REM-AVC trial** (Duret et al., *Stroke*, 2020): Phase III RCT (n=143 subacute stroke), Armeo Spring vs. stretching/active exercises — no significant FMA-UE difference at primary endpoint; Armeo group had higher engagement and exercise volume
- Comparison with Kinect-based system (Klamroth-Marganska et al., *Medicine*, 2019): No significant difference in FMA-UE; grip strength recovery favored robotic group

---

### 1.4 Tyromotion — Amadeo, Pablo, Diego (Graz, Austria)

Tyromotion offers three distinct devices targeting different body segments, all powered by the **tyroS** software platform.

#### Amadeo — Finger-Hand Rehabilitation
- Robotically actuated finger splints; each finger driven independently
- Passive, active-assisted, active, and resistive modes
- Suitable for severe hand paresis (including patients with no voluntary finger movement)
- Spasticity assessment capability (published in *Frontiers in Neurorobotics*, 2023)
- Games include: target-reaching tasks via finger force/position, piano-playing simulation, grip-and-release exercises

#### Pablo — Upper Extremity Functional Rehabilitation
- Sensor-based (pressure sensor, inclination sensor) wand/handle device
- Not an exoskeleton — uses biofeedback and gamification
- Targets grip, forearm rotation, shoulder, and core
- Games: ball-rolling, balance tasks, functional ADL simulations

#### Diego — Bilateral Shoulder-Arm Rehabilitation
- Suspension/assistance system for both arms simultaneously
- Active, active-assisted, and resistive training modes
- Targets shoulder and elbow in functional reaching tasks
- Bilateral training design (trains both limbs simultaneously)

**tyroS Software Games (cross-device):**
| Game | Devices | Motor Target |
|------|---------|-------------|
| Bricks Breaker | Amadeo, Diego, Pablo, Omego, Tymo, Myro | Precision upper-limb control |
| Paddle Boat | Amadeo, Diego, Pablo, Omego, Tymo, Myro | Sustained movement, direction control |
| Ski Champion | Lexo (gait) | Lower limb (note: gait device) |

tyroS combines motor, sensory, and cognitive training with gamification, biofeedback, and performance reporting in a single platform.

---

### 1.5 ReoGo / ReoGo-J — Motorika (Israel / Japan)

**Hardware:**
- Fully motorized end-effector robot
- Patient holds a handle attached to a motorized arm
- Supports 3D movement: shoulder + elbow in a larger workspace than purely horizontal systems

**Five Therapy Modes (graduated assistance):**
| Mode | Description | Patient Level |
|------|-------------|--------------|
| Guided | Full robot drives movement; patient passive | Severe/flaccid |
| Initiated | Patient initiates movement; robot completes it | Severe-moderate |
| Step-Initiated | Patient initiates partial movements; robot assists rest | Moderate |
| Follow-Assist | Patient drives movement; low continuous robot assist | Moderate-mild |
| Free | Full voluntary movement; no robot assistance | Mild/recovery |

**Games:** ReoGo has a dedicated game menu with adjustable difficulty levels for each mode. Games target:
- Point-to-point reaching (8 directions)
- Trajectory following
- Task-oriented activities simulating ADLs

**ReoGo-J (Japan, 2024):** A 2024 cross-sectional clinical trial (*Scientific Reports*, 2024) developed an item response theory-based automatic setting optimization system. The ReoGo-J device has **71 training items** rated on a 3-point scale; an algorithm determines optimal difficulty settings automatically from a brief initial assessment — the first published system of this type.

**Key Clinical Evidence:**
- Randomized trial (Guidali et al., *Journal of NeuroEngineering and Rehabilitation*, 2011): 19 patients with chronic hemiparesis — significant improvements in proximal UE and flexor synergy (FMA-UE) vs. self-guided therapy
- Meta-analysis (Lee et al., *Kaohsiung J Med Sci*, 2023): robotic arm interventions including ReoGo significantly improved upper limb function (FMA-UE, ARAT) in stroke patients

---

### 1.6 YouGrabber (YouRehab, Switzerland)

**Hardware:**
- Wearable data gloves with inertial/position sensors (no exoskeleton)
- Non-immersive VR: screen-based display
- Lightweight, portable; designed for clinic and community settings

**Joints Targeted:**
- Arm, hand, and finger movements (all upper limb segments)
- Specifically developed for arm + hand + finger tasks only

**Three Training Modes:**
1. **Normal mode** — left/right real hands control their virtual counterparts
2. **Virtual Mirror Therapy** — one real hand controls both virtual arms (affected arm mirrored)
3. **Virtual Following** — affected virtual hand follows the unaffected real hand

**Game Library:**
| Game | Movement Target |
|------|----------------|
| Airplane | Shoulder/elbow reach and navigation |
| Magic Finger | Isolated finger extension/flexion |
| Toy Catching | Bimanual reach and grasp |
| Catch the Carrot | Reactive reaching, hand opening |
| Tomato Juggling | Timed grasp-and-release |
| Shopping | Functional reach-grasp-place (ADL simulation) |

**Three Feedback Modalities:** acoustic, visual, and sensory (haptic) — all three simultaneously delivered.

**Engagement Evidence:** YouRehab reports patients train "up to three times harder" vs. conventional occupational therapy; clinicians can supervise 2–3 patients simultaneously.

**Applicable Populations:** Stroke, TBI, cerebral palsy, multiple sclerosis, other CNS disorders.

**Key Clinical Evidence:**
- Pilot feasibility study (Laver et al., *Disability and Rehabilitation*, 2017): feasible and motivating in community rehabilitation; patients reported high enjoyment
- Qualitative study (Laver et al., *Disability and Rehabilitation: Assistive Technology*, 2018): positive patient and health professional experiences; key themes — engagement, ease of use, potential for unsupervised practice

---

### 1.7 Rehabilitation Gaming System (RGS) — SPECS Lab, Universitat Pompeu Fabra, Barcelona

**Hardware:**
- Camera-based motion capture (no physical robot)
- Wearable inertial sensors or depth cameras track arm movements
- Screen-based VR display; not immersive VR

**Unique Design Features:**
- Grounded in neuroscientific principles: mirror neuron system activation via action observation
- Individualized adaptive difficulty (DDA): adjusts task difficulty online based on performance
- Tasks increase complexity as the patient masters each skill

**Game Scenarios:**
- Virtual object reaching, grasping, and transport
- Target-hitting
- Bimanual tasks
- "Message in a Bottle" combined cognitive-motor scenario: motor action → cognitive challenge → second motor action (integrated dual-task design)

**Tested With:** >1,500 stroke patients at acute, subacute, and chronic stages, including home settings.

**Key Clinical Evidence:**
- **Cameirão et al.** (*NeuroRehabilitation and Neural Repair*, 2011): RCT in acute stroke (n=16); RGS group showed significantly faster improvement on Fugl-Meyer and Chedoke Arm and Hand Activity Inventory vs. conventional therapy
- **Cameirao et al.** (*Journal of NeuroEngineering and Rehabilitation*, 2010): Review of RGS system design and adaptive algorithm
- Adaptive difficulty system validated: game difficulty auto-adapts within ~30 minutes to match individual impairment level

---

## 2. Game Mechanics by System

### 2.1 Joint Targeting by System

| System | Shoulder Flex/Ext | Shoulder Rot | Elbow | Wrist | Hand/Finger |
|--------|:-----------------:|:------------:|:-----:|:-----:|:-----------:|
| InMotion ARM | Yes | Limited | Yes | Module | Module |
| KINARM Exo | Yes | No | Yes | No | No |
| Armeo Spring/Power | Yes | Yes | Yes | Yes | Grip |
| Tyromotion Diego | Yes | Yes | Yes | Partial | No |
| Tyromotion Amadeo | No | No | No | No | Yes (all) |
| Tyromotion Pablo | Yes | Yes | Yes | Yes | Grip |
| ReoGo | Yes | Yes | Yes | No | No |
| YouGrabber | Yes | Yes | Yes | Yes | Yes (full) |
| RGS | Yes | Yes | Yes | Yes | Partial |

### 2.2 Difficulty Adaptation Mechanisms

All modern systems use some form of **Dynamic Difficulty Adjustment (DDA)**. Core approaches:

1. **Workspace Scaling** — target distance grows as ROM improves (Armeo, ReoGo)
2. **Assistance Reduction** — gravity compensation or robot torque reduces as strength recovers (Armeo spring tension, ReoGo modes)
3. **Speed/Timing** — target appearance speed or window narrows (KINARM, YouGrabber, RGS)
4. **Distractor Density** — number of competing objects increases (RGS, YouGrabber)
5. **Trajectory Complexity** — from straight-line reaching to curved, multi-step paths (InMotion, ReoGo)
6. **Cognitive Load Escalation** — secondary cognitive tasks added only after motor skill is stabilized (RGS "Message in a Bottle"; dual-task overlays in Pablo)
7. **Brunnstrom / FMA Staging** — clinician-set mode determines starting difficulty tier; auto-DDA adjusts within tier (all systems)
8. **Item Response Theory** — automated optimal setting selection based on initial assessment battery (ReoGo-J, 2024)

### 2.3 Cognitive Elements in Game Design

| Cognitive Domain | Implementation Examples |
|-----------------|------------------------|
| Target selection | Multiple simultaneous targets; patient must select correct color/shape (Armeo Pirate, RGS) |
| Distractor avoidance | Objects to avoid mixed with targets (YouGrabber, RGS, KINARM Object Hit) |
| Sustained attention | Long continuous maze / trajectory tracking (InMotion maze, RGS) |
| Reaction time | Sudden target appearance, moving targets (KINARM Object Hit, ReoGo) |
| Spatial working memory | Sequence of targets to remember (RGS, Pablo) |
| Bimanual coordination | Both arms required simultaneously (KINARM Ball on Bar, Diego, YouGrabber mirror therapy) |
| Integrated dual-task | Motor action required to unlock cognitive challenge, then second motor action (RGS "Message in a Bottle") |

---

## 3. Clinical Evidence

### 3.1 Key Systematic Reviews and Meta-Analyses

| Authors | Year | Journal | N studies / N patients | Main Finding |
|---------|------|---------|----------------------|-------------|
| Mehrholz, Pohl, et al. | 2018 | *Cochrane Database Syst Rev* | 34 RCTs / 1,160 pts | Robot-assisted therapy improved arm function and ADLs; evidence quality low to moderate |
| Lo, Guarino, et al. | 2010 | *N Engl J Med* | 1 RCT / 127 pts (chronic) | Robot therapy + usual care not superior to intensive therapy alone at 36 weeks; both better than usual care |
| Kwakkel, Kollen, Krebs | 2008 | *Neurorehabil Neural Repair* | Systematic review | Significant improvement in arm motor function (FMA); shoulder + elbow benefit more than wrist + hand |
| Mehrholz, Pollock, et al. | 2020 | *J Neuroeng Rehabil* | Network meta-analysis | All robot types improve FMA-UE; electromechanical devices also improve ADLs |
| RATULS Trial (Rodgers et al.) | 2019 | *The Lancet* | 1 RCT / 770 pts | InMotion ARM: no significant advantage over enhanced upper limb therapy; cost-effectiveness uncertain |
| Chien et al. | 2020 | *Brain and Behavior* | Meta-analysis / subacute only | Significant FMA-UE improvement; effect size larger in subacute vs. chronic |
| Cai et al. | 2023 | *Archives of Phys Med Rehabil* | Systematic review + meta-analysis | RAT significantly improved FMA-UE (SMD 0.69, 95% CI 0.34–1.05, p<0.001) |
| Urra et al. (Game-based, VR) | 2021 | *JMIR Serious Games* | Meta-analysis / 26 studies | Game-based rehab: mean FMA-UE improvement 3.10 points vs. control (p=0.002) |
| Lee et al. | 2023 | *Kaohsiung J Med Sci* | Systematic review + meta-analysis | Robotic arm significantly improved UL function and hand function; 30–60 min/session optimal |

### 3.2 Landmark Device-Specific Trials

| Trial | System | Design | Key Result |
|-------|--------|--------|-----------|
| Cameirão et al. (2011) | RGS | RCT, acute stroke, n=16 | RGS group: significantly better FMA + Chedoke scores; faster improvement |
| Duret et al. / REM-AVC (2020) | Armeo Spring | Phase III RCT, subacute, n=143 | No significant FMA-UE difference; engagement and exercise volume higher with Armeo |
| Guidali et al. (2011) | ReoGo | RCT, chronic, n=19 | Significant FMA proximal UE improvement vs. self-guided therapy |
| Lo et al. (2010) | InMotion ARM | RCT, chronic, n=127 | Robot + usual care not superior to dose-matched conventional therapy |
| RATULS (2019) | InMotion ARM | Multi-centre RCT, n=770 | InMotion ARM not significantly better; both robot and enhanced therapy improved over usual care |
| Klamroth-Marganska et al. | Armeo Spring vs. Kinect | Comparative, subacute | No FMA-UE difference; grip strength favored robotic group |

### 3.3 Outcome Measures Used

| Measure | What It Tests | Sensitivity to Robot Therapy |
|---------|--------------|------------------------------|
| **FMA-UE** (Fugl-Meyer Assessment Upper Extremity, 0–66) | Impairment: voluntary movement, reflexes, coordination | High — most commonly reported; robot therapy consistently shows significant gains |
| **ARAT** (Action Research Arm Test, 0–57) | Activity: grasp, grip, pinch, gross movement | Moderate — less sensitive than FMA-UE in severe patients |
| **WMFT** (Wolf Motor Function Test) | Activity: 15 timed functional tasks | Not consistently improved — 5 RCTs pooled: no significant difference (meta-analysis 2023) |
| **Barthel Index** (0–100) | ADL independence | Inconsistent — improved in some Cochrane analyses |
| **Kinematics** (velocity, smoothness, path length, ROM) | Motor control quality | Sensitive — improves even when FMA-UE unchanged; valuable for mechanism studies |
| **MAS** (Modified Ashworth Scale) | Spasticity | Mixed — robot therapy may reduce spasticity |
| **CAHAI / CAHD** (Chedoke Arm and Hand Activity Inventory) | Bimanual ADL function | Used in RGS studies; sensitive to change |
| **MoCA** (Montreal Cognitive Assessment) | Cognitive function | Improved in dual-task game studies |

### 3.4 Dose-Response Findings

- Patients can perform **280–1,300 repetitions per robot session** (mean ~600–800 reps); conventional therapy delivers ~32–50 repetitions/session
- Animal models: **>400 movements/session** required to enhance motor system connectivity
- Human studies: **>300 movements/session** required for significant cortical and clinical changes
- Meta-analysis finding: **30–60 min/session** is the optimal session duration for UL robotic therapy
- **Ceiling effect observed:** no monotonic dose-response above the minimum threshold; more repetitions beyond ~600/session do not proportionally increase benefit
- Typical protocols: **5 days/week, 3–6 weeks** for subacute; **3 days/week, 8–12 weeks** for chronic
- Combined robot + conventional therapy superior to either alone in several subacute trials

---

## 4. Game Design Principles for Neurorehabilitation

### 4.1 Core Neurorehabilitation Principles Driving Game Design

Based on evidence for neuroplasticity and motor learning (Frontiers in Neurology, 2019):

1. **Massed / Repetitive Practice** — hundreds of task-specific repetitions per session
2. **Task-Specific Practice** — movements that mirror functional ADL demands
3. **Variable Practice** — varying targets, trajectories, speeds to promote generalization
4. **Increasing Difficulty (Progressive Overload)** — scaffold complexity as skill improves
5. **Multisensory Information** — simultaneous visual, auditory, and haptic feedback
6. **Explicit Knowledge of Results** — score, accuracy %, time displayed after each rep
7. **Implicit Knowledge of Performance** — real-time cursor or avatar movement feedback
8. **Action Observation** — watching avatar perform the movement activates mirror neurons
9. **Mental Practice** — visualization of movement (some VR systems implement this)
10. **Social Interaction** — competitive leaderboards, therapist observation, group modes

### 4.2 Feedback Types

| Feedback Type | Implementation in Rehab Games | Evidence |
|--------------|-------------------------------|---------|
| **Visual — augmented** | Real-time cursor/avatar tracking hand/arm position | Universal; reduces reliance on proprioception in severe cases |
| **Visual — knowledge of results** | Score, target hit/miss, progress bars, level-up animations | Increases motivation; should be delivered immediately after movement |
| **Visual — error amplification** | Cursor deviated from actual hand position to encourage correction | Promotes active error correction; used in KINARM |
| **Auditory — feedback tones** | Positive chime on target hit, neutral on miss | Reinforces correct movements; useful for patients with visual impairment |
| **Auditory — TTS narration** | Voice countdown, instruction, encouragement | Reduces cognitive demand for reading; aids patients with aphasia |
| **Haptic — force feedback** | Robot provides resistance when approaching target (InMotion, KINARM) | Proprioceptive enrichment; may enhance motor learning |
| **Haptic — vibrotactile** | Vibration at target contact or error (exoskeleton gloves) | Supplementary; used in some research prototypes |

### 4.3 Repetition Targets

| Category | Target Repetitions | Source |
|----------|-------------------|--------|
| Minimum for cortical change | >300 reps/session | Human motor learning studies |
| Animal model threshold | >400 reps/session | Nudo et al. (rodent stroke models) |
| Typical robot session | 600–1,000 reps/session | Clinical trial data (meta-analysis) |
| Conventional therapy | 32–50 reps/session | Observation studies in stroke units |
| Robot therapy upper range | Up to 3,600 reps/session | Reported in some intensity studies |

**Implication for game design:** each game round or level should target approximately 50–100 discrete movements; sessions should chain 6–10 rounds with rest intervals to accumulate 300–600+ repetitions.

### 4.4 Motivation and Engagement Strategies

Based on game design theory applied to rehabilitation (Barrett et al., 2016; PMC6453078):

| Strategy | Implementation |
|----------|---------------|
| **Flow State** (Csikszentmihalyi) | DDA ensures challenge always slightly exceeds current skill — prevents boredom and anxiety |
| **Intrinsic Reward** | Points, level progression, unlockable content for meeting motor targets |
| **Clear Goals** | Each game round has an explicit goal (hit 10 targets, navigate maze in < 60s) |
| **Immediate Feedback** | No delayed reward — feedback is real-time or within 1–2 seconds |
| **Failure as Learning** | Missed targets trigger visual "near-miss" feedback, not penalty sounds — avoids learned helplessness |
| **Progress Visualization** | Session-over-session performance graphs; ROM improvement charts |
| **Narrative / Theme** | Pirate adventure, space, sports themes increase enjoyment and emotional engagement |
| **Choice and Agency** | Patient selects from 2–3 game options each session (empowerment) |
| **Social / Competitive** | Leaderboards, head-to-head with avatar of previous-session self |
| **Positive Reinforcement Focus** | Research shows positive feedback is more effective than error focus in neurological patients |

### 4.5 Cognitive-Motor Dual-Task Benefits

Evidence from a 2021 meta-analysis (*Frontiers in Human Neuroscience*) and a 2026 medRxiv preprint:

- Stroke patients show deficits in **divided attention** during upper limb movement — more saccades to distractors, reduced force control
- **Two approaches** to dual-task design in games:
  1. **Classical dual-task:** cognitive task added as secondary distractor of motor task (counts backward while reaching)
  2. **Integrated dual-task:** cognitive task embedded as a prerequisite for motor success (select correct target color before reaching) — RGS "Message in a Bottle" approach
- Cognitive-motor dual-task training (CMDT) produces **greater cognitive improvement** than single-task motor training alone
- Recommended in chronic stroke for patients with mild-moderate cognitive impairment (MoCA 18–25)
- Caution: dual-task adds cognitive load — not appropriate for severe aphasia or significant attentional deficits without therapist supervision

---

## 5. Open-Source and Academic Game Frameworks

### 5.1 Kinect-Based Systems

**Microsoft Kinect V1 / V2** became the dominant low-cost motion capture platform for academic rehab game research from 2012 to ~2022 (before Kinect discontinuation).

| System/Paper | Year | Games | Target | Platform |
|-------------|------|-------|--------|----------|
| Palacios-Navarro et al. | 2015 | Bird Dodge, Hit Catch, Burst, Veggie Pick | Shoulder/elbow | Kinect V1 + Unity |
| Mystic Isle | 2020 | Full-body multi-planar adventure | UL + trunk | Kinect V2 + Unity |
| Bilateral UL Rehab (IEEE, 2018) | 2018 | Bilateral reaching game | Bimanual shoulder/elbow | Kinect V2 |
| Validation Kinect V2 (PLoS One, 2018) | 2018 | Custom reaching task | Shoulder/elbow ROM | Kinect V2 |
| Xbox Kinect VR effects (ScienceDirect, 2017) | 2017 | Commercial Xbox games | UL functional | Xbox Kinect |

**OpenNI SDK** — the open-source skeleton-tracking library underlying many Kinect-based prototypes. Allows creation or modification of software for non-commercial use. Most projects used OpenNI + NITE for skeleton tracking, then passed joint angles to Unity or custom renderers.

### 5.2 Unity-Based Open Frameworks

| Framework | Source | Features |
|-----------|--------|---------|
| **Unity-Rehab-Game-Framework** (BeppeInfo) | [GitHub](https://github.com/BeppeInfo/Unity-Rehab-Game-Framework) | Base for rehab games using Unity3D + RobRehabSystem; connects to robotic controllers |
| **RobRehabSystem** (Bitiquinho) | GitHub | Open-source robot control backend for Unity rehab games |
| **ReHAb Playground** (MDPI, *Future Internet*, 2025) | Academic paper | Deep learning-based gesture recognition + 3D hand tracking; Unity; home rehab |
| **AdaptRehab VR** | ResearchGate | Unity 3D adaptive VR rehab games; auto difficulty adjustment |
| **Low-cost game framework** (Academia.edu) | Academic paper | Low-cost home stroke rehab system; motion sensing + Unity |

### 5.3 Leap Motion / Depth Camera Systems

- **Leap Motion Controller** — hand and finger tracking at high precision (sub-millimeter); used for wrist/hand/finger rehabilitation games
- Development of 3D exergame for upper limb using Leap Motion + Unity (IEEE, 2021)
- Suitable for distal UL (wrist, finger) tasks where Kinect skeleton tracking is insufficient

### 5.4 Telerehabilitation and Markerless Motion Capture Frameworks

| System | Year | Features |
|--------|------|---------|
| Consumer-grade camera telerehab (arXiv, 2311.13088) | 2023 | Markerless motion capture (MediaPipe/OpenPose), validated UL exercise tracking, open-source |
| JMIR VR Exergames iterative design | 2024 | VR exergames for stroke UL using iterative user-centered design |
| Serious Video Game post-stroke (MDPI *Appl Sci*, 2025) | 2025 | Kinect V2 alternative RGB camera; 4 games (Bird Dodge, Hit Catch, Burst, Veggie Pick) |

### 5.5 Mobile / Tablet-Based Rehabilitation Apps

| System | Platform | Hardware | Features |
|--------|----------|---------|---------|
| MoU-Rehab | Android tablet + smartphone | IMU sensors | 30 min/day; FMA-UE, Brunnstrom, MMT improvements vs. OT alone (Choi et al., *Restorative Neurology and Neuroscience*, 2016) |
| HandMATE | Android app + robotic glove | Hand exoskeleton + tablet | Home-based; positive chronic stroke patient feedback (PMC, 2021) |
| Mobile AR game (PMC, 2020) | iOS/Android | Phone camera | AR game for upper limb deficit; case study feasibility |
| Exoskeleton + gamified app (JMIR Rehab, 2019) | Android | Wearable exoskeleton + app | VR/AR/gamification systematic review; significant hand/arm function improvements |

**Flutter / Dart-based systems:** No peer-reviewed publications found using Flutter specifically for stroke rehabilitation game interfaces as of March 2026. Existing work uses Android (Java/Kotlin), Unity, or web-based frameworks. Flutter's cross-platform capability and Bluetooth Low Energy support make it architecturally well-suited for exoskeleton control applications (as in the URR App project), with game feedback delivered via embedded WebView or platform channels to a Unity/WebGL game layer.

---

## 6. Summary Table

| System | Type | Joints | Games | Adapts To | Key Evidence |
|--------|------|--------|-------|-----------|-------------|
| InMotion ARM | End-effector robot | Shoulder, elbow | Clock/reach, maze, pong | AAN impedance, manual difficulty | RATULS 2019 (Lancet); Krebs/Hogan >30 years RCTs |
| KINARM Exo | Exoskeleton | Shoulder, elbow | VGR, Ball on Bar, Object Hit | Target distance, speed, distractors | Scott lab assessments; assessment gold standard |
| Armeo Spring | Passive exo | Shoulder, elbow, wrist, grip | Balloons, Goalkeeper, Pirate, Meteors | Spring tension, workspace, target speed | REM-AVC 2020; Klamroth 2019 |
| Armeo Power | Motorized exo | Shoulder, elbow, wrist | Fishing, Wall, Abacus | 1D→3D exercise, assistance level | Stroke RCTs, MS, CP studies |
| Tyromotion Amadeo | Finger robot | All fingers | Piano, grip tasks, Bricks Breaker | Resistance, ROM threshold | Frontiers Neurorobotics 2023 (spasticity) |
| Tyromotion Diego | Suspension | Shoulder, elbow | Reaching, bilateral tasks | Assistance level, speed | Clinical case series |
| Tyromotion Pablo | Sensor biofeedback | Shoulder to finger | Paddle Boat, balance games | Sensor threshold, ROM | Commercial/clinical use |
| ReoGo | End-effector robot | Shoulder, elbow, 3D | Reach, trajectory, ADL tasks | 5-mode hierarchy | Guidali 2011; Lee 2023 meta-analysis |
| ReoGo-J | End-effector robot | Shoulder, elbow | 71 training items | IRT-based auto-optimization | Scientific Reports 2024 |
| YouGrabber | Sensor gloves | Full UL + fingers | 7 games (Airplane, Shopping…) | Speed, workspace, mirror mode | Laver 2017 pilot; Laver 2018 qualitative |
| RGS | Camera-based | Full UL | Target reaching, dual-task | Auto-DDA (~30 min adaptation) | Cameirão 2011 RCT; >1,500 patients |

---

## 7. References

### Systematic Reviews and Meta-Analyses
1. Mehrholz J, Pohl M, Platz T, Kugler J, Elsner B. Electromechanical and robot-assisted arm training for improving activities of daily living, arm function, and arm muscle strength after stroke. *Cochrane Database Syst Rev.* 2018;9:CD006876.
2. Mehrholz J, Pollock A, Pohl M, Kugler J, Elsner B. Systematic review with network meta-analysis of RCTs of robotic-assisted arm training for improving ADL and UL function after stroke. *J Neuroeng Rehabil.* 2020;17:83.
3. Cai Y, et al. Efficacy of robot-assisted training on rehabilitation of upper limb function in patients with stroke: systematic review and meta-analysis. *Arch Phys Med Rehabil.* 2023. doi:10.1016/j.apmr.2023.01.014
4. Lee WH, et al. Robotic arm use for upper limb rehabilitation after stroke: systematic review and meta-analysis. *Kaohsiung J Med Sci.* 2023. doi:10.1002/kjm2.12679
5. Chien WT, et al. Robot-assisted therapy for upper-limb rehabilitation in subacute stroke patients: systematic review and meta-analysis. *Brain Behav.* 2020. doi:10.1002/brb3.1742
6. Urra O, et al. (game-based VR meta-analysis). *Virtual Reality.* 2025. doi:10.1007/s10055-025-01155-8

### Landmark RCTs
7. Lo AC, Guarino PD, Richards LG, et al. Robot-assisted therapy for long-term upper-limb impairment after stroke. *N Engl J Med.* 2010;362(19):1772–1783.
8. Rodgers H, et al. (RATULS). Robot assisted training for the upper limb after stroke: a multicentre randomised controlled trial. *The Lancet.* 2019;394(10192):51–62.
9. Duret C, et al. (REM-AVC). Additional, mechanized upper limb self-rehabilitation in patients with subacute stroke. *Stroke.* 2020. doi:10.1161/STROKEAHA.120.032545
10. Cameirão MS, Bermúdez i Badia S, Duarte E, Verschure PFMJ. Virtual reality based rehabilitation speeds up functional recovery of the upper extremities after stroke: RCT in the acute phase using the RGS. *NeuroRehabilitation.* 2011;28:247–258.

### Device-Specific and Foundational Papers
11. Krebs HI, Hogan N, et al. Robot-aided neurorehabilitation. *IEEE Trans Rehabil Eng.* 1998;6(1):75–87.
12. Kwakkel G, Kollen BJ, Krebs HI. Effects of robot-assisted therapy on upper limb recovery after stroke: systematic review. *Neurorehabil Neural Repair.* 2008;22(2):111–121.
13. Guidali M, et al. Robot-aided therapy for upper limb paresis in patients with stroke-related lesions. *Eur J Phys Rehabil Med.* 2011.
14. Klamroth-Marganska V, et al. Influence of new technologies on post-stroke rehabilitation: comparison of Armeo Spring to the Kinect System. *Medicine (Kaunas).* 2019;55(4):98. PMC6524064.
15. Molteni F, et al. (ReoGo-J automatic optimization). Automatic setting optimization for robotic upper-extremity rehabilitation in patients with stroke using ReoGo-J. *Sci Rep.* 2024. doi:10.1038/s41598-024-74672-2
16. Barrett N, Swain I, Gatzidis C, Mecheraoui C. The use and effect of video game design theory in the creation of game-based systems for upper limb stroke rehabilitation. *J Rehabil Assist Technol Eng.* 2016. PMC6453078.

### Game Design and Dual-Task
17. Cameirao MS, et al. Neurorehabilitation using the VR-based RGS: methodology, design, psychometrics, usability and validation. *J Neuroeng Rehabil.* 2010;7:48.
18. Duffau H, et al. Dual task effects on speed and accuracy during cognitive and upper limb motor tasks in adults with stroke hemiparesis. *Front Hum Neurosci.* 2021;15:671541. PMC8250862.
19. Laver KE, et al. A mixed methods small pilot study: effects of upper limb training using a VR gaming system (YouGrabber) in people with chronic stroke. *Disabil Rehabil.* 2017.
20. Choi YH, Ku J, Lim H, Kim YH, Paik NJ. Mobile game-based VR rehabilitation program for upper limb dysfunction after ischemic stroke. *Restor Neurol Neurosci.* 2016;34(3).
21. Frontiers Neurorobotics (Tyromotion Amadeo spasticity). Spasticity evaluation with the Amadeo Tyromotion device in patients with hemispheric stroke. *Front Neurorobotics.* 2023.
22. Grosmaire AG, Pila O, Breuckmann P, Duret C. Robot-assisted therapy for upper limb paresis after stroke: use of robotic algorithms in advanced practice. *Neurorehabilitation.* 2022. doi:10.3233/NRE-220025

### Open-Source / Mobile Frameworks
23. ReHAb Playground. *Future Internet (MDPI).* 2025;17(11):522.
24. Developing a Serious Video Game to Engage the Upper Limb Post-Stroke Rehabilitation. *Appl Sci (MDPI).* 2025;15(15):8240.
25. Validation of consumer-grade camera-based human activity evaluation for UL exercises: automated telerehabilitation framework. *arXiv.* 2023. arXiv:2311.13088.
26. HandMATE: wearable robotic hand exoskeleton and integrated Android app for at-home stroke rehabilitation. *PMC.* 2021. PMC8485422.
27. Towards bilateral upper-limb rehabilitation after stroke using Kinect game. *IEEE EMBC.* 2018. doi:10.1109/EMBC.2018.8574861.

---

*This document was compiled for the URR App / upper-limb rehabilitation exoskeleton project. It focuses on game mechanics and design principles applicable to building rehabilitation games controlled via Bluetooth from a tablet. All citations are from peer-reviewed sources or manufacturer technical documentation.*
