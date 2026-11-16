package game

// The hidden lucky cat and the end of a street. The heap sits on an old packed layer. Turning the
// bottom-left column CAT_TURNS times in a row (no other column turned in between) cracks it open and the
// cat comes up: from then on soil per compost is doubled, and her statue stands on the street. Old Mo
// hints at her in the chatter. The user's decisions (DESIGN.md); the count is Claude's.

CAT_TURNS :: 6
CRACK_SHOWS :: 2 // turns in a row before the first crack shows
CAT_COL :: 0

turned_corner :: proc(g: ^Game, col: int) {
	if g.cat_found {
		return
	}
	if col != CAT_COL {
		g.corner_run = 0
		return
	}
	g.corner_run += 1
	if g.corner_run >= CAT_TURNS {
		g.cat_found = true
		g.cat_t = 0
		g.best_cat = true
		play(g, .Cat)
		say(g, OLD_MO, CAT_FOUND_LINE)
	} else if g.corner_run >= CRACK_SHOWS {
		play(g, .Crack)
	}
}

finish_street :: proc(g: ^Game) {
	g.finished = true
	g.shop.open = false
	g.streets += 1
	if g.best_time == 0 || g.time < g.best_time {
		g.best_time = g.time
	}
	play(g, .Green)
}

// A fresh grey street; the bests and the sound setting stay.
new_street :: proc(g: ^Game) {
	best, cat, streets, muted := g.best_time, g.best_cat, g.streets, g.muted
	init_game(g, rand_u64(g))
	g.best_time, g.best_cat, g.streets, g.muted = best, cat, streets, muted
	g.chat.lands = LEARN_LANDS // they know the controls by now
}
