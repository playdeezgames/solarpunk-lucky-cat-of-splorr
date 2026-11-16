#+build !js
package game

// A bot plays whole streets through the real commands, to tune prices and rates to the user's 20 to 30
// minute run. Off unless -define:PLAYTEST=true:
// odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:PLAYTEST=true -o:speed -define:ODIN_TEST_NAMES=game.playtest_streets

import "core:fmt"
import "core:testing"

PLAYTEST :: #config(PLAYTEST, false)
PLAYTEST_SEEDS :: #config(PLAYTEST_SEEDS, 4)

Style :: struct {
	name:  string,
	think: f32, // seconds before it starts steering a new scrap
	step:  f32, // seconds between key presses while steering
	drop:  bool, // drops straight down once over the column (else lets it fall)
	smart: bool, // places by the neighbours; otherwise picks the lowest column, with a little sense
	cat:   bool, // goes looking for the cat once it has heard the hint
}

STYLES := [?]Style {
	{name = "careful", think = 0.5, step = 0.12, drop = true, smart = true, cat = true},
	{name = "relaxed", think = 1.0, step = 0.2, drop = true, smart = true, cat = false},
	{name = "lazy", think = 0.8, step = 0.25, drop = false, smart = false, cat = false},
}

// How good it is to land `kind` on column `col` now.
place_score :: proc(g: ^Game, kind: Kind, col: int, smart: bool) -> f32 {
	h := height(g, col)
	if h >= ROWS {
		return -1000
	}
	browns, greens := touching(g, col, h)
	score := -f32(h) * 0.6
	if !smart {
		return score + (1 if kind == .Green && browns > 0 else 0)
	}
	if kind == .Green {
		score += f32(browns) * 3 - f32(greens) * 2
	} else {
		// A brown is best next to greens that have no brown yet.
		OFFS :: [4][2]int{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
		for o in OFFS {
			if at(g, col + o[0], h + o[1]) == .Green {
				b, _ := touching(g, col + o[0], h + o[1])
				score += 3 if b == 0 else 1
			}
		}
		score -= f32(browns) * 0.5
	}
	return score
}

best_column :: proc(g: ^Game, kind: Kind, smart: bool) -> int {
	best, best_score := 0, f32(-1e9)
	for col in 0 ..< COLS {
		s := place_score(g, kind, col, smart) - 0.05 * f32(abs(col - g.piece.col))
		if s > best_score {
			best, best_score = col, s
		}
	}
	return best
}

slimy_column :: proc(g: ^Game) -> int {
	for col in 0 ..< COLS {
		for row in 0 ..< height(g, col) {
			if g.heap[col][row].slime {
				return col
			}
		}
	}
	return -1
}

// Spends soil: the next house when it can, an upgrade when it is cheap next to the house.
bot_shop :: proc(g: ^Game) {
	if price, ok := next_house_price(g); ok && g.soil >= price {
		buy(g, SHOP_HOUSE)
		return
	}
	house, _ := next_house_price(g)
	for u in Upgrade {
		if price, ok := upgrade_price(g, u); ok && g.soil >= price && price * 2 <= house + 10 {
			buy(g, 1 + int(u))
			return
		}
	}
}

Run :: struct {
	time:     f64,
	houses:   [HOUSES]f64, // when each house bloomed
	spilled:  i64,
	compost:  i64,
	cat_at:   f64,
	finished: bool,
}

play_street :: proc(seed: u64, style: Style) -> Run {
	g := new(Game)
	defer free(g)
	init_game(g, seed)
	run: Run
	DT :: f32(1.0 / 30)
	wait := style.think
	target := -1
	seen := -1
	heard := false
	digging := false
	for g.time < 3 * 3600 && !g.finished {
		tick(g, f64(DT))
		g.sound_count = 0
		if g.chat.who == OLD_MO {
			heard = true
		}
		// The shop, between scraps.
		before := g.houses
		bot_shop(g)
		if g.houses != before {
			run.houses[g.houses - 1] = g.time
		}
		if g.finished {
			break
		}
		// The cat: once the hint is heard, a careful player digs at the left corner.
		if style.cat && heard && !g.cat_found && height(g, CAT_COL) >= 2 {
			digging = true
		}
		if digging && !g.cat_found {
			if g.fork > 0 {
				turn(g, CAT_COL)
			}
			if g.cat_found {
				run.cat_at = g.time
				digging = false
			}
		} else if col := slimy_column(g); col >= 0 && g.fork > 0 && style.smart {
			turn(g, col)
		}
		if g.waiting > 0 {
			continue
		}
		// A new scrap: think, choose a column, steer, drop.
		if g.spawns != seen {
			seen = g.spawns
			wait = style.think
			target = -1
		}
		wait -= DT
		if wait > 0 {
			continue
		}
		if target < 0 {
			target = best_column(g, g.piece.kind, style.smart)
		}
		if g.piece.col != target {
			before_col := g.piece.col
			command(g, .East if target > g.piece.col else .West)
			if g.piece.col == before_col {
				target = g.piece.col // blocked; take what we can
			}
			wait = style.step
			continue
		}
		if style.drop {
			command(g, .Ok)
			wait = 1e9 // until the next scrap
		}
	}
	run.time = g.time
	run.spilled = g.spilled
	run.compost = g.compost
	run.finished = g.finished
	return run
}

@(test)
playtest_streets :: proc(t: ^testing.T) {
	if !PLAYTEST {
		return
	}
	for style in STYLES {
		total: f64
		for s in 0 ..< PLAYTEST_SEEDS {
			r := play_street(u64(1000 + s * 77), style)
			total += r.time
			fmt.printf("%-8s seed %d: %s %5.1f min, spilled %d, compost %d, cat %5.1f min; houses at", style.name, s, "done" if r.finished else "STUCK", r.time / 60, r.spilled, r.compost, r.cat_at / 60)
			for h in r.houses {
				fmt.printf(" %4.1f", h / 60)
			}
			fmt.println()
		}
		fmt.printf("%-8s average %.1f min\n", style.name, total / f64(PLAYTEST_SEEDS) / 60)
	}
}
