#+build !js
package game

import "core:testing"

// Turns the bottom-left column, waiting for the fork to refill as needed.
turn_corner :: proc(g: ^Game) -> bool {
	for g.fork == 0 {
		tick(g, 0.25)
		g.piece.y = SPAWN_Y
	}
	return turn(g, CAT_COL)
}

@(test)
cat_comes_up_after_turns_in_a_row :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Brown, .Brown, .Brown)
	for _ in 0 ..< CAT_TURNS - 1 {
		testing.expect(t, turn_corner(&g))
	}
	testing.expect(t, !g.cat_found)
	testing.expect_value(t, g.corner_run, CAT_TURNS - 1)
	testing.expect(t, turn_corner(&g))
	testing.expect(t, g.cat_found)
	testing.expect_value(t, g.chat.line, CAT_FOUND_LINE)
	testing.expect_value(t, soil_per_compost(&g), f32(2))
}

@(test)
turning_another_column_resets_the_run :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.piece.col = 5
	put(&g, 0, .Brown, .Brown)
	put(&g, 3, .Brown, .Brown)
	for _ in 0 ..< CAT_TURNS - 1 {
		turn_corner(&g)
	}
	for g.fork == 0 {
		tick(&g, 0.25)
		g.piece.y = SPAWN_Y
	}
	testing.expect(t, turn(&g, 3))
	testing.expect_value(t, g.corner_run, 0)
	turn_corner(&g)
	testing.expect(t, !g.cat_found)
}

@(test)
last_house_ends_the_street_and_a_fresh_one_keeps_bests :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.soil = 10_000
	g.time = 1234
	g.cat_found = true
	g.best_cat = true
	g.muted = true
	for _ in 0 ..< HOUSES {
		buy(&g, SHOP_HOUSE)
	}
	testing.expect(t, g.finished)
	testing.expect_value(t, g.best_time, 1234)
	testing.expect_value(t, g.streets, 1)
	y := g.piece.y
	tick(&g, 0.25)
	testing.expect_value(t, g.piece.y, y) // the heap stops
	command(&g, .West)
	testing.expect(t, g.finished)
	command(&g, .Ok)
	testing.expect(t, !g.finished)
	testing.expect_value(t, g.houses, 0)
	testing.expect_value(t, g.soil, 0)
	testing.expect(t, !g.cat_found) // she has to be found again on each street
	testing.expect(t, g.best_cat && g.muted)
	testing.expect_value(t, g.best_time, 1234)
}

@(test)
start_over_needs_two_presses :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.soil = 50
	open_shop(&g)
	g.shop.cursor = SHOP_RESTART
	command(&g, .Ok)
	testing.expect_value(t, g.soil, 50)
	testing.expect(t, g.shop.confirm)
	command(&g, .Ok)
	testing.expect_value(t, g.soil, 0)
}

@(test)
mute_silences :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	open_shop(&g)
	g.shop.cursor = SHOP_SOUND
	g.sound_count = 0
	command(&g, .Ok)
	testing.expect(t, g.muted)
	g.sound_count = 0
	command(&g, .South)
	testing.expect_value(t, g.sound_count, 0)
}

@(test)
save_round_trips_and_rejects_damage :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 2, .Brown, .Green, .Compost)
	g.soil = 77
	g.levels[.Worms] = 2
	g.corner_run = 3
	g.warmth = 0.5
	g.tut.card = .Slime
	say(&g, NEIGHBOURS[0], BLOOM_LINES[0])
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	testing.expect_value(t, save_game(&g, buf), SAVE_CAP)

	h: Game
	init_game(&h, 99)
	testing.expect(t, load_game(&h, buf))
	testing.expect_value(t, h.soil, 77)
	testing.expect_value(t, h.levels[.Worms], 2)
	testing.expect_value(t, h.corner_run, 3)
	testing.expect_value(t, h.heap[2][1].kind, Kind.Green)
	testing.expect_value(t, h.chat.line, "")
	testing.expect_value(t, h.warmth, f32(0.5))
	testing.expect_value(t, h.tut.card, Tip.Slime)

	// A gap in a stack.
	bad: Game = g
	bad.heap[4][1] = Cell{kind = .Brown}
	testing.expect_value(t, save_game(&bad, buf), SAVE_CAP)
	testing.expect(t, !load_game(&h, buf))
	// Wrong length.
	testing.expect(t, !load_game(&h, buf[:SAVE_CAP - 1]))
	testing.expect_value(t, h.soil, 77) // unchanged by the failed loads
}
