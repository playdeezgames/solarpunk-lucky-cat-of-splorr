#+build !js
package game

import "core:testing"

// A game with an empty heap and a known falling scrap.
fresh :: proc(g: ^Game, kind := Kind.Green) {
	init_game(g, 1)
	g.piece = Piece{kind = kind, col = 0, y = SPAWN_Y}
}

put :: proc(g: ^Game, col: int, kinds: ..Kind) {
	for k, i in kinds {
		g.heap[col][i] = Cell{kind = k}
	}
}

@(test)
drop_lands_on_column :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 2, .Brown, .Brown)
	command(&g, .East)
	command(&g, .East)
	testing.expect_value(t, g.piece.col, 2)
	command(&g, .Ok)
	testing.expect_value(t, g.heap[2][2].kind, Kind.Green)
	testing.expect_value(t, height(&g, 2), 3)
	testing.expect_value(t, g.piece.col, 2) // the next scrap starts where the last was steered
	testing.expect_value(t, g.piece.y, SPAWN_Y)
}

@(test)
falls_and_lands_in_time :: proc(t: ^testing.T) {
	g: Game
	fresh(&g, .Brown)
	for _ in 0 ..< 200 {
		tick(&g, 1.0 / 60)
	}
	// 9.5 rows at FALL_SPEED take about 5.9 s; 3.3 s in, it is still falling.
	testing.expect_value(t, height(&g, 0), 0)
	for _ in 0 ..< 200 {
		tick(&g, 1.0 / 60)
	}
	testing.expect_value(t, g.heap[0][0].kind, Kind.Brown)
}

@(test)
cannot_steer_into_taller_column :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 1, .Brown, .Brown, .Brown, .Brown, .Brown)
	g.piece.y = 3
	command(&g, .East)
	testing.expect_value(t, g.piece.col, 0)
	g.piece.y = 6
	command(&g, .East)
	testing.expect_value(t, g.piece.col, 1)
}

@(test)
full_column_spills :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	for r in 0 ..< ROWS {
		g.heap[0][r] = Cell{kind = .Brown}
	}
	command(&g, .Ok)
	testing.expect_value(t, g.spilled, 1)
	testing.expect_value(t, height(&g, 0), ROWS)
}

@(test)
green_touching_brown_rots :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Brown, .Green)
	// One brown touching: rots in 1/HEAT_RATE seconds.
	for _ in 0 ..< int(1.0 / HEAT_RATE * 60) + 2 {
		tick(&g, 1.0 / 60)
		g.piece.y = SPAWN_Y // keep the falling scrap out of the way
	}
	testing.expect_value(t, g.compost, 2)
	// Both became compost; the bottom one may already have gone out of the hatch.
	testing.expect(t, g.heap[0][0].kind == .Compost)
}

@(test)
two_browns_rot_twice_as_fast :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 0, .Brown)
	put(&g, 1, .Green)
	put(&g, 2, .Brown)
	tick(&g, 0.25)
	testing.expect(t, abs(g.heap[1][0].heat - 2 * HEAT_RATE * 0.25) < 1e-4)
}

@(test)
packed_greens_go_slimy_and_turning_clears :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Green, .Green, .Green)
	for _ in 0 ..< int(SLIME_TIME * 60) + 2 {
		tick(&g, 1.0 / 60)
		g.piece.y = SPAWN_Y
	}
	testing.expect(t, g.heap[0][1].slime) // the middle one touches two greens
	testing.expect(t, !g.heap[0][0].slime) // the ends touch only one
	testing.expect(t, turn(&g, 0))
	testing.expect(t, !g.heap[0][0].slime && !g.heap[0][1].slime && !g.heap[0][2].slime)
	testing.expect(t, g.air[0] > 0)
}

@(test)
slimy_green_does_not_heat :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 0, .Green)
	put(&g, 1, .Brown)
	g.heap[0][0].slime = true
	tick(&g, 0.25)
	testing.expect_value(t, g.heap[0][0].heat, f32(0))
}

@(test)
turn_rotates_bottom_to_top_and_uses_fork :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 3, .Brown, .Green, .Compost)
	testing.expect(t, turn(&g, 3))
	testing.expect_value(t, g.heap[3][0].kind, Kind.Green)
	testing.expect_value(t, g.heap[3][1].kind, Kind.Compost)
	testing.expect_value(t, g.heap[3][2].kind, Kind.Brown)
	testing.expect_value(t, g.fork, FORK_MAX - 1)
	testing.expect(t, turn(&g, 3))
	testing.expect(t, turn(&g, 3))
	testing.expect(t, !turn(&g, 3)) // out of strength
	// Refills a pip every FORK_REFILL seconds.
	for _ in 0 ..< int(FORK_REFILL * 4) + 1 {
		tick(&g, 0.25)
		g.piece.y = SPAWN_Y
	}
	testing.expect_value(t, g.fork, 1)
}

@(test)
cannot_turn_short_column :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 0, .Brown)
	testing.expect(t, !turn(&g, 0))
	testing.expect_value(t, g.fork, FORK_MAX)
}

@(test)
compost_sinks_and_drops_out_as_soil :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Brown, .Brown, .Compost)
	for _ in 0 ..< 3 * 60 {
		tick(&g, 1.0 / 60)
		g.piece.y = SPAWN_Y
	}
	testing.expect_value(t, g.soil, 1)
	testing.expect_value(t, height(&g, 0), 2)
	testing.expect_value(t, g.heap[0][0].kind, Kind.Brown)
	testing.expect_value(t, g.heap[0][1].kind, Kind.Brown)
}

@(test)
draws_without_crashing :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 7)
	f := new(Frame)
	defer free(f)
	for _ in 0 ..< 600 {
		tick(&g, 1.0 / 30)
		draw_game(f, &g)
	}
	resolve(f)
	testing.expect(t, f.rgba[0] != 0)
}
