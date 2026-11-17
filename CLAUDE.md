# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The SPLORR!! entry for **Jamference: AI Game Jam Hack 4** (https://itch.io/jam/jamference-ai-game-jam-hack-4), joined November 16, 2026. The repo (public, `playdeezgames/solarpunk-lucky-cat-of-splorr`) was created that day. The game is **Composters of SPLORR!!**: you run the street's compost bin, steer falling scraps so greens touch browns and rot into compost, and spend the compost to green a grey street. **`DESIGN.md` is the design and records the user's decisions; read it first and keep it current.** Numbers are Claude's placeholders; decisions marked (user) are not.

The vault at `/home/yermom/git/bok-of-splorr/splorr/` holds the standing rules (read its `Home.md` first), the jam note `Jams/Jamference AI Game Jam Hack 4.md` and this game's note `Games/Composters of SPLORR!!.md`. When a fact changes, update that note and its `Home.md` row too. `Gotchas.md` there has the wasm and Odin lessons.

## The jam's constraints

- **Theme Solarpunk** (optional, but rated and must be visible to a player). **Restriction, mandatory: Hidden Lucky Cat** (off the main path, a real benefit); the itch page must say the game hides a lucky cat (not where).
- **Submissions close November 20, 2026 08:00** (timezone not given; treated as UTC). Built in the jam week; own boilerplate and tooling are allowed, no older game's code.
- AI must do real work; the submission lists the AI tools and what each did, and the team. Rated on Fun, AI use, Polish, Theme.
- During rating only play-blocking bug fixes.

## Commands

Odin is at `/home/yermom/ODIN/odin` (put it on `PATH`).

```bash
tools/test.sh                  # native tests (one thread), wasm checks of both packages, then a real wasm build
tools/build.sh [--size]        # wasm build into build/web
tools/serve.sh                 # build and serve on http://localhost:${PORT:-8000}/
tools/pages.sh                 # tests, size build, copy into docs/ for GitHub Pages; never commits or pushes
./shippit.sh [--push]          # tests, size build, zip; butler push only with --push (only on the user's "ship")
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.<test_name>  # one test
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:PLAYTEST=true -o:speed -define:ODIN_TEST_NAMES=game.playtest_streets  # the bot plays whole streets in five styles (careful, relaxed, lazy, noturn, random; a few seconds) and prints time, soil, average heat, mulch, packets, turns, fill and idle time; PLAYTEST_SEEDS sets how many
tools/make_shots.sh            # assets/screenshots/01-heap 02-street 03-shed 04-end and assets/portal.png, rendered natively (never showing the cat)
python3 -I tools/make_cover.py # assets/cover.png (630x500) from a natively rendered frame
tools/dump.sh out.png [-define:DUMP_HOUSES=8 -define:DUMP_SHOP=true -define:DUMP_END=true -define:DUMP_CAT=true -define:DUMP_CRACKS=3]  # render a frame natively at 3x
```

The browser pane's launch config `composters-web` (port 8772, in the vault's `.claude/launch.json`) serves `build/web`; run `tools/build.sh` first.

## Architecture

Odin compiled to `js_wasm32`, a 384 by 216 software framebuffer of Sweetie-16 palette indices drawn to a canvas (no WebGL), per the vault's `Tech/Odin wasm recipe.md`. Real time: odin.js calls `step` with the frame's seconds; `game.tick` clamps dt to 0.25 s.

- `src/game/` is the pure rules package (no `core:os`, no `core:fmt`; its own splitmix64 RNG). Test files start with `#+build !js`. `game.odin`: tuning constants at the top, `heap[col][row]` (row 0 at the bottom, each column a gapless stack), the falling `piece` and the `queue`, `command`, `land` (spills when full), `turn` (bottom to top, clears slime, airs the column, uses a fork pip), and `tick` → delivery (`waiting`: a scrap arrives every `deliver_time`), `rot` (greens heat per brown touching; packed greens go slimy; a brown touching no green, and a green that is slimy or touches no brown, break down on their own over `BROWN_WEATHER`/`SLIME_WEATHER` so a heap can never lock up), `rot_cell` (a green and one brown become compost worth `soil_per_compost` times `warm_mult`; an egg box feeds two greens), `sink` (compost swaps down a row every `SINK_TIME`, never past a crisp packet), `empty_hatch` (bottom compost banks its `worth`; mulch is worth 0). Since November 17, 2026: scraps that break down on their own become **mulch** (no soil); the heap's **warmth** (0 to 1, x1 to x3 soil) rises `WARM_PER_ROT` a rot and loses `WARM_COOL` of itself a second, and slime, mulch and spills knock it down; `Sort` adds coffee grounds, egg boxes and citrus, and `Kind.Junk` is a crisp packet (`turn` on its column lifts it out; the wind takes it after `PACKET_WEATHER`), unlocked by houses bloomed (`UNLOCK_*`). `stats` is a global the playtest bot reads (not saved). `economy.odin` is soil (`bank_soil`, the Sieve's part-soil), the shop (`Shop`, `shop_command`, `buy`; row 0 the next house, then the `Upgrade`s, then Back), prices, and the boosts every rule reads (`fork_max`, `fork_refill`, `worm_boost`, `air_time`, `soil_per_compost`, `fall_speed`, `green_chance`). `lucky.odin` is the cat (`turned_corner` counts `corner_run`; `CAT_TURNS` in a row of `CAT_COL` sets `cat_found`, which doubles `soil_per_compost`), `finish_street` and `new_street` (bests and the sound setting stay). `save.odin` saves the whole `Game` as raw bytes behind a header, blanking the chat strings (they point into the build's data); bump `SAVE_VERSION` whenever `Game`'s layout changes, and `save_is_sane` checks every field before a load. `chat.odin` is the neighbours and their lines (chatter starts when the tutorial's guided steps are done). `tutorial.odin` is the tutorial: guided `Step`s on a first street (`init_game(..., guided = true)`, only from `web.odin`; tests and fresh streets skip them), each with a goal along the bottom (`GOALS`), scripted first scraps (`SCRIPT`), and `Tip` cards that pause the heap until OK, shown once each (`tut_show`) for the heap's heat, slime, a spill, each new scrap, and the shed's HOW TO PLAY. `render.odin` lays out the screen (bin, next scraps, the HEAT gauge, barrow, the eight-house street; `draw_house` with the GREY remap, cells with SLIME, MULCH and SOGGY; `draw_card` for tutorial cards). `screen.odin` and `font.odin` are boilerplate (framebuffer, DINOBYTE text).
- **Art** is drawn by Claude in the Anvil (world `composters.json` in `~/anvil-worlds/`, exported to `art/composters.json`; tileset `compost`, 16x16, Sweetie-16). After changing it, export again and run `python3 -I tools/gen_gfx.py`; the `Gfx` enum in `screen.odin` follows its `NAMES` list. Never hand-edit `gfx.odin` or `font.odin`. `dump_test.odin` renders a frame natively: `odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:DUMP_PLAY=/path/play.ppm -define:DUMP_HOUSES=8 -define:ODIN_TEST_NAMES=game.dump_play` (also `DUMP_CARD=<Tip>` and `DUMP_STEP=<Step>`).
- `src/web/web.odin` (`package main`, `#+build js`) is the browser layer, imported as `tggd:game`. `web/index.html` saves to localStorage (`composters-save`) and maps arrows/WASD, Space or Enter (OK), Esc, E or Backspace (Cancel: the shed), gamepad and touch pads to `platform_command` (the `Command` order must match) and plays `SOUNDS` (must follow the `Sound` enum order). F opens the LootLocker feedback form (`web/lootlocker.js`, the vault's kit; no LootLocker game set up).

## Standing rules (full text in the vault's `Home.md`)

- **"Push" means `git push`; "ship" means itch.io.** Neither unless the user says that word. The jam submission needs no Coxswain booking; publishing it still needs the user's yes.
- **GitHub Pages is live** since November 16, 2026 (the user's "Push and Pages") at https://playdeezgames.github.io/solarpunk-lucky-cat-of-splorr/, served from `main` `/docs`. To update it: `tools/pages.sh`, commit `docs/`, push (each push needs the user's go-ahead).
- itch.io embed: "Click to launch in fullscreen". Footer back links and the "Send feedback" link on the page.
- Public repo: no 1-Bit Kingdom art. Keep every licence record and credit.
- Anything an AI agent posts on itch.io says so.
- Do not describe or "fix" the user's decided design as a problem.
