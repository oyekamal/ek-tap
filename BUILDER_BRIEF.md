# Ek Tap builder brief

You are building one or more mini-games for **Ek Tap**, a Godot 4.7 Android app of 12 one-button games.
Project: `~/Documents/free_work/godot-games/ek-tap/`.

## Read first
1. `core/mini_game.gd` — the base class. Every game `extends MiniGame`. Read the whole file; use its helpers
   (`add_score`, `lose_life`, `end_run`, `shake`, `hitstop`, `popup`, `burst`, `text_c`, `set_xform`, `rng`, `time`, `W`, `H`).
2. `games/almost_pop.gd` — the reference game. Copy its structure: settings in `_init()`, reset in `_setup()`,
   logic in `_tick(dt)`, drawing in `_draw_game()`, input in `_on_press()` / `_on_release()`, autoplay in `_bot(dt)`.
3. `core/sfx.gd` — sounds: `Sfx.tone(freq, dur, wave, vol, slide_to)`, `Sfx.chord([...])`, `Sfx.loop_start/loop_pitch/loop_stop`.
4. `/home/oye/Documents/free_work/personal-agent-v2/.claude/skills/game-retention-design/SKILL.md` — the quality bar (Gate 1 especially).

## Rules
- One file per game: `games/<game_id>.gd`. Do NOT edit core/, main.gd, project.godot or other games' files.
- Only code-drawn shapes (`draw_rect`, `draw_circle`, `draw_colored_polygon`, `draw_line`, `draw_arc`, `draw_polyline`, `text_c`). No image assets, no scenes.
- Portrait, resolution-independent: size everything from `W` and `H` (base is 720x1280 but aspect varies).
- Inside `_draw_game()` use `set_xform(...)` instead of `draw_set_transform` (keeps screen shake).
- The HUD (score, best, lives, back button, game-over card) is automatic. Keep the top ~200 px free of important play.
- Godot 4 syntax only: `@onready`, `await`, typed vars. Integer division warnings: use `int()`/`float()` explicitly. Avoid `:=` when the right side is Variant (e.g. dictionary lookups) — declare the type.
- Tunables as `const` at the top with a short comment.
- Game feel (from the skill): input feedback < 100 ms, readable failure in ~1 s (freeze + highlight the cause), hit-stop 60–120 ms on fails, shake on impacts, rising-pitch sound cues, instant next round, no text needed to understand play.
- `_bot(dt)` must lift the finger (`_release()`) whenever a round ends while it is holding, or it deadlocks (`_press()` is ignored while `holding`).
- `_bot(dt)` must play plausibly (sometimes well, sometimes failing) so headless capture shows real play and eventually a game over.

## Verify (required before you report done)
```bash
cd ~/Documents/free_work/godot-games/ek-tap
godot --headless --path . --quit-after 300 -- --game-path=res://games/<game_id>.gd --autoplay 2>&1 | grep -E 'ERROR|WARNING|SCRIPT' | grep -vE 'leaked at exit|still in use at exit'
```
must print nothing. Do NOT run `--import`; the project is already imported. Use `--fixed-fps 30` for runs that must reach a game over (headless runs faster than real time):
```bash
godot --headless --path . --fixed-fps 30 --quit-after 3000 -- --game-path=res://games/<game_id>.gd --autoplay 2>&1 | grep -E 'ERROR|SCRIPT'
```

Capture frames and LOOK at them:
```bash
O=/tmp/ektap-cap/<game_id>; rm -rf $O; mkdir -p $O
DISPLAY=:1 timeout 90 godot --path . --resolution 405x720 --write-movie $O/f.png --fixed-fps 30 --quit-after 600 -- --game-path=res://games/<game_id>.gd --autoplay >/dev/null 2>&1
python3 -c "
from PIL import Image
fs=['$O/f%08d.png'%i for i in (30,100,180,260,380,560)]
ims=[Image.open(f) for f in fs]; w,h=ims[0].size
s=Image.new('RGB',(w*3,h*2))
[s.paste(im,((i%3)*w,(i//3)*h)) for i,im in enumerate(ims)]
s.save('$O/sheet.png')"
```
Then Read `$O/sheet.png`. Fix anything that looks broken, clipped, unreadable or ugly, and re-capture once.

Report: file path, 3-second pitch, what the bot showed, anything you're unsure about. Max 150 words.
