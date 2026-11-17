package game

// The tutorial. A first street starts with guided steps: a goal along the bottom of the screen that
// moves on when the player has done it (land a brown, land a green beside it, watch it rot, see the soil
// drop, keep going, turn a column, green the first house). The first scraps are scripted and come
// slowly. Cards (which pause the heap until OK) explain each new thing once, the first time it turns up:
// the heap's heat, slime, a spill, and each new neighbour's scrap. The shed's HOW TO PLAY shows the
// whole game on one card. A fresh street skips the guided steps. Written by Claude.

Step :: enum u8 {
	Land_Brown,
	Land_Green,
	Rot,
	Bank,
	Keep_Going,
	Turn,
	Shed,
	Done,
}

Tip :: enum u8 {
	None,
	Welcome,
	Warmth,
	Slime,
	Spill,
	Grounds,
	Egg_Box,
	Citrus,
	Packet,
	Ready,
	Help,
}

Tutorial :: struct {
	step:    Step,
	done:    bool, // the guided steps are over (or were skipped)
	card:    Tip, // shown, pausing the heap, until OK
	seen:    bit_set[Tip;u16],
	pending: bit_set[Tip;u16], // cards waiting their turn
	script:  int, // scripted scraps handed out
	count:   int, // scraps landed in the Keep_Going step
}

KEEP_GOING :: 5 // scraps landed in the Keep_Going step

// The first scraps of a first street: a leaf, a peel to put beside it, then a gentle mix.
SCRIPT := [?]Kind{.Brown, .Green, .Brown, .Green, .Green, .Brown, .Green, .Brown}

Card :: struct {
	title: string,
	text:  string,
	pic:   Kind, // a scrap to show beside the title (None for none)
	sort:  Sort,
}

CARDS := [Tip]Card {
	.None    = {},
	.Welcome = {title = "THE STREET'S BIN", text = "You are Ash Street's compost bin. The neighbours drop their scraps in from above. Rot them into soil, and spend the soil to turn the grey street green."},
	.Warmth  = {title = "A HOT HEAP", text = "Every rot warms the heap (HEAT, by the barrow). A hot heap makes up to 3 soil a compost. It cools if nothing rots. A scrap left on its own turns to grey MULCH: worth nothing.", pic = .Compost},
	.Slime   = {title = "SLIME!", text = "Greens packed together with no brown go slimy and stop rotting, and the heap cools. UP turns the column the scrap is over: the slime clears.", pic = .Green},
	.Spill   = {title = "SPILLED", text = "That column was full, so the scrap spilled and the heap cooled. Keep the heap low: pair greens with browns so they rot down."},
	.Grounds = {title = "COFFEE GROUNDS", text = "From Priya at No. 1. A green that rots twice as fast. Good for keeping the heap hot.", pic = .Green, sort = .Grounds},
	.Egg_Box = {title = "EGG BOXES", text = "From Des at No. 2. A brown that feeds two greens before it is used up. It goes soggy after the first.", pic = .Brown, sort = .Egg_Box},
	.Citrus  = {title = "ORANGE PEEL", text = "From Theo at No. 4. A green the worms dislike: it rots slowly. It never goes slimy, and greens beside it stay fresh too.", pic = .Green, sort = .Citrus},
	.Packet  = {title = "CRISP PACKETS", text = "From the kids at No. 6. Not compost! Compost will not sink past one. UP on its column and the fork lifts it out.", pic = .Junk},
	.Ready   = {title = "THE FIRST HOUSE BLOOMS", text = "That's the bin. Green all eight houses. Each new neighbour brings scraps a little faster, and some bring new kinds. Old Mo at No. 8 remembers the last bin..."},
	.Help    = {title = "HOW TO PLAY", text = "LEFT/RIGHT steer, DOWN drops. Land greens (peels) touching browns (leaves): they heat up and rot into compost, which drops into the barrow as soil. Rots keep the heap hot: more soil. Greens with no brown go slimy: UP turns a column and clears it. Scraps left alone turn to grey mulch: no soil. E or ESC: the shed."},
}

// Goals along the bottom while the guided steps run.
GOALS := [Step]string {
	.Land_Brown = "A brown leaf is coming. LEFT/RIGHT to steer, DOWN to drop it in.",
	.Land_Green = "Now a green peel. Land it touching the leaf.",
	.Rot        = "Touching a brown, a green heats up (the bar). Hot enough, both rot.",
	.Bank       = "Compost! It sinks, and drops out of the bottom into the barrow as SOIL.",
	.Keep_Going = "Keep every green touching a brown. Watch the HEAT by the barrow.",
	.Turn       = "UP turns the column under the scrap with the fork: it airs and rots faster. Try it.",
	.Shed       = "Save 15 soil, then E or ESC opens the BIN SHED: green the first house.",
	.Done       = "",
}

tut_start :: proc(g: ^Game) {
	g.tut = Tutorial{}
	tut_show(g, .Welcome)
}

// Shows a card once (or queues it behind the one showing).
tut_show :: proc(g: ^Game, tip: Tip) {
	if tip in g.tut.seen {
		return
	}
	g.tut.seen += {tip}
	if g.tut.card == .None {
		g.tut.card = tip
	} else {
		g.tut.pending += {tip}
	}
}

tut_paused :: proc(g: ^Game) -> bool {
	return g.tut.card != .None
}

// Slow scraps while the first lessons run.
tut_slow :: proc(g: ^Game) -> bool {
	return !g.tut.done && g.tut.step <= .Bank
}

tut_scripted :: proc(g: ^Game) -> bool {
	return !g.tut.done && g.tut.script < len(SCRIPT)
}

tut_scrap :: proc(g: ^Game) -> Piece {
	k := SCRIPT[g.tut.script]
	g.tut.script += 1
	return Piece{kind = k, look = u8(rand_int(g, LOOKS))}
}

// A card takes the commands while it shows: OK (or Cancel) puts it away.
tut_command :: proc(g: ^Game, c: Command) -> bool {
	if g.tut.card == .None {
		return false
	}
	if c == .Ok || c == .Cancel {
		g.tut.card = .None
		for t in Tip {
			if t in g.tut.pending {
				g.tut.pending -= {t}
				g.tut.card = t
				break
			}
		}
		play(g, .Close)
	}
	return true
}

tut_landed :: proc(g: ^Game, p: Piece) {
	if g.tut.done {
		return
	}
	#partial switch g.tut.step {
	case .Land_Brown:
		if p.kind == .Brown {
			g.tut.step = .Land_Green
		}
	case .Land_Green:
		for col in 0 ..< COLS {
			for row in 0 ..< ROWS {
				if g.heap[col][row].kind == .Green && !no_brown(g, col, row) {
					g.tut.step = .Rot
				}
			}
		}
	case .Keep_Going:
		g.tut.count += 1
		if g.tut.count >= KEEP_GOING {
			g.tut.step = .Turn
		}
	}
}

tut_rotted :: proc(g: ^Game) {
	if !g.tut.done && g.tut.step <= .Rot {
		g.tut.step = .Bank
	}
}

tut_banked :: proc(g: ^Game) {
	if !g.tut.done && g.tut.step == .Bank {
		g.tut.step = .Keep_Going
		tut_show(g, .Warmth)
	}
}

tut_turned :: proc(g: ^Game, packet: bool) {
	if !g.tut.done && g.tut.step == .Turn {
		g.tut.step = .Shed
	}
}

tut_bought :: proc(g: ^Game) {
	if !g.tut.done {
		g.tut.step = .Done
		g.tut.done = true
		tut_show(g, .Ready)
	}
}

// Cards for things as they first turn up: slime, a spill, a new kind of scrap in the queue.
tut_tick :: proc(g: ^Game, dt: f32) {
	if g.spilled > 0 {
		tut_show(g, .Spill)
	}
	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			if g.heap[col][row].slime {
				tut_show(g, .Slime)
			}
		}
	}
	pieces := [QUEUE + 1]Piece{g.piece, g.queue[0], g.queue[1], g.queue[2]}
	for p in pieces {
		switch {
		case p.kind == .Junk:
			tut_show(g, .Packet)
		case p.sort == .Grounds:
			tut_show(g, .Grounds)
		case p.sort == .Egg_Box:
			tut_show(g, .Egg_Box)
		case p.sort == .Citrus:
			tut_show(g, .Citrus)
		}
	}
}

// A fresh street skips the guided steps (the cards already seen stay seen).
tut_skip :: proc(g: ^Game) {
	seen := g.tut.seen
	g.tut = Tutorial{step = .Done, done = true, seen = seen}
}
