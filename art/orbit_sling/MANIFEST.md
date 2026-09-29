# Orbit Sling — Sprite Manifest (v2) — 20 sprites + 2 bg

## GO/NO-GO GATE (generate these 3 first, ship stubs into orbit_sling.gd at real size on #14122B)
1 puff_neutral  2 planet_mochi_moon  3 planet_cactus_pal  (+ puff_squash edited from puff_neutral)
Go only if: Puff reads at 48px · r46 overlay centred within 2px after trim · no fringe · cactus_pal silhouette clearly
differs from mochi_moon · puff_neutral vs puff_squash drift <= 2px / same outline width. Else fix STYLE, don't batch.

## Puff (7, essential only): puff_neutral, puff_squash, puff_stretch, puff_fly, puff_happy, puff_scared, puff_bald(miss/dizzy)
Idle breathing = code tween. Land/squash/trail/spin/regrow = code. No wink, no fluff-particle sprite (Godot particle of a tiny seed).

## Planets (6 + 1 decoy, DIFFERENT silhouettes + gameplay role; rest deferred until game supports roles)
mochi_moon  fat oval, sleepy, big forgiving capture · cactus_pal  spiky+flower hat (hazard variant) ·
ringo  ringed planet (ring = capture ring) · frosty_pop  tall narrow ice-lolly · boba_bubble  cup+straw (bobbing target) ·
berry_bloom  bud, opens on capture · cloud_nine  faceless decoy puff
(each: idle face baked; 'caught you' face done in code or 2nd sprite only for mochi_moon + ringo)

## Gameplay (3): star, orbit_ring_soft (r=100 art, optional; code arc is fallback), target_glow -> CODE, so only: star, golden_seed, next_arrow_hint
## Background (2, static, no parallax — game has no world clock): bg_space_1080x1920 (nebula rim-lit, warm magenta + teal secondary
light), bg_stars_layer (tileable-none, overlay)
## UI: none as sprites (Godot Labels/icons). Cut: black_hole, angry_asteroid, magnet_bubble, trail_comet, crown, counters, confetti.

Budget: ~23 gens + ~8 retries + 20 cutouts. Verify live fal price before run (nano-banana-pro est. ~$0.15/img -> ~$5).
