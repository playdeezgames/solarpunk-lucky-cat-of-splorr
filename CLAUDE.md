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
```

The browser pane's launch config `composters-web` (port 8772, in the vault's `.claude/launch.json`) serves `build/web`; run `tools/build.sh` first.

## Architecture

Odin compiled to `js_wasm32`, a 384 by 216 software framebuffer of Sweetie-16 palette indices drawn to a canvas (no WebGL), per the vault's `Tech/Odin wasm recipe.md`. Real time: odin.js calls `step` with the frame's seconds; `game.tick` clamps dt to 0.25 s.

- `src/game/` is the pure rules package (no `core:os`, no `core:fmt`; its own splitmix64 RNG). Test files start with `#+build !js`. `game.odin`: tuning constants at the top, `heap[col][row]` (row 0 at the bottom, each column a gapless stack), the falling `piece` and the `queue`, `command`, `land` (spills when full), `turn` (bottom to top, clears slime, airs the column, uses a fork pip), and `tick` → `rot` (greens heat per brown touching; packed greens go slimy), `rot_cell` (a green and one brown become compost), `sink` (compost swaps down a row every `SINK_TIME`), `empty_hatch` (bottom compost becomes soil). `render.odin` lays out the screen; cells are drawn plainly until the Anvil art (step 2). `screen.odin` and `font.odin` are boilerplate (framebuffer, DINOBYTE text).
- `src/web/web.odin` (`package main`, `#+build js`) is the browser layer, imported as `tggd:game`. `web/index.html` maps arrows/WASD, Space (OK), Esc (Cancel), gamepad and touch pads to `platform_command` (the `Command` order must match) and plays `SOUNDS` (must follow the `Sound` enum order). F opens the LootLocker feedback form (`web/lootlocker.js`, the vault's kit; no LootLocker game set up).

## Standing rules (full text in the vault's `Home.md`)

- **"Push" means `git push`; "ship" means itch.io.** Neither unless the user says that word. The jam submission needs no Coxswain booking; publishing it still needs the user's yes.
- GitHub Pages is the default; enabling it is the user's call.
- itch.io embed: "Click to launch in fullscreen". Footer back links and the "Send feedback" link on the page.
- Public repo: no 1-Bit Kingdom art. Keep every licence record and credit.
- Anything an AI agent posts on itch.io says so.
- Do not describe or "fix" the user's decided design as a problem.
