#+build !js
package game

// Tests for the heap's heat, mulch, the special scraps and the tutorial (November 17, 2026).

import "core:testing"

run :: proc(g: ^Game, seconds: f32) {
	for _ in 0 ..< int(seconds * 60) {
		tick(g, 1.0 / 60)
		g.piece.y = SPAWN_Y
	}
}

@(test)
rots_warm_the_heap_and_make_compost_worth_more :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	testing.expect_value(t, warm_mult(&g), f32(1))
	put(&g, 0, .Brown, .Green)
	run(&g, 1 / HEAT_RATE + 0.2)
	testing.expect(t, g.warmth > 0)
	g.warmth = 1
	put(&g, 2, .Brown, .Green)
	g.heap[2][1].heat = 0.999
	run(&g, 0.1)
	testing.expect(t, g.heap[2][0].kind == .Compost)
	testing.expect(t, abs(g.heap[2][0].worth - 3 * soil_per_compost(&g)) < 0.05)
	// And it cools when nothing rots.
	w := g.warmth
	run(&g, 5)
	testing.expect(t, g.warmth < w)
}

@(test)
mulch_banks_nothing :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Compost)
	g.heap[0][0].mulch = true
	run(&g, 2)
	testing.expect_value(t, height(&g, 0), 0)
	testing.expect_value(t, g.soil, 0)
}

@(test)
egg_box_feeds_two_greens :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 1, .Brown)
	g.heap[1][0].sort = .Egg_Box
	put(&g, 0, .Green)
	g.heap[0][0].heat = 0.999
	run(&g, 0.05)
	testing.expect_value(t, g.heap[1][0].kind, Kind.Brown) // soggy, still there
	testing.expect_value(t, g.heap[1][0].fed, u8(1))
	put(&g, 2, .Green)
	g.heap[2][0].heat = 0.999
	run(&g, 0.05)
	testing.expect_value(t, g.heap[1][0].kind, Kind.Compost)
	testing.expect_value(t, g.compost, 3)
}

@(test)
citrus_keeps_greens_from_slime :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Green, .Green, .Green)
	g.heap[0][1].sort = .Citrus
	run(&g, SLIME_TIME + 1)
	for r in 0 ..< 3 {
		testing.expect(t, !g.heap[0][r].slime)
	}
	// Without the citrus the middle one would go slimy.
	put(&g, 2, .Green, .Green, .Green)
	run(&g, SLIME_TIME + 1)
	testing.expect(t, g.heap[2][1].slime)
}

@(test)
grounds_rot_twice_as_fast :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Brown, .Green)
	put(&g, 2, .Brown, .Green)
	g.heap[2][1].sort = .Grounds
	run(&g, 1)
	testing.expect(t, abs(g.heap[2][1].heat - 2 * g.heap[0][1].heat) < 1e-3)
}

@(test)
packet_holds_up_compost_until_forked_out :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Junk, .Compost)
	g.heap[0][1].worth = 1
	run(&g, 3)
	testing.expect_value(t, g.heap[0][0].kind, Kind.Junk) // the compost cannot get past
	testing.expect_value(t, g.soil, 0)
	testing.expect(t, turn(&g, 0))
	testing.expect_value(t, g.packets, 1)
	run(&g, 1)
	testing.expect_value(t, g.soil, 1)
	testing.expect_value(t, height(&g, 0), 0)
}

@(test)
packet_blows_away_in_the_end :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Junk, .Brown)
	run(&g, PACKET_WEATHER + 1)
	testing.expect(t, g.heap[0][0].kind != .Junk)
}

@(test)
special_scraps_wait_for_their_neighbours :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	for _ in 0 ..< 500 {
		p := new_scrap(&g)
		testing.expect(t, p.sort == .Plain && p.kind != .Junk)
	}
	g.houses = UNLOCK_PACKET
	seen: bit_set[Sort]
	junk := false
	for _ in 0 ..< 2000 {
		p := new_scrap(&g)
		seen += {p.sort}
		junk ||= p.kind == .Junk
	}
	testing.expect(t, seen == {.Plain, .Grounds, .Egg_Box, .Citrus})
	testing.expect(t, junk)
}

@(test)
tutorial_walks_through_the_first_steps :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 3, guided = true)
	testing.expect_value(t, g.tut.card, Tip.Welcome)
	tick(&g, 1)
	testing.expect_value(t, g.time, f64(0)) // the card pauses the heap
	command(&g, .Ok)
	testing.expect_value(t, g.tut.card, Tip.None)
	// A brown first, then a green; land the green beside the brown.
	testing.expect_value(t, g.piece.kind, Kind.Brown)
	command(&g, .Ok)
	testing.expect_value(t, g.tut.step, Step.Land_Green)
	for g.waiting > 0 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.piece.kind, Kind.Green)
	command(&g, .East)
	command(&g, .Ok)
	testing.expect_value(t, g.tut.step, Step.Rot)
	// It rots, the compost drops out, and the heat card shows.
	for _ in 0 ..< 60 * 30 {
		tick(&g, 1.0 / 60)
		g.piece.y = SPAWN_Y
		if g.tut.card != .None {
			break
		}
	}
	testing.expect_value(t, g.tut.step, Step.Keep_Going)
	testing.expect_value(t, g.tut.card, Tip.Warmth)
	testing.expect(t, g.soil > 0)
	command(&g, .Ok)
	g.tut.step = .Turn
	put(&g, 3, .Brown, .Brown)
	testing.expect(t, turn(&g, 3))
	testing.expect_value(t, g.tut.step, Step.Shed)
	g.soil = 100
	testing.expect(t, buy(&g, SHOP_HOUSE))
	testing.expect(t, g.tut.done)
	testing.expect_value(t, g.tut.card, Tip.Ready)
}

@(test)
cards_show_once_and_queue :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 3)
	tut_show(&g, .Slime)
	tut_show(&g, .Spill)
	tut_show(&g, .Slime)
	testing.expect_value(t, g.tut.card, Tip.Slime)
	command(&g, .Ok)
	testing.expect_value(t, g.tut.card, Tip.Spill)
	command(&g, .Ok)
	testing.expect_value(t, g.tut.card, Tip.None)
	// A fresh street keeps what has been read.
	new_street(&g)
	tut_show(&g, .Slime)
	testing.expect_value(t, g.tut.card, Tip.None)
	testing.expect(t, g.tut.done)
}
