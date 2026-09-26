# Ek Tap — Keyword Research

Prepared: 2026-09-26. All volume/competition reads below are **qualitative inference** from live search-result density and phrase repetition (via `ddg.py` and Play listing pages found through it) — there is no real Play Console / paid keyword-tool volume data behind any of this. Treat every "high/medium/low" as an informed guess, not a measurement.

---

## 1. Real competitors found (Google Play, one-tap / minigame-collection niche)

| App | Package | Title pattern / keyword signal |
|---|---|---|
| **One Tap** (Andrzej658) | `com.andrzej658.one_tap` | Literal exact-match title on the core keyword phrase; plain description ("test your reflexes in a dynamic one-touch arcade game") |
| **Single Tap Games** | `com.foxxymobile.singletapgames` (Wear OS) | Adds plural "Games" to the core phrase — targets the bundle/category term directly |
| **Button.** | `com.C74Games.com.unity.button` | Single evocative word, no genre word in title; relies on screenshots/description for discovery |
| **One More Button** | `com.tommysoereide.onemorebutton` | Sequel-style naming, keeps "Button" as the anchor keyword |
| **ONE BTN BOSSES** | `com.MidnightMunchies.OneBtnBosses` | Abbreviates "button" → "BTN", adds a unique differentiator word ("Bosses") while keeping the root keyword |
| **Helix Stack Jump: Smash Ball** (MWM/Ketchapp-lineage) | `com.hiroba.helix` | Title = [brand hook] + colon + [genre words]; markets "easy one-tap controls" in the *description*, not the title |
| **Mini-Games: New Arcade** | (tracked via ASOTools keyword monitoring) | Title = [category noun] + colon + [descriptor]; confirmed via ASOTools to target "mini games", "mini game", "free game app" as core terms |

**Pakistani-made one-tap competitors:** none found. Top Pakistan-market casual games surfaced (Yalla Ludo, Happy Chicken Claw, Frost Valley) are all large studios in unrelated genres, not indie one-tap games. **This is a genuine gap, not a validated-demand signal** — no evidence anyone is searching for it yet, but also nobody is contesting the "desi/Pakistani one-tap game" positioning.

**Naming-convention takeaway:** there's a real, Play-recognized sub-genre clustering around the literal words "one tap" / "one button" / "button" / "BTN" — Ek Tap's title should sit inside that cluster (as recommended in `listing.md` §1) rather than inventing unrelated branding.

---

## 2. Keyword candidates

| Keyword | Volume / competition (inferred) | Reasoning |
|---|---|---|
| mini games | High / very high | ASOTools runs dedicated competitor tracking on this exact term — broad, contested |
| tap games | High / high | Broad genre term, many hits |
| one tap game | Medium / medium | Literal-match competitors exist (One Tap, Single Tap Games) — contested but narrower |
| one button game(s) | Medium / medium-high | Whole naming sub-genre targets this (Button., One More Button, ONE BTN BOSSES) |
| arcade mini games | Medium / high | Generic arcade-bundle phrasing, many bundle apps use it |
| casual games offline | Medium / high | Broad, generic, heavily used across unrelated apps |
| reflex game | Medium / medium | Real dedicated apps compete here (Reflaxy, TimerBattle, "Reaction training") |
| reaction time game | Medium / medium | Same cluster as above, more App Store-side presence than Play |
| offline games no wifi | Medium / low-medium | Strong explicit query pattern observed ("Top 10 INSANE Offline Games (No WiFi)" style content) |
| stack/helix-style one tap | Medium / high | Ketchapp lineage dominates this; use only as a description reference point, not a title keyword — too contested to own |
| simple games one touch | Low-medium / low | Long-tail phrasing, little direct competition found |
| kids games easy controls | Low-medium / low-medium | Adjacent-audience angle; plausible parent-search intent, unverified |
| hold and release game | Low / low | Matches Ek Tap's actual input verb; underused as a keyword — good long-tail fit |
| 12 mini games in one | Low / low | Bundle-count long-tail; real precedent for bundles marketing by game count |
| no ads offline arcade | Low-medium / low-medium | Plausible, unverified — worth testing, not a strong bet |
| brain-free games | Low / low | No literal competitor found under this exact phrase — open but unproven |
| desi games | Low / low | No direct competing listing found — open long-tail, no validated demand either |
| Pakistani games app | Low / low | No small indie competitor found — genuine gap, no validated demand |
| kite flying game | Low / low | No direct Play competitor surfaced for kite-cutting specifically |
| kabaddi game | Low-medium / low-medium | Kabaddi *sports* games exist as a broader adjacent category (not directly searched in this pass) |
| chai/tea game | Very low / very low | Essentially unclaimed novelty long-tail |
| bazaar/haggling game | Very low / very low | Unclaimed |

**Read on the South-Asian-flavour keywords (desi, Pakistani, kite, kabaddi, chai, bazaar):** these are differentiation copy for the description and screenshots, not proven search-volume bets. No autocomplete/related-search evidence surfaced for any of them — don't lean on them as the primary discovery strategy; lean on "one tap" / "one button" / "mini games" / "offline no wifi" for discovery, and use the desi terms to convert once a user is already looking at the listing.

---

## 3. Autocomplete / related-search signals observed

- "one tap games" surfaced a real, near-identical-named competitor cluster (One Tap, Single Tap Games) — the exact phrase is already contested at the title level.
- "one button games" surfaced a recognizable sub-genre naming convention (literal "Button"/"BTN" root words) spanning several small indie developers — Play's own discovery/recommendation systems appear to group these together.
- "minigame collection android 12 games" surfaced bundle-count framing as a real, working pattern (bundles like "2-3-4 Player Mini Games" ~30 games, "Offline Games" ~1000+ games market themselves by count) — supports using "12" explicitly in title/short description.
- "no wifi" / "offline" is a recurring explicit user-query pattern (e.g. YouTube content titled "No WiFi, No Problem", "Top 10 INSANE Offline Games (No WiFi)") — worth using verbatim ("no wifi needed") in the short description, not just "offline" alone.
- No autocomplete/related-search evidence at all for Pakistani/desi/kite/kabaddi/chai/bazaar terms — unclaimed, but also unvalidated. Treat as a bet on being first, not a bet backed by observed demand.

---

## 4. Keyword placement recommendation (maps to `listing.md`)

- **Title:** `one-tap`, `games`, `12` (bundle count) — the three highest-confidence terms.
- **Short description:** `one-tap games`, `hold, release, tap` (long-tail, low competition), `offline`, `no wifi needed`.
- **Full description:** natural repetition of `one tap` / `one-tap`, `offline`, `mini game(s)`, plus one paragraph each surfacing `reflex game`, `reaction-time game`, `arcade`, `casual`, `easy controls` — categories with real but not overwhelming competition — without stuffing.
- **Screenshots/feature graphic:** carry the desi-flavour differentiation (kite, dhaba, kabaddi, bazaar) visually, since it has no keyword backing yet but is a genuine visual hook once a user is already on the listing page.

---

## Sources

- Live competitor listings and package names surfaced via `ddg.py` search snippets against play.google.com (One Tap, Single Tap Games, Button., One More Button, ONE BTN BOSSES, Helix Stack Jump, Mini-Games: New Arcade / ASOTools tracking page).
- Pakistan casual-games market context: Similarweb/Appfigures top-Pakistan-casual coverage of Yalla Ludo, Happy Chicken Claw, Frost Valley (large-studio titles, not indie one-tap competitors).
- No paid keyword-volume tool (Sensor Tower, data.ai, AppTweak) was used or available — all reads above are qualitative, from result density and phrase repetition only.
