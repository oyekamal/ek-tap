# Orbit Sling art (2026-09-29)
Generated with Gemini gemini-3-pro-image via gen.py (key: personal-agent-v2/.env GEMINI_API_KEY). fal account was TOP_UP-locked.
- sprites/        raw keyed cutouts (edge flood-fill of flat grey #808080), 16 sprites + bg_space_v3/v5
- sprites_game5/  BEST polished set (drop shadow, hue rim, uniform outline, specular+core shadow). sprites_game6 = same + crisper Puff edge.
- mock5.py/mock6.py build mock scenes; gauntlet/ has pairs + keys. r5 background (bg_space_v5) beat r6 (far planets = clutter).
- Gauntlet vs Cute & Tiny Space screenshots (bar/): 6 blind rounds, wins 0,0,1,1,1,0 of 3. NOT passed. Residual gaps = bespoke UI/lettering + one shared rim/light pass.
Known: planet anchor must be core centre; ringo needed global grey key; mochi_moon now round (not oval); cloud_nine has a face.

## Resume (when we build the game)
1. Wire `sprites_game5/*.png` into `games/orbit_sling.gd`: planet sprites anchor on the planet CORE centre (r=46 -> 92px), Puff ~56px replaces the 12px stone; rotate Puff toward velocity when flying.
2. Squash/stretch/spin-up/regrow/trail/glows/orbit rings are done in CODE, not sprites. States -> poses: orbit=neutral, hold=squash, release=stretch, flying=fly, chain=happy, near-miss=scared, lost=bald.
3. Background: use `sprites/bg_space_v5.png` (clean). Do NOT add distant-planet clutter (round 6 lost).
4. UI (score pill, buttons, lettering) is NOT an asset here — build it with the game; it was the biggest remaining gap vs the shipped bar.
5. Regenerate any sprite: `python3 gen.py NAME "prompt" [ref.png]` (needs GEMINI_API_KEY in personal-agent-v2/.env; style in STYLE_PROMPT.txt). Always pass raw/planet_ringo.png or raw/puff_neutral.png as the style anchor.
6. Playtest before more art rounds. Reference bar: Cute & Tiny Space (App Store screenshots, not included — third-party).
