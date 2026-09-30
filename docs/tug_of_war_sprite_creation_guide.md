# Tug of War — Sprite Creation Guide (AI image/animation generation)
**Written**: 2026-09-16
**Tools**: ChatGPT (image generation) + an animation AI tool (e.g. whichever of Tencent Hunyuan / Kling / Runway you have access to) + Photopea (free, background removal + frame compositing)
**Owner**: Human (prompting + background removal + resizing) + Claude (pubspec registration + code wiring)
**Reference**: same format as `sprite_creation_guide.md` (Shield Guard game); only the animation-sheet section is new (based on [irisogli.com's 2D game AI asset workflow](https://irisogli.com/create-an-entire-2d-game-with-ai-characters-assets-animation-and-parallax-free)).

---

## 0. This game doesn't need "real" parallax

The source tutorial is for a side-scrolling platformer, so it splits the background into several layers (far/mid/gameplay/foreground) that scroll at different speeds as the camera moves. **Tug of War has a fixed camera — it's a 1v1 face-off, nothing scrolls.** So instead of a 4-layer parallax rig, all we need is:

- **One static background image** (sky + canopy + mist + river), and
- The river ripples keep animating in code as a thin moving overlay on top, so it still reads as "alive."

In other words: skip the tutorial's "4 parallax layers" step entirely — **1 background image + 2 cliff images** is enough. Everything else (rope, knot, characters, particles) is its own separately animated sprite.

---

## 1. Sprite list

The bridge was removed on the clinician's instruction, so build guide §7's `bridge_platform.png` is not needed.

| # | Filename | Content | Size | Priority |
|---|--------|------|------|---------|
| 1 | `bg_jungle_canyon.png` | Sky + canopy + mist + river (static) | 1920×1080 | Required |
| 2 | `cliff_left.png` | Left cliff (jagged inner edge, grass + vines) | 900×1080 | Required |
| 3 | `cliff_right.png` | Right cliff (can just be a horizontal flip of the left one) | 900×1080 | Required |
| 4 | `player_pull_sheet.png` | Human pulling — 1×4 sheet | 1024×512 | Required |
| 5 | `animal_chimp_sheet.png` | Chimpanzee pulling — 1×4 sheet | 1024×512 | Required |
| 6 | `animal_orang_sheet.png` | Orangutan pulling — 1×4 sheet | 1024×512 | Required |
| 7 | `animal_gorilla_sheet.png` | Gorilla pulling — 1×4 sheet | 1024×512 | Required |
| 8 | `rope_knot.png` | Centre knot (rope bundle + pennant flag) | 256×256 | Optional (already looks fine procedurally) |
| 9 | `dust_cloud.png` | Foot-slip dust puff | 128×128 | Optional |
| 10 | `splash_water.png` | Landing splash | 256×256 | Optional |
| 11 | `confetti.png` | Victory confetti piece | 64×64 | Optional |

> **Minimum for a demo**: items 1–7 (background + 2 cliffs + the 4 character sheets) already transform the look. 8–11 can wait — the current procedural versions read fine.

---

## 2. Overall process (the article's method, scaled down for this project)

```
Static images (background, cliffs, knot, particles)
  ① Paste the prompt below into ChatGPT
  ② If it's not right, regenerate or tweak the prompt wording (3–5 tries is normal)
  ③ In Photopea: remove the background + resize to the target dimensions
  ④ Save into assets/images/tug_of_war/

Animation sheets (human + 3 animals)
  ① First lock in the character's still design in ChatGPT — side profile, rope-gripping pose
  ② Feed that locked-in design image to an animation AI tool and ask for a
     "repeating pull motion" loop video (request a chroma-key green background,
     #00FF00 — it makes background removal much easier)
  ③ Extract 4 evenly-spaced frames from the resulting video
     (screenshot while scrubbing, or use a free video editor's "export frame" feature)
  ④ In Photopea, composite the 4 frames side by side into one 1024×512 canvas
  ⑤ Select the chroma-key green (#00FF00) with the magic wand, delete it, export as
     a transparent PNG
  ⑥ Save into assets/images/tug_of_war/
```

### Background-removal tools

| Tool | Method |
|------|------|
| **Photopea** (free, browser) | Magic wand on the green/solid background → Delete → export PNG |
| **remove.bg** | Upload, auto transparent background (free tier is lower-res) |
| **ChatGPT itself** | State "transparent background" in the prompt (fine for simple static props) |

---

## 3. Shared style prefix (put this in front of every prompt)

Reusing the style already agreed on in the build guide (§8):

```
cartoon cel-shaded, bold black outlines, vibrant colors,
jungle adventure style, mobile game asset
```

---

## 4. Per-sprite ChatGPT prompts (paste as-is)

### ① Background — `bg_jungle_canyon.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, jungle adventure
style, mobile game asset.
A dramatic jungle canyon scene, two cliff edges facing each other across a
deep gorge with NO bridge connecting them, a river with visible ripples
running along the bottom of the gorge, misty distant jungle canopy in the
background, lush tropical vegetation, wide 16:9 aspect ratio, flat game
background art, no characters.
```

### ② Left cliff — `cliff_left.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, jungle adventure
style, mobile game asset.
A single jungle cliff platform seen from the side, jagged rocky inner edge
facing right toward a chasm, grassy flat top with a few blades of grass and
one hanging vine down the cliff face, transparent background, tall
portrait crop, no characters, no bridge.
```

### ③ Right cliff — `cliff_right.png`
```
Same style and cliff as above, mirrored so the jagged rocky edge faces
LEFT toward the chasm instead of right. transparent background, no
characters, no bridge.
```
> If this doesn't come out right, just flip ② horizontally instead (Photopea: Image → Flip Horizontal).

### ④ Human (player) design — still image to lock in before `player_pull_sheet.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, mobile game asset.
A determined young adult in a blue short-sleeve shirt and dark pants,
bracing stance seen from a fixed side profile, both arms reaching forward
gripping an invisible rope, back leg extended for leverage, front leg bent,
solid chroma key green background only (#00FF00 style green screen),
full body, no shadows on the ground.
```
→ Once you like this design, feed it to the animation tool and ask for "a 4-frame loop of this character repeating a pulling motion, fixed side profile, keep the green background."

### ⑤ Chimpanzee — `animal_chimp_sheet.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, mobile game asset.
A small, hunched cartoon chimpanzee, dark brown-black fur, large round
ears, long arms reaching forward gripping an invisible rope, crouched
low stance, fixed side profile view facing left, solid chroma key green
background only (#00FF00), full body, expressive face.
```

### ⑥ Orangutan — `animal_orang_sheet.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, mobile game asset.
A round, shaggy cartoon orangutan with reddish-brown fur, wide cheek
flanges on the face, very long arms reaching forward gripping an
invisible rope, heavy round belly, short bent legs, fixed side profile
view facing left, solid chroma key green background only (#00FF00),
full body.
```

### ⑦ Gorilla — `animal_gorilla_sheet.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, mobile game asset.
A massive muscular cartoon gorilla, black fur with a silver-gray patch on
its back, broad shoulders, small head with a crested skull between the
shoulders, thick arms reaching forward gripping an invisible rope, short
thick legs, intimidating but cartoon-cute, fixed side profile view facing
left, solid chroma key green background only (#00FF00), full body.
```

### ⑧ Centre knot / flag (optional) — `rope_knot.png`
```
cartoon cel-shaded, bold black outlines, vibrant colors, mobile game asset.
A round bundle of thick woven rope with two strands crossing over it,
a short wooden flagpole sticking up from the top with a small red
triangular pennant flag, transparent background, square format 1:1,
no characters.
```

### ⑨ Dust (optional) — `dust_cloud.png`
```
cartoon cel-shaded, bold black outlines, mobile game asset.
A small puff of brown dust cloud, soft rounded edges, transparent
background, square format 1:1, particle effect sprite.
```

### ⑩ Splash (optional) — `splash_water.png`
```
A cartoon water splash explosion, bright blue and white, solid black
background, square format 1:1, particle effect sprite for screen-blend use.
```

### ⑪ Confetti (optional) — `confetti.png`
```
A single small rectangular piece of colorful confetti, bright color,
transparent background, tiny square format 1:1, particle sprite.
```

---

## 5. How to make the animation sheets (new — the core of the source article)

The 4 characters (human + 3 animals) need a **1×4 repeating-pull-motion sheet**, not a still:

```
1) First lock in the "still" design using prompts ④–⑦ above (regenerate until you like it).
2) Upload the locked-in image to an animation AI tool (Tencent Hunyuan / Kling / Runway,
   whichever you have access to) and ask: "Make this character repeat a rope-pulling
   motion in a fixed side profile, 2-3 second loop, keep the green background."
3) Capture 4 evenly-spaced frames representing one full motion cycle from the resulting
   video (screenshots while scrubbing, or a free video editor's "export frame" feature).
4) Open a new 1024×512 canvas in Photopea and paste the 4 frames side by side,
   256px apart.
5) Magic-wand-select the chroma-key green (#00FF00), delete it, and export as a
   transparent PNG.
```

It's normal for the loop to not look great on the first try — keep attaching the locked-in still design image and repeating "this character, only the pulling motion" so the style doesn't drift between attempts.

---

## 6. Resizing

| Item | Target size | Easy method |
|------|---------|------------|
| Background | 1920×1080 | Photopea → Image → Image Size |
| Cliffs | 900×1080 | same as above |
| Character sheets | 1024×512 (256×512 per frame) | space the 4 frames exactly 256px apart |
| Knot / particles | 128–256 square | same as above |

> Doesn't need to be exact — the code fits images with `drawImageRect`, so ±50px is fine.

---

## 7. Save location

```
assets/images/tug_of_war/
  ├── bg_jungle_canyon.png
  ├── cliff_left.png
  ├── cliff_right.png
  ├── player_pull_sheet.png
  ├── animal_chimp_sheet.png
  ├── animal_orang_sheet.png
  ├── animal_gorilla_sheet.png
  ├── rope_knot.png        (optional)
  ├── dust_cloud.png       (optional)
  ├── splash_water.png     (optional)
  └── confetti.png         (optional)
```

Once saved, tell Claude the assets are ready — pubspec registration through the `onLoad()`/`render()` swap will be handled from there.

---

## 8. Division of labor

| Task | Owner |
|------|------|
| Entering ChatGPT prompts + generating images/video | **Human** |
| Extracting 4 frames from the animation video + compositing the sheet | **Human** |
| Background (chroma-key) removal, resizing, saving to folder | **Human** |
| `pubspec.yaml` registration | Claude |
| `onLoad()` sprite-loading code | Claude |
| Swapping `render()` procedural drawing for sprites | Claude |
| Frame-switching logic timed to the pull cycle | Claude |

---

## 9. Detached arm/hand rig (2-joint IK) — replaces the 4-pose sheets

**Why**: the 4-pose sheet approach (player/champ/gor/or 1–4.png) bakes the arm into the same
flat image as the body, at a fixed angle per pose. No matter how precisely the grip point is
measured (see §5's frame-by-frame PIL marking), the rope can only ever touch that one fixed
point in that one fixed pose — it visibly detaches the moment the character leans, trembles,
or falls, because the body is leaning/rotating but the baked-in arm angle isn't. A **detached
arm** fixes this at the root: the shoulder and elbow become two independently rotatable joints
that the game code drives every frame (a real 2-bone forward-kinematics chain), so the hand
position is *computed*, not measured off a photo — it can be aimed exactly at the rope's true
anchor point at all times, at any lean angle, with no per-pose guesswork.

This replaces the 4 "effort" pose frames per character with **3 static pieces** per character
(body, upper arm, forearm+hand) — 12 files total instead of 16, and no animation-video step
needed for these (§5's video-loop workflow is no longer needed for arms; keep it only if you
still want a body idle-sway loop, which is optional).

### 9.1 Required pieces (per character: player, champ, gor, or)

| File | Content | Notes |
|------|---------|------|
| `<name>_body.png` | Torso + head + legs, tug-of-war bracing stance, **no arm at all** | Shoulder shown as a rounded stub/socket (like a sleeve or shoulder fur) so the upper-arm piece overlaps it cleanly |
| `<name>_upperarm.png` | Shoulder-to-elbow segment only, in a straight neutral rest pose | Shoulder pivot at the **top-center edge** of the canvas |
| `<name>_forearm.png` | Elbow-to-fist segment, ending in a hand gripping an (invisible/implied) rope | Elbow pivot at the **top-center edge** of the canvas |

### 9.2 Shared style prefix (put this in front of every prompt)

```
2D mobile game character illustration, clean smooth vector-style outlines (not thick comic
ink), soft cel shading, vibrant natural colors, semi-realistic cartoon proportions — matching
the style of an existing tug-of-war game character sprite (bracing/leaning stance, gripping a
rope with both hands).
```

### 9.3 Pivot convention (critical — repeat this in every arm/forearm prompt)

```
The limb must be drawn perfectly straight, pointing straight down from the top edge of the
canvas like a plumb line. Its pivot joint (the shoulder for the upper arm, the elbow for the
forearm) must sit exactly at the top-center of the canvas, touching or almost touching the top
edge — not in the middle of the image. Transparent background. No perspective foreshortening,
even/flat lighting along the limb's length (it will be rotated by software afterward, so
directional shading baked in one direction will look wrong at other angles).
```

AI image generators won't hit this pixel-perfect — treat it as a strong bias, not a guarantee.
After generating, use the same technique as §"how these hand-fractions were measured" earlier
in this doc (a quick Python/PIL script drawing a crosshair at a candidate pivot point, viewed
and adjusted until it lines up) to find the *actual* pivot pixel in the delivered image, then
tell Claude that pixel offset — the rendering code needs it to rotate around the right point.

### 9.4 Per-character prompts

**Player (human) body** — `player_body.png`
```
[style prefix]
A determined young adult woman, ponytail, blue short-sleeve shirt and dark green pants,
bracing tug-of-war stance seen from a fixed side profile facing right, back leg extended for
leverage, front leg bent, shoulders squared toward the right with two short rounded shoulder
stubs where the arms attach — no arms or hands drawn, torso and head only otherwise complete,
transparent background, no shadow on the ground.
```

**Player arm** — `player_upperarm.png` / `player_forearm.png`
```
[style prefix] [pivot convention]
A single human arm segment matching the player character's skin tone and blue sleeve (for the
upper arm) / bare forearm (for the forearm), toned but not overly muscular.
```
For the forearm specifically, add:
```
The lower end (opposite the elbow pivot) ends in a clenched fist as if gripping a thick rope —
fingers wrapped around a rope-width gap, thumb over the top, angled so the grip reads correctly
when the whole limb is rotated to any angle.
```

**Chimpanzee body** — `champ_body.png`
```
[style prefix]
A small, hunched cartoon chimpanzee, dark brown-black fur, large round ears, crouched low
tug-of-war stance facing right, two short rounded shoulder stubs where the long arms attach —
no arms or hands drawn, transparent background, expressive face.
```

**Chimpanzee arm** — `champ_upperarm.png` / `champ_forearm.png`
```
[style prefix] [pivot convention]
A single long chimpanzee arm segment, dark brown-black fur, matching the chimpanzee body's fur
texture and tone.
```
Forearm gets the same rope-gripping-fist addition as above, in fur-covered chimp-hand form.

**Orangutan body** — `or_body.png`
```
[style prefix]
A round, shaggy cartoon orangutan, reddish-brown fur, wide cheek flanges, heavy round belly,
short bent legs, tug-of-war stance facing right, two short rounded shoulder stubs where the
very long arms attach — no arms or hands drawn, transparent background.
```

**Orangutan arm** — `or_upperarm.png` / `or_forearm.png`
```
[style prefix] [pivot convention]
A single very long orangutan arm segment, reddish-brown shaggy fur, matching the orangutan
body's fur texture and tone.
```
Forearm gets the rope-gripping-fist addition, fur-covered orangutan hand.

**Gorilla body** — `gor_body.png`
```
[style prefix]
A massive muscular cartoon gorilla, black fur with a silver-gray patch on its back, broad
shoulders, small crested head, short thick legs, intimidating but cartoon-cute, tug-of-war
stance facing right, two short rounded shoulder stubs where the thick arms attach — no arms or
hands drawn, transparent background.
```

**Gorilla arm** — `gor_upperarm.png` / `gor_forearm.png`
```
[style prefix] [pivot convention]
A single thick gorilla arm segment, black fur, matching the gorilla body's fur texture and
tone.
```
Forearm gets the rope-gripping-fist addition, fur-covered gorilla fist.

### 9.5 After generating

1. Background-remove + save each piece into `assets/tugofwar/` using the exact filenames above.
2. Tell Claude the pieces are ready. Claude will: measure each piece's true pivot pixel (§9.3),
   rewire `_drawFighter`/`_paintPlayer`/`_paintAnimal` to draw body + a 2-joint rotated arm
   instead of a single flat sprite, and drive the shoulder/elbow angles from `effort`/`heave`
   (and, going forward, could even solve the angles via inverse kinematics so the hand always
   lands exactly on the rope, however it sags).
3. The old `player/champ/gor/or 1~4.png` 4-pose sheets can stay in the folder unused, or be
   deleted once the arm rig is confirmed working — Claude's loader will simply stop requesting
   them.
