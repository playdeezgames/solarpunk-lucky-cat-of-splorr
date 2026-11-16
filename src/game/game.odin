package game

// The rules of the heap: a 6 by 9 bin of column stacks. Scraps fall in one at a time, greens rot into
// compost where they touch browns, compost sinks and drops out of the hatch as soil. Pure: no core:os,
// no core:fmt, its own RNG, so tests are deterministic with a seed.

// Tuning (Claude's placeholders; see DESIGN.md).
COLS :: 6
ROWS :: 9
FALL_SPEED :: 1.6 // rows a second
HEAT_RATE :: 0.12 // heat a second for each brown a green touches (rots at 1)
SLIME_TIME :: 4.0 // seconds a green can be packed among greens before it goes slimy
SINK_TIME :: 0.35 // seconds between compost sinking a row
HATCH_TIME :: 0.6 // seconds compost sits at the bottom before it drops out
AIR_TIME :: 8.0 // seconds a turned column stays aired
AIR_BOOST :: 2.0 // heat multiplier while aired
FORK_MAX :: 3 // fork strength pips
FORK_REFILL :: 4.0 // seconds to refill one pip
GREEN_CHANCE :: 0.5 // chance a new scrap is green
QUEUE :: 3 // scraps shown waiting
SPAWN_Y :: f32(ROWS) + 0.5 // where a new scrap appears (rows from the bottom; the bin rim is ROWS)

Kind :: enum u8 {
	None,
	Green,
	Brown,
	Compost,
}

Cell :: struct {
	kind:  Kind,
	heat:  f32, // a green's progress to rotting, 0 to 1
	pack:  f32, // seconds a green has been packed among greens with no brown
	slime: bool,
	look:  u8, // which picture of its kind (peel, grounds, leaf, cardboard...), for drawing
}

Piece :: struct {
	kind: Kind,
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
}

SOUND_CAP :: 16

Game :: struct {
	rng:         u64,
	heap:        [COLS][ROWS]Cell, // heap[col][row], row 0 at the bottom; each column is a gapless stack
	air:         [COLS]f32, // seconds of airing left
	hatch:       [COLS]f32, // seconds the bottom compost has waited
	sink_t:      f32,
	piece:       Piece,
	queue:       [QUEUE]Piece,
	fork:        int, // strength pips
	fork_t:      f32,
	soil:        i64, // banked
	compost:     i64, // total compost made (for the end screen)
	spilled:     i64,
	time:        f64, // seconds played
	sounds:      [SOUND_CAP]Sound,
	sound_count: i32,
}

LOOKS :: 3 // pictures per kind of scrap

init_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed ~ 0x9E3779B97F4A7C15
	g.fork = FORK_MAX
	for i in 0 ..< QUEUE {
		g.queue[i] = new_scrap(g)
	}
	next_piece(g)
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
	if g.sound_count < SOUND_CAP {
		g.sounds[g.sound_count] = s
		g.sound_count += 1
	}
}

new_scrap :: proc(g: ^Game) -> Piece {
	kind := Kind.Green if rand_f32(g) < GREEN_CHANCE else Kind.Brown
	return Piece{kind = kind, look = u8(rand_int(g, LOOKS))}
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

// How many browns and greens touch the cell (left, right, above, below).
touching :: proc(g: ^Game, col, row: int) -> (browns, greens: int) {
	OFFS :: [4][2]int{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
	for o in OFFS {
		switch at(g, col + o[0], row + o[1]) {
		case .Brown:
			browns += 1
		case .Green:
			greens += 1
		case .None, .Compost:
		}
	}
	return
}

command :: proc(g: ^Game, c: Command) {
	p := &g.piece
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
	// The menu comes in step 3.
	}
}

// The falling scrap comes to rest on its column, or spills if the column is full.
land :: proc(g: ^Game) {
	p := g.piece
	h := height(g, p.col)
	if h >= ROWS {
		g.spilled += 1
		play(g, .Spill)
	} else {
		g.heap[p.col][h] = Cell{kind = p.kind, look = p.look}
		play(g, .Land)
	}
	next_piece(g)
}

// The fork turns a column: its bottom scrap comes up to the top and the rest settle down one. The column
// is aired: slime clears and it heats faster for a while.
turn :: proc(g: ^Game, col: int) -> bool {
	h := height(g, col)
	if g.fork <= 0 || h < 2 {
		play(g, .Deny)
		return false
	}
	g.fork -= 1
	if g.fork_t <= 0 {
		g.fork_t = FORK_REFILL
	}
	bottom := g.heap[col][0]
	for r in 0 ..< h - 1 {
		g.heap[col][r] = g.heap[col][r + 1]
	}
	g.heap[col][h - 1] = bottom
	for r in 0 ..< h {
		g.heap[col][r].slime = false
		g.heap[col][r].pack = 0
	}
	g.air[col] = AIR_TIME
	g.hatch[col] = 0
	play(g, .Turn)
	return true
}

tick :: proc(g: ^Game, dt_in: f64) {
	dt := f32(min(dt_in, 0.25))
	g.time += f64(dt)

	// Fork strength refills one pip at a time.
	if g.fork < FORK_MAX {
		g.fork_t -= dt
		if g.fork_t <= 0 {
			g.fork += 1
			g.fork_t = FORK_REFILL if g.fork < FORK_MAX else 0
		}
	}
	for &a in g.air {
		a = max(a - dt, 0)
	}

	// The falling scrap.
	g.piece.y -= FALL_SPEED * dt
	if g.piece.y <= f32(height(g, g.piece.col)) {
		land(g)
	}

	rot(g, dt)
	sink(g, dt)
	empty_hatch(g, dt)
}

// Greens touching browns heat up and rot; greens packed among greens go slimy.
rot :: proc(g: ^Game, dt: f32) {
	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			c := &g.heap[col][row]
			if c.kind != .Green {
				continue
			}
			browns, greens := touching(g, col, row)
			if browns == 0 && greens >= 2 && !c.slime {
				c.pack += dt
				if c.pack >= SLIME_TIME {
					c.slime = true
					play(g, .Slime)
				}
			} else if browns > 0 {
				c.pack = 0
			}
			if browns == 0 || c.slime {
				continue
			}
			rate := HEAT_RATE * f32(browns)
			if g.air[col] > 0 {
				rate *= AIR_BOOST
			}
			c.heat += rate * dt
		}
	}
	// Rot the ripe ones after measuring, so one pass does not change its own neighbours mid-way.
	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			if g.heap[col][row].kind == .Green && g.heap[col][row].heat >= 1 {
				rot_cell(g, col, row)
			}
		}
	}
}

// A ripe green becomes compost along with one brown it touches (the hottest pick: below first, then
// the sides, then above, so compost tends to form low).
rot_cell :: proc(g: ^Game, col, row: int) {
	OFFS :: [4][2]int{{0, -1}, {-1, 0}, {1, 0}, {0, 1}}
	for o in OFFS {
		if at(g, col + o[0], row + o[1]) == .Brown {
			g.heap[col + o[0]][row + o[1]] = Cell{kind = .Compost, look = u8(rand_int(g, LOOKS))}
			g.heap[col][row] = Cell{kind = .Compost, look = u8(rand_int(g, LOOKS))}
			g.compost += 2
			play(g, .Rot)
			return
		}
	}
}

// Compost sinks through the scraps below it, one row every SINK_TIME.
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

// Compost at the bottom of a column drops out of the hatch into the barrow as soil.
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
		for r in 0 ..< ROWS - 1 {
			g.heap[col][r] = g.heap[col][r + 1]
		}
		g.heap[col][ROWS - 1] = {}
		g.soil += 1
		play(g, .Hatch)
	}
}
