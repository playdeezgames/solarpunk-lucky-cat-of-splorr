# Composters of SPLORR!! — design

The SPLORR!! entry for **Jamference: AI Game Jam Hack 4** (https://itch.io/jam/jamference-ai-game-jam-hack-4). Theme **Solarpunk** (optional, rated); mandatory restriction **Hidden Lucky Cat** (findable, off the main path, a real benefit). Submissions close **November 20, 2026 08:00** (timezone not given on the page; treated as UTC).

Decisions marked **(user)** are the user's (November 16, 2026) and are not to be changed without asking. Everything else, especially every number, is Claude's placeholder, to be tuned by playtesting.

## The game in one line

You run the street's compost bin: steer the neighbours' scraps into the heap, keep greens touching browns so they rot into compost, and spend the compost to turn a grey street into a solarpunk one.

## Decided by the user

- **Run length: 20 to 30 minutes (user)**, so jam raters reach the ending.
- **Play shape: the heap column (user).** The heap is a cross-section. Scraps fall in from the neighbours above; the player steers where each lands and chooses when to turn the heap. Finished compost drops out of the bottom.
- **Greens and browns: neighbours mix (user).** Each scrap cooks by what touches it: a green touching browns heats up and rots into compost; greens packed together go slimy and stink; browns packed together stay cold. Placement is the puzzle; turning the heap reshuffles a stuck patch.
- **Goal: green the street (user).** Beside the heap, a grey street of houses. Compost feeds a garden; each garden that blooms adds a solarpunk feature (solar roof, vines, rain barrel, wind turbine, rooftop farm) and a neighbour who sends more scraps. The run ends when the whole street is green.
- **The lucky cat: under the bin floor (user).** The heap sits on an old packed layer that normal play never needs to clear. Turning one bottom corner over and over crumbles it and reveals the cat; an old neighbour hints at "the last bin's tenant". From then on its waving paw **doubles compost**, and the ending gains a **lucky-cat statue on the street**.
- **Title: Composters of SPLORR!! (user).**

## Rules (Claude's proposal)

### The heap

- The bin is **6 columns by 9 rows**. Each column is a stack: scraps always rest on the one below (no gaps).
- Scraps are **greens** (peels, coffee grounds, grass clippings) or **browns** (leaves, cardboard, twigs). **Compost** is what they become.
- One scrap falls at a time, from above the bin. **Left/right** steer it, **down** drops it a row, **OK** drops it straight down. It cannot be steered into a column stacked higher than it is. It lands on top of its column. If the column is already full, the scrap **spills** and is lost. The next three scraps are shown.
- **Rotting.** A green touching browns (left, right, above, below) heats up, faster for each brown it touches. When it is hot enough it rots: it and one brown it touches both become compost.
- **Slime.** A green touching two or more greens and no brown, for a few seconds, goes **slimy** (it stinks, and gives off fumes). A slimy green does not heat at all until its column is turned.
- **Cold browns.** A brown touching no green does nothing. It just takes up room.
- **Sinking and the hatch.** Compost is heavy: it sinks through the scraps below it, one row at a time. Compost that reaches the bottom drops out of the hatch into the barrow and is banked as **soil**.
- **Turning.** **Up** turns the column under the falling scrap with the fork: its bottom scrap comes up to the top and the rest settle down one. Turning airs the column: its slime clears and it heats faster for a while. Each turn uses one of the fork's **strength** pips, which refill slowly.

### The street (step 3)

- Eight houses, grey at the start. The shop (the Esc menu) offers **"Green the next house"** for soil; prices rise house by house.
- Each house that blooms gets its own solarpunk feature and a new neighbour: scraps fall a little faster, and the green/brown mix shifts with who lives there.
- Upgrades, also bought with soil: **Fork** (more strength, faster refill), **Worms** (greens heat faster), **Solar fan** (turning airs a column for longer), **Sieve** (more soil per compost).
- Neighbour chatter runs along the bottom of the screen; one old neighbour's lines hint at the cat.

### The lucky cat (step 4)

- The packed layer under the bin floor shows nothing special. Turning the **bottom-left column** several times in a row (without turning another column in between) cracks it; enough turns in a row crumble it and the cat comes up. Normal play turns columns where slime is, so it will not happen by accident.
- Benefit: soil per compost is doubled for the rest of the run, and the cat's statue stands on the street (shown in the ending).

### The end (step 4)

- When the eighth house blooms: the street in full, the time taken, compost made, and the statue if the cat was found. Then a fresh street; the best time is kept.

## Build order

1. **The heap** — falling scraps, steering, landing, spills, rotting, slime, sinking, the hatch and soil, turning with fork strength; plain drawn cells; native tests.
2. **Art** — scraps, compost, bin, fork, barrow and the street drawn by Claude in the Anvil; the street on screen.
3. **The street and the shop** — houses blooming, neighbours, upgrades, chatter.
4. **The cat and the end** — the packed layer, the cat, the statue, the end screen, saves, sounds.
5. **Release** — `ITCH_DESCRIPTION.md` (with the hidden-lucky-cat line, the AI disclosure and the team), cover, screenshots, devlog, a playtest bot to tune the 20 to 30 minutes, LootLocker link. Pages, the itch page and the jam submission are the user's calls.

## What carries over from earlier games

The jam allows your own libraries and tooling. The Odin wasm recipe boilerplate is reused: the framebuffer and text code (`screen.odin`), the browser layer (`web.odin`), the page shim (`index.html`), the build/test/ship scripts, the font generator and the shared LootLocker kit. All game rules are written new for this jam.

## Progress

- November 16, 2026: design decided (above).
- November 16, 2026: **step 1 built**: falling scraps (steer, drop a row, drop straight down; next three shown), landing and spills, rotting (heat per brown touching; a green and one brown become compost), slime, compost sinking and the hatch banking soil, turning with three fork pips. Plain drawn cells, a grey placeholder street. 12 native tests; checked in the browser pane (soil banks as compost drops out).
- November 16, 2026: **step 2 built**: 22 pictures drawn by Claude in the Anvil (world `composters.json`, exported to `art/`): three greens (peel, lettuce, grass clippings), three browns (leaf, cardboard, twig), three composts (one with a worm, one with a sprout), the fork (shown stuck in a column just after a turn), the barrow, the lucky cat, and the street pieces (roof, wall, solar roof, rooftop farm, vines, wind turbine, rain barrel, bare and blooming gardens, the sun). Slimy greens are the green art recoloured teal; grey houses are the house art recoloured grey. The street draws eight houses; a bloomed house gets its colour, a garden and one of five features in turn (solar roof, vines, rain barrel, wind turbine, rooftop farm). Plank bin walls. A native frame dump (`dump_test.odin`, `DUMP_PLAY`, `DUMP_HOUSES`). Open for step 3: the sky is still navy; it could clear from smog to blue as the street greens.
