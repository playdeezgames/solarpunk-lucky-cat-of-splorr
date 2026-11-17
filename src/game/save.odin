package game

// Saves: the whole Game as raw bytes behind a small header. A save from another build (another version
// or size) is not loaded and the page starts a fresh street; a save that loads is checked field by field
// first, so a damaged one cannot break the game. The chat strings point into the build's data, so they
// are blanked in the save. Bump SAVE_VERSION whenever Game's layout changes (old saves are then ignored).

SAVE_MAGIC :: u32(0x504D_4F43) // "COMP"
SAVE_VERSION :: u32(2) // 2: heap heat, mulch, special scraps, the tutorial (November 17, 2026)

Save_Header :: struct {
	magic:   u32,
	version: u32,
	size:    u32,
}

SAVE_CAP :: size_of(Save_Header) + size_of(Game)

save_game :: proc(g: ^Game, out: []u8) -> int {
	if len(out) < SAVE_CAP {
		return 0
	}
	tmp := new(Game)
	defer free(tmp)
	tmp^ = g^
	tmp.chat.who, tmp.chat.line, tmp.chat.t = "", "", 0
	tmp.sound_count = 0
	h := Save_Header{SAVE_MAGIC, SAVE_VERSION, u32(size_of(Game))}
	copy(out, (cast([^]u8)&h)[:size_of(Save_Header)])
	copy(out[size_of(Save_Header):], (cast([^]u8)tmp)[:size_of(Game)])
	return SAVE_CAP
}

load_game :: proc(g: ^Game, data: []u8) -> bool {
	if len(data) != SAVE_CAP {
		return false
	}
	h: Save_Header
	copy((cast([^]u8)&h)[:size_of(Save_Header)], data)
	if h.magic != SAVE_MAGIC || h.version != SAVE_VERSION || h.size != u32(size_of(Game)) {
		return false
	}
	tmp := new(Game)
	defer free(tmp)
	copy((cast([^]u8)tmp)[:size_of(Game)], data[size_of(Save_Header):])
	// Never trust the string headers in the bytes.
	tmp.chat.who, tmp.chat.line, tmp.chat.t = "", "", 0
	if !save_is_sane(tmp) {
		return false
	}
	g^ = tmp^
	g.sound_count = 0
	g.shop.open = false
	return true
}

finite :: proc(v: f32, lo, hi: f32) -> bool {
	return v >= lo && v <= hi // false for NaN
}

save_is_sane :: proc(g: ^Game) -> bool {
	for col in 0 ..< COLS {
		ended := false
		for row in 0 ..< ROWS {
			c := g.heap[col][row]
			if u8(c.kind) > u8(max(Kind)) || u8(c.sort) > u8(max(Sort)) || int(c.look) >= LOOKS || c.fed > 1 || !finite(c.worth, 0, 100) {
				return false
			}
			if c.kind == .None {
				ended = true
			} else if ended {
				return false // a gap in a stack
			}
			if !finite(c.heat, 0, 2) || !finite(c.pack, 0, 1000) {
				return false
			}
		}
		if !finite(g.air[col], 0, 100) || !finite(g.forked[col], 0, 1) || !finite(g.hatch[col], 0, 10) {
			return false
		}
	}
	pieces := [QUEUE + 1]Piece{g.piece, g.queue[0], g.queue[1], g.queue[2]}
	for p in pieces {
		if p.kind != .Green && p.kind != .Brown && p.kind != .Junk || u8(p.sort) > u8(max(Sort)) || int(p.look) >= LOOKS {
			return false
		}
	}
	if g.piece.col < 0 || g.piece.col >= COLS || !finite(g.piece.y, 0, SPAWN_Y) {
		return false
	}
	for lv in g.levels {
		if lv < 0 || lv > UPGRADE_MAX {
			return false
		}
	}
	if g.houses < 0 || g.houses > HOUSES || g.fork < 0 || g.fork > fork_max(g) || !finite(g.fork_t, 0, 10) {
		return false
	}
	if !finite(g.warmth, 0, 1) || g.mulched < 0 || g.packets < 0 {
		return false
	}
	t := g.tut
	if u8(t.step) > u8(max(Step)) || u8(t.card) > u8(max(Tip)) || t.script < 0 || t.script > len(SCRIPT) || t.count < 0 {
		return false
	}
	if g.soil < 0 || g.compost < 0 || g.spilled < 0 || !finite(g.soil_frac, 0, 1) || !finite(g.sink_t, 0, 1) {
		return false
	}
	if g.corner_run < 0 || g.corner_run >= CAT_TURNS || !finite(g.cat_t, 0, 1e9) {
		return false
	}
	if !(g.time >= 0 && g.time < 1e9) || !(g.best_time >= 0 && g.best_time < 1e9) || g.streets < 0 {
		return false
	}
	if g.finished != (g.houses == HOUSES) || g.shop.cursor < 0 || g.shop.cursor >= SHOP_ROWS {
		return false
	}
	return true
}
