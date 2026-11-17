package game

// The rules of the heap: a 6 by 9 bin of column stacks. Scraps fall in one at a time, greens rot into
// compost where they touch browns, compost sinks and drops out of the hatch as soil. Rots keep the heap
// hot, and a hot heap makes more soil; a scrap that breaks down on its own is only mulch, worth nothing.
// Each new neighbour brings a new kind of scrap (Sort). Pure: no core:os, no core:fmt, its own RNG, so
// tests are deterministic with a seed.

// Tuning (Claude's placeholders; see DESIGN.md).
COLS :: 6
ROWS :: 9
FALL_SPEED :: 2.6 // rows a second
DELIVER :: 2.0 // seconds between scraps from the neighbours (less with each bloomed house)
BROWN_WEATHER :: 60.0 // seconds for a brown touching no green to break down on its own (mulch)
PACKET_WEATHER :: 120.0 // seconds before the wind takes a crisp packet (so no heap locks up for good)
SLIME_WEATHER :: 45.0 // seconds for a green touching no brown (slimy or not) to break down on its own (mulch)
HEAT_RATE :: 0.12 // heat a second for each brown a green touches (rots at 1)
SLIME_TIME :: 4.0 // seconds a green can be packed among greens before it goes slimy
SINK_TIME :: 0.35 // seconds between compost sinking a row
HATCH_TIME :: 0.6 // seconds compost sits at the bottom before it drops out
AIR_TIME :: 8.0 // seconds a turned column stays aired
AIR_BOOST :: 2.0 // heat multiplier while aired
FORK_MAX :: 3 // fork strength pips before upgrades
FORK_REFILL :: 4.0 // seconds to refill one pip
GREEN_CHANCE :: 0.5 // chance a new scrap is green
QUEUE :: 3 // scraps shown waiting
HOUSES :: 8 // houses on the street
SPAWN_Y :: f32(ROWS) + 0.5 // where a new scrap appears (rows from the bottom; the bin rim is ROWS)

// The heap's heat: rots warm it, time cools it; soil per compost is x1 when cold up to x3 when hot.
WARM_MAX_MULT :: 3.0
WARM_PER_ROT :: 0.06
WARM_COOL :: 0.035 // share of the heat lost a second (less with the solar fan), so it settles where the rots keep it
WARM_SLIME :: 0.08 // lost when a green goes slimy
WARM_MULCH :: 0.04 // lost when a scrap breaks down on its own
WARM_SPILL :: 0.15 // lost when a scrap spills

Kind :: enum u8 {
	None,
	Green,
	Brown,
	Compost,
	Junk, // a crisp packet: never rots, holds up the compost above it, the fork lifts it out
}

// Special scraps, one more as each new neighbour moves in (Plain is the everyday peel or leaf).
Sort :: enum u8 {
	Plain,
	Grounds, // green: heats twice as fast
	Egg_Box, // brown: feeds two greens before it is used up
	Citrus, // green: heats slowly, never goes slimy, and keeps the greens beside it from going slimy
}

GROUNDS_HEAT :: 2.0
CITRUS_HEAT :: 0.6

Cell :: struct {
	kind:  Kind,
	sort:  Sort,
	heat:  f32, // a green's progress to rotting, 0 to 1
	pack:  f32, // seconds a green has been packed among greens with no brown
	slime: bool,
	mulch: bool, // compost from a scrap that broke down on its own: no soil
	fed:   u8, // greens an egg box has fed
	look:  u8, // which picture of its kind (peel, grounds, leaf, cardboard...), for drawing
	worth: f32, // soil this compost banks when it drops out
}

Piece :: struct {
	kind: Kind,
	sort: Sort,
	look: u8,
	col:  int,
	y:    f32, // rows from the bin floor, falling; lands when it reaches the column's height
}

Command :: enum i32 {
	North,
	South,
	West,
	East,
	Ok,
	Cancel,
}

Sound :: enum i32 {
	Move,
	Land,
	Turn,
	Rot,
	Hatch,
	Spill,
	Deny,
	Slime,
	Open,
	Close,
	Buy,
	Bloom,
	Crack,
	Cat,
	Green, // the whole street
}

SOUND_CAP :: 16

Game :: struct {
	rng:         u64,
	heap:        [COLS][ROWS]Cell, // heap[col][row], row 0 at the bottom; each column is a gapless stack
	air:         [COLS]f32, // seconds of airing left
	forked:      [COLS]f32, // seconds the fork stays drawn after a turn
	hatch:       [COLS]f32, // seconds the bottom compost has waited
	sink_t:      f32,
	piece:       Piece,
	waiting:     f32, // seconds until the next scrap arrives (it is not in play until then)
	since_spawn: f32,
	spawns:      int, // scraps that have arrived
	queue:       [QUEUE]Piece,
	fork:        int, // strength pips
	fork_t:      f32,
	warmth:      f32, // the heap's heat, 0 to 1
	soil:        i64, // banked
	soil_frac:   f32, // part-soil, carried until it makes a whole one
	houses:      int, // how many houses have bloomed
	levels:      [Upgrade]int,
	corner_run:  int, // turns of the bottom-left column in a row (the packed layer cracks)
	cat_found:   bool,
	cat_t:       f32, // seconds since the cat came up (its jump out of the floor)
	finished:    bool, // the whole street is green: the end screen
	best_time:   f64, // fastest street, kept across fresh streets (0 for none)
	best_cat:    bool, // whether the cat was ever found
	streets:     int, // streets finished
	muted:       bool,
	shop:        Shop,
	chat:        Chat,
	tut:         Tutorial,
	compost:     i64, // total compost made (for the end screen)
	mulched:     i64,
	spilled:     i64,
	packets:     i64, // crisp packets forked out
	time:        f64, // seconds played
	sounds:      [SOUND_CAP]Sound,
	sound_count: i32,
}

LOOKS :: 3 // pictures per kind of scrap

// Counters for the playtest bot (not part of Game, so saves do not change).
Stats :: struct {
	pairs:       int, // a green and a brown rotted together
	green_alone: int, // a green broke down on its own (slimy or with no brown)
	brown_alone: int, // a brown broke down on its own
	slimed:      int,
	turns:       int,
	turns_slime: int, // turns that cleared slime
	packets:     int, // turns that lifted out a packet
	warmth:      f64, // summed each tick, for the average
	soil:        f64, // soil banked
}
stats: Stats

// A first street (`guided`) starts with the tutorial; otherwise its guided steps are skipped.
init_game :: proc(g: ^Game, seed: u64, guided := false) {
	g^ = {}
	g.rng = seed ~ 0x9E3779B97F4A7C15
	g.fork = FORK_MAX
	if guided {
		tut_start(g)
	} else {
		tut_skip(g)
	}
	for i in 0 ..< QUEUE {
		g.queue[i] = new_scrap(g)
	}
	next_piece(g)
	g.waiting = 0 // the first scrap is ready
}

// splitmix64
rand_u64 :: proc(g: ^Game) -> u64 {
	g.rng += 0x9E3779B97F4A7C15
	z := g.rng
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

rand_f32 :: proc(g: ^Game) -> f32 {
	return f32(rand_u64(g) >> 40) / f32(1 << 24)
}

rand_int :: proc(g: ^Game, n: int) -> int {
	return int(rand_u64(g) % u64(n))
}

play :: proc(g: ^Game, s: Sound) {
	if !g.muted && g.sound_count < SOUND_CAP {
		g.sounds[g.sound_count] = s
		g.sound_count += 1
	}
}

// Which houses' neighbours bring which special scraps (houses bloomed before they start arriving),
// and how often (share of greens, of browns, or of all scraps for packets).
UNLOCK_GROUNDS :: 1
UNLOCK_EGG_BOX :: 2
UNLOCK_CITRUS :: 4
UNLOCK_PACKET :: 6
GROUNDS_SHARE :: 0.3
EGG_BOX_SHARE :: 0.3
CITRUS_SHARE :: 0.25
PACKET_SHARE :: 0.07

new_scrap :: proc(g: ^Game) -> Piece {
	if tut_scripted(g) {
		return tut_scrap(g)
	}
	r := rand_f32(g)
	if g.houses >= UNLOCK_PACKET && r < PACKET_SHARE {
		return Piece{kind = .Junk}
	}
	kind := Kind.Green if rand_f32(g) < green_chance(g) else Kind.Brown
	p := Piece{kind = kind, look = u8(rand_int(g, LOOKS))}
	s := rand_f32(g)
	if kind == .Green {
		if g.houses >= UNLOCK_GROUNDS && s < GROUNDS_SHARE {
			p.sort = .Grounds
		} else if g.houses >= UNLOCK_CITRUS && s >= 1 - CITRUS_SHARE {
			p.sort = .Citrus
		}
	} else if g.houses >= UNLOCK_EGG_BOX && s < EGG_BOX_SHARE {
		p.sort = .Egg_Box
	}
	return p
}

// Takes the front of the queue as the falling scrap, over the column the last one was steered to.
next_piece :: proc(g: ^Game) {
	col := g.piece.col
	g.piece = g.queue[0]
	for i in 0 ..< QUEUE - 1 {
		g.queue[i] = g.queue[i + 1]
	}
	g.queue[QUEUE - 1] = new_scrap(g)
	g.piece.col = col
	g.piece.y = SPAWN_Y
	g.waiting = max(deliver_time(g) - g.since_spawn, 0)
	if g.waiting == 0 {
		g.since_spawn = 0
		g.spawns += 1
	}
}

height :: proc(g: ^Game, col: int) -> int {
	for r in 0 ..< ROWS {
		if g.heap[col][r].kind == .None {
			return r
		}
	}
	return ROWS
}

at :: proc(g: ^Game, col, row: int) -> Kind {
	if col < 0 || col >= COLS || row < 0 || row >= ROWS {
		return .None
	}
	return g.heap[col][row].kind
}

cell_at :: proc(g: ^Game, col, row: int) -> Cell {
	if col < 0 || col >= COLS || row < 0 || row >= ROWS {
		return {}
	}
	return g.heap[col][row]
}

// How many browns and greens touch the cell (left, right, above, below). `citrus` counts the greens
// among them that are citrus.
touching :: proc(g: ^Game, col, row: int) -> (browns, greens, citrus: int) {
	OFFS :: [4][2]int{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
	for o in OFFS {
		c := cell_at(g, col + o[0], row + o[1])
		switch c.kind {
		case .Brown:
			browns += 1
		case .Green:
			greens += 1
			if c.sort == .Citrus {
				citrus += 1
			}
		case .None, .Compost, .Junk:
		}
	}
	return
}

command :: proc(g: ^Game, c: Command) {
	if g.finished {
		if c == .Ok {
			new_street(g)
		}
		return
	}
	if g.shop.open {
		shop_command(g, c)
		return
	}
	if tut_command(g, c) {
		return
	}
	p := &g.piece
	if g.waiting > 0 && (c == .South || c == .Ok) {
		return // nothing to drop until the next scrap arrives
	}
	switch c {
	case .West, .East:
		to := p.col + (-1 if c == .West else 1)
		if to < 0 || to >= COLS || f32(height(g, to)) > p.y {
			play(g, .Deny)
			return
		}
		p.col = to
		play(g, .Move)
	case .South:
		p.y = max(p.y - 1, f32(height(g, p.col)))
		if p.y <= f32(height(g, p.col)) {
			land(g)
		}
	case .Ok:
		land(g)
	case .North:
		turn(g, p.col)
	case .Cancel:
		open_shop(g)
	}
}

// The falling scrap comes to rest on its column, or spills if the column is full.
land :: proc(g: ^Game) {
	p := g.piece
	h := height(g, p.col)
	if h >= ROWS {
		g.spilled += 1
		cool(g, WARM_SPILL)
		play(g, .Spill)
	} else {
		g.heap[p.col][h] = Cell{kind = p.kind, sort = p.sort, look = p.look}
		g.chat.lands += 1
		play(g, .Land)
	}
	tut_landed(g, p)
	next_piece(g)
}

warm_mult :: proc(g: ^Game) -> f32 {
	return 1 + (WARM_MAX_MULT - 1) * g.warmth
}

cool :: proc(g: ^Game, by: f32) {
	g.warmth = max(g.warmth - by, 0)
}

// The fork turns a column: its bottom scrap comes up to the top and the rest settle down one. The column
// is aired: slime clears and it heats faster for a while. If a crisp packet is in the column, the fork
// lifts that out instead (the highest one), and the rest settle down.
turn :: proc(g: ^Game, col: int) -> bool {
	h := height(g, col)
	junk := -1
	for r in 0 ..< h {
		if g.heap[col][r].kind == .Junk {
			junk = r
		}
	}
	if g.fork <= 0 || h < 2 && junk < 0 {
		play(g, .Deny)
		return false
	}
	g.fork -= 1
	stats.turns += 1
	for r in 0 ..< h {
		if g.heap[col][r].slime {
			stats.turns_slime += 1
			break
		}
	}
	if g.fork_t <= 0 {
		g.fork_t = fork_refill(g)
	}
	if junk >= 0 {
		for r in junk ..< ROWS - 1 {
			g.heap[col][r] = g.heap[col][r + 1]
		}
		g.heap[col][ROWS - 1] = {}
		g.packets += 1
		stats.packets += 1
		h -= 1
	} else {
		bottom := g.heap[col][0]
		for r in 0 ..< h - 1 {
			g.heap[col][r] = g.heap[col][r + 1]
		}
		g.heap[col][h - 1] = bottom
	}
	for r in 0 ..< h {
		g.heap[col][r].slime = false
		g.heap[col][r].pack = 0
	}
	g.air[col] = air_time(g)
	g.forked[col] = 0.35
	g.hatch[col] = 0
	play(g, .Turn)
	turned_corner(g, col)
	tut_turned(g, junk >= 0)
	return true
}

tick :: proc(g: ^Game, dt_in: f64) {
	dt := f32(min(dt_in, 0.25))
	chat_tick(g, dt)
	if g.cat_found {
		g.cat_t += dt
	}
	tut_tick(g, dt)
	if g.shop.open || g.finished || tut_paused(g) {
		return // the shop (and a tutorial card waiting to be read) pauses the heap
	}
	g.time += f64(dt)

	// Fork strength refills one pip at a time.
	if g.fork < fork_max(g) {
		g.fork_t -= dt
		if g.fork_t <= 0 {
			g.fork += 1
			g.fork_t = fork_refill(g) if g.fork < fork_max(g) else 0
		}
	}
	for col in 0 ..< COLS {
		g.air[col] = max(g.air[col] - dt, 0)
		g.forked[col] = max(g.forked[col] - dt, 0)
	}
	cool(g, g.warmth * warm_cool(g) * dt)
	stats.warmth += f64(g.warmth)

	// The falling scrap.
	g.since_spawn += dt
	if g.waiting > 0 {
		g.waiting -= dt
		if g.waiting <= 0 {
			g.waiting = 0
			g.since_spawn = 0
			g.spawns += 1
		}
	} else {
		g.piece.y -= fall_speed(g) * dt
		if g.piece.y <= f32(height(g, g.piece.col)) {
			land(g)
		}
	}

	rot(g, dt)
	sink(g, dt)
	empty_hatch(g, dt)
}

// How fast a green heats for each brown it touches.
green_rate :: proc(g: ^Game, c: Cell) -> f32 {
	rate := f32(HEAT_RATE)
	#partial switch c.sort {
	case .Grounds:
		rate *= GROUNDS_HEAT
	case .Citrus:
		return rate * CITRUS_HEAT // the worms will not touch it
	}
	return rate * worm_boost(g)
}

// Greens touching browns heat up and rot; greens packed among greens go slimy.
rot :: proc(g: ^Game, dt: f32) {
	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			c := &g.heap[col][row]
			if c.kind == .Junk {
				c.heat += dt / PACKET_WEATHER
				continue
			}
			if c.kind == .Brown {
				// A cold brown breaks down on its own, slowly, so a heap can never lock up for good.
				_, gr, _ := touching(g, col, row)
				if gr == 0 {
					c.heat += dt / BROWN_WEATHER
				}
				continue
			}
			if c.kind != .Green {
				continue
			}
			browns, greens, citrus := touching(g, col, row)
			if browns == 0 || c.slime {
				// A slimy green, or one with no brown, breaks down on its own, slowly (so no heap locks
				// up for good).
				c.heat += dt / SLIME_WEATHER
			}
			// Packed among greens with no brown it goes slimy, unless it is citrus or citrus is beside it.
			if browns == 0 && greens >= 2 && citrus == 0 && c.sort != .Citrus && !c.slime {
				c.pack += dt
				if c.pack >= SLIME_TIME {
					c.slime = true
					stats.slimed += 1
					cool(g, WARM_SLIME)
					play(g, .Slime)
				}
			} else if browns > 0 {
				c.pack = 0
			}
			if browns == 0 || c.slime {
				continue
			}
			rate := green_rate(g, c^) * f32(browns)
			if g.air[col] > 0 {
				rate *= AIR_BOOST
			}
			c.heat += rate * dt
		}
	}
	// Rot the ripe ones after measuring, so one pass does not change its own neighbours mid-way.
	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			c := &g.heap[col][row]
			if c.heat < 1 {
				continue
			}
			if c.kind == .Junk {
				// The wind takes it; the rest of the column settles.
				for r in row ..< ROWS - 1 {
					g.heap[col][r] = g.heap[col][r + 1]
				}
				g.heap[col][ROWS - 1] = {}
				continue
			}
			if c.kind == .Brown || c.kind == .Green && (c.slime || no_brown(g, col, row)) {
				if c.kind == .Brown {
					stats.brown_alone += 1
				} else {
					stats.green_alone += 1
				}
				c^ = Cell{kind = .Compost, mulch = true, look = u8(rand_int(g, LOOKS))}
				g.mulched += 1
				cool(g, WARM_MULCH)
				play(g, .Rot)
			} else if c.kind == .Green {
				rot_cell(g, col, row)
			}
		}
	}
}

// A ripe green becomes compost along with one brown it touches (the hottest pick: below first, then
// the sides, then above, so compost tends to form low). An egg box feeds two greens: the first leaves it
// soggy, the second turns it to compost too. The compost is worth more the hotter the heap is.
rot_cell :: proc(g: ^Game, col, row: int) {
	OFFS :: [4][2]int{{0, -1}, {-1, 0}, {1, 0}, {0, 1}}
	for o in OFFS {
		bc, br := col + o[0], row + o[1]
		if at(g, bc, br) != .Brown {
			continue
		}
		g.warmth = min(g.warmth + WARM_PER_ROT, 1)
		worth := soil_per_compost(g) * warm_mult(g)
		g.heap[col][row] = Cell{kind = .Compost, look = u8(rand_int(g, LOOKS)), worth = worth}
		g.compost += 1
		b := &g.heap[bc][br]
		if b.sort == .Egg_Box && b.fed == 0 {
			b.fed = 1
		} else {
			b^ = Cell{kind = .Compost, look = u8(rand_int(g, LOOKS)), worth = worth}
			g.compost += 1
		}
		stats.pairs += 1
		play(g, .Rot)
		tut_rotted(g)
		return
	}
}

// Compost sinks through the scraps below it, one row every SINK_TIME (but not through a crisp packet).
sink :: proc(g: ^Game, dt: f32) {
	g.sink_t += dt
	if g.sink_t < SINK_TIME {
		return
	}
	g.sink_t -= SINK_TIME
	for col in 0 ..< COLS {
		for row in 1 ..< ROWS {
			below := &g.heap[col][row - 1]
			here := &g.heap[col][row]
			if here.kind == .Compost && (below.kind == .Green || below.kind == .Brown) {
				below^, here^ = here^, below^
				g.hatch[col] = 0
			}
		}
	}
}

// Compost at the bottom of a column drops out of the hatch into the barrow as soil (mulch as nothing).
empty_hatch :: proc(g: ^Game, dt: f32) {
	for col in 0 ..< COLS {
		if g.heap[col][0].kind != .Compost {
			g.hatch[col] = 0
			continue
		}
		g.hatch[col] += dt
		if g.hatch[col] < HATCH_TIME {
			continue
		}
		g.hatch[col] = 0
		worth := g.heap[col][0].worth
		for r in 0 ..< ROWS - 1 {
			g.heap[col][r] = g.heap[col][r + 1]
		}
		g.heap[col][ROWS - 1] = {}
		bank_soil(g, worth)
		play(g, .Hatch)
		tut_banked(g)
	}
}

no_brown :: proc(g: ^Game, col, row: int) -> bool {
	browns, _, _ := touching(g, col, row)
	return browns == 0
}
