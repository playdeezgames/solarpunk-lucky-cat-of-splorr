package game

// Lays out the screen: the bin on the left (a cross-section of the heap), the next scraps and the barrow
// beside it, the street on the right. Step 1 draws plain cells; the Anvil art replaces them in step 2.

CELL :: 16
BIN_X :: 24
BIN_FLOOR :: 184 // y of the bin floor; row r's top is BIN_FLOOR - (r+1)*CELL
BIN_W :: COLS * CELL
BIN_TOP :: BIN_FLOOR - ROWS * CELL
STREET_X :: 168

cell_x :: proc(col: int) -> int {return BIN_X + col * CELL}
cell_y :: proc(row: int) -> int {return BIN_FLOOR - (row + 1) * CELL}

// Specks per look, as (x, y) offsets inside a cell: a cheap texture until the Anvil art lands.
SPECKS := [LOOKS][6][2]int {
	{{3, 3}, {10, 4}, {6, 9}, {12, 11}, {2, 12}, {8, 6}},
	{{5, 2}, {12, 6}, {3, 8}, {9, 12}, {13, 2}, {7, 10}},
	{{2, 5}, {8, 2}, {11, 9}, {5, 13}, {13, 13}, {6, 6}},
}

draw_cell :: proc(f: ^Frame, x, y: int, kind: Kind, look: u8, slime := false, heat: f32 = 0) {
	base, speck: u8
	switch kind {
	case .Green:
		base, speck = COLOR_GREEN, COLOR_LIME
		if slime {
			base, speck = COLOR_TEAL, COLOR_CYAN
		}
	case .Brown:
		base, speck = COLOR_ORANGE, COLOR_YELLOW
	case .Compost:
		base, speck = COLOR_DARK, COLOR_PURPLE
	case .None:
		return
	}
	fill_rect(f, x + 1, y + 1, CELL - 2, CELL - 2, base)
	for s in SPECKS[int(look) % LOOKS] {
		fill_rect(f, x + s[0], y + s[1], 2, 2, speck)
	}
	if kind == .Green && heat > 0 && !slime {
		fill_rect(f, x + 1, y + CELL - 3, int(heat * f32(CELL - 2)), 2, COLOR_RED)
	}
	if slime {
		// Fumes.
		set_px(f, x + 4, y - 1, COLOR_LIME)
		set_px(f, x + 5, y - 3, COLOR_LIME)
		set_px(f, x + 10, y - 2, COLOR_LIME)
	}
}

draw_game :: proc(f: ^Frame, g: ^Game) {
	cls(f, COLOR_NAVY)
	buf: [32]u8

	// Sky and ground.
	fill_rect(f, 0, 0, SCREEN_W, BIN_TOP - 8, COLOR_NAVY)
	fill_rect(f, 0, BIN_FLOOR + 12, SCREEN_W, SCREEN_H - BIN_FLOOR - 12, COLOR_BLACK)

	// The bin: walls, the inside, the packed old layer under the floor.
	fill_rect(f, BIN_X - 4, BIN_TOP, 4, BIN_FLOOR - BIN_TOP + 12, COLOR_MID)
	fill_rect(f, BIN_X + BIN_W, BIN_TOP, 4, BIN_FLOOR - BIN_TOP + 12, COLOR_MID)
	fill_rect(f, BIN_X, BIN_TOP, BIN_W, BIN_FLOOR - BIN_TOP, COLOR_DARK)
	fill_rect(f, BIN_X, BIN_FLOOR, BIN_W, 12, COLOR_PURPLE)
	for col in 0 ..< COLS {
		if g.air[col] > 0 {
			// An aired column: a pale strip at the rim.
			fill_rect(f, cell_x(col) + 2, BIN_TOP - 3, CELL - 4, 2, COLOR_SKY)
		}
	}

	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			c := g.heap[col][row]
			draw_cell(f, cell_x(col), cell_y(row), c.kind, c.look, c.slime, c.heat)
		}
	}

	// Where the falling scrap will land, then the scrap itself.
	p := g.piece
	h := height(g, p.col)
	if h < ROWS {
		ly := cell_y(h)
		fill_rect(f, cell_x(p.col) + 1, ly + CELL - 2, CELL - 2, 1, COLOR_LIGHT)
	}
	py := BIN_FLOOR - int(p.y * CELL) - CELL
	draw_cell(f, cell_x(p.col), py, p.kind, p.look)

	// Next scraps.
	print(f, "NEXT", BIN_X + BIN_W + 10, BIN_TOP, COLOR_LIGHT)
	for i in 0 ..< QUEUE {
		q := g.queue[i]
		draw_cell(f, BIN_X + BIN_W + 12, BIN_TOP + 10 + i * 18, q.kind, q.look)
	}

	// The barrow under the hatch.
	fill_rect(f, BIN_X + BIN_W + 8, BIN_FLOOR, 28, 10, COLOR_MID)
	fill_rect(f, BIN_X + BIN_W + 10, BIN_FLOOR - 2, 24, 4, COLOR_DARK)

	// Top line: soil and fork strength.
	x := print(f, "SOIL ", 4, 4, COLOR_LIGHT) + 4
	x += print(f, commas(buf[:], g.soil), x, 4, COLOR_YELLOW)
	x += 12
	x += print(f, "FORK ", x, 4, COLOR_LIGHT)
	for i in 0 ..< FORK_MAX {
		fill_rect(f, x + i * 8, 5, 6, 6, COLOR_LIME if i < g.fork else COLOR_DARK)
	}
	if g.spilled > 0 {
		sx := print(f, "SPILLED ", STREET_X, 4, COLOR_LIGHT) + STREET_X
		print(f, commas(buf[:], g.spilled), sx, 4, COLOR_RED)
	}

	// The street (grey for now; it greens in step 3).
	for i in 0 ..< 8 {
		hx := STREET_X + 4 + i * 26
		fill_rect(f, hx, BIN_FLOOR - 40, 22, 52, COLOR_MID)
		fill_rect(f, hx + 2, BIN_FLOOR - 46, 18, 6, COLOR_DARK)
		fill_rect(f, hx + 4, BIN_FLOOR - 32, 6, 6, COLOR_LIGHT)
		fill_rect(f, hx + 12, BIN_FLOOR - 32, 6, 6, COLOR_LIGHT)
		fill_rect(f, hx + 8, BIN_FLOOR - 4, 6, 16, COLOR_DARK)
	}

	print(f, "LEFT/RIGHT STEER  DOWN DROP  UP TURN", 4, SCREEN_H - 10, COLOR_MID)
}
