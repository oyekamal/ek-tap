# Orbit Sling — Art Style (v2, after 3 harsh critics)

Game: one-button orbit/sling (games/orbit_sling.gd, bg #14122B, planet core r=46 -> 92px, orbit r=100, capture r=92).
Hero: **Puff** — a dandelion-seed-head creature. White fluff ball with a spiky-soft halo silhouette, tiny body/feet.
Signature gag tied to the mechanic: HOLD = spins up like a fan, shedding seeds; RELEASE = sheds half its fluff and
stretches into a dart; MISS = lands bald and sheepish, fluff regrows in ~1s. (Squash/stretch/spin/regrow are done in
CODE; sprites are only the states below.)

## Style sentence (in every prompt)
Hand-painted kawaii game sprite, soft dark-indigo outline on hero/planets/pickups only, 3-tone shading
(light / base / cool-lilac core shadow — never grey), one light from top-left, soft rim light bottom-right,
rounded shapes, saturated pastel, no texture noise, no text, no ground shadow, one object centred, 15% padding.

## Palette (closed family; accents retinted into it)
indigo #2B2A5C (outline) · cloud #FFF8F0 · blush #FFB3A7 · mint #8FE3CF · butter #FFE08A · lilac #B9A2F0
gameplay accents (retinted, saturated versions of the same hues): coral #FF7A8C, aqua #5FD0F5, sun #FFD23F.
Outline on dark bg: sprites also get a 2px light rim (#E8E4FF, 60%) baked in, or a glow in code — indigo-on-#14122B disappears.

## Puff spec
Big eyes (~25% of head) with two-part catchlight, one signature tuft on top, halo of seed-fluff, stub feet.
Must read at 48px on #14122B. In-game display size 56px (stone is r=12 today — Puff replaces it, drawn at ~56px,
orbit sprite rotates toward velocity when flying).

## Keying (decided, test first)
White hero is NOT generated on magenta (fringe). Generate on flat mid-grey #808080, cut with `pixelcut/background-removal`
(sync_mode false). Non-white items may use flat chroma green #00FF00 as fallback. NO translucent/glow sprites — do
glows, jelly translucency and rings in code. Anchor = planet CORE-circle centre (not bbox centre) after trim.

## Rules
Re-attach the anchor image on EVERY edit (drift after ~5). Planet colour is baked; the per-chain PALETTE tint is
dropped for sprite planets (planet identity = its own colour/silhouette). Sizes: planets 256px, Puff 256px,
pickups 128px, bg 1080x1920.
