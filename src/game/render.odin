package game

// Lays out the screen: the bin on the left (a cross-section of the heap), the next scraps and the barrow
// beside it, the street of eight houses on the right. Art is Claude's, drawn in the Anvil (gfx.odin).

CELL :: 16
BIN_X :: 24
BIN_FLOOR :: 184 // y of the bin floor; row r's top is BIN_FLOOR - (r+1)*CELL
BIN_W :: COLS * CELL
BIN_TOP :: BIN_FLOOR - ROWS * CELL
STREET_X :: 168
HOUSE_STEP :: 26

cell_x :: proc(col: int) -> int {return BIN_X + col * CELL}
cell_y :: proc(row: int) -> int {return BIN_FLOOR - (row + 1) * CELL}

// Slimy greens: green to teal, lime to cyan, the teal outline to navy.
SLIME :: Remap{0, 1, 2, 3, 4, 11, 7, 8, 8, 9, 10, 11, 12, 13, 14, 15}
// A grey street: every colour to a grey.
GREY :: Remap{0, 15, 14, 14, 13, 13, 14, 14, 15, 15, 15, 13, 13, 13, 14, 15}

scrap_gfx :: proc(kind: Kind, look: u8) -> (Gfx, bool) {
	l := int(look) % LOOKS
	switch kind {
	case .Green:
		return Gfx(int(Gfx.Green_Peel) + l), true
	case .Brown:
		return Gfx(int(Gfx.Brown_Leaf) + l), true
	case .Compost:
		return Gfx(int(Gfx.Compost_A) + l), true
	case .None:
	}
	return .Sun, false
}

draw_cell :: proc(f: ^Frame, x, y: int, kind: Kind, look: u8, slime := false, heat: f32 = 0) {
	pic, ok := scrap_gfx(kind, look)
	if !ok {
		return
	}
	draw_gfx(f, pic, x, y, remap = SLIME if slime else IDENTITY)
	if kind == .Green && heat > 0 && !slime {
		// Heat: a bar along the bottom, yellow turning red as it nears rotting.
		w := int(heat * f32(CELL - 4))
		fill_rect(f, x + 2, y + CELL - 3, w, 1, COLOR_RED if heat > 0.66 else COLOR_ORANGE if heat > 0.33 else COLOR_YELLOW)
	}
	if slime {
		// Fumes.
		set_px(f, x + 4, y - 1, COLOR_LIME)
		set_px(f, x + 5, y - 3, COLOR_LIME)
		set_px(f, x + 10, y - 2, COLOR_LIME)
		set_px(f, x + 11, y - 4, COLOR_LIME)
	}
}

// One house of the street; `bloomed` houses get their colour, a garden and their solarpunk feature.
draw_house :: proc(f: ^Frame, i: int, bloomed: bool) {
	x := STREET_X + 4 + i * HOUSE_STEP
	feature := i % 5
	remap := IDENTITY if bloomed else GREY
	roof := Gfx.Roof
	if bloomed && feature == 0 {
		roof = .Roof_Solar
	} else if bloomed && feature == 4 {
		roof = .Roof_Farm
	}
	if bloomed && feature == 3 {
		draw_gfx(f, .Turbine, x, BIN_FLOOR - 48)
	}
	draw_gfx(f, roof, x, BIN_FLOOR - 32, remap = remap)
	draw_gfx(f, .Wall, x, BIN_FLOOR - 16, remap = remap)
	if bloomed && feature == 1 {
		draw_gfx(f, .Vines, x, BIN_FLOOR - 16)
	}
	if bloomed && feature == 2 {
		draw_gfx(f, .Barrel, x + 14, BIN_FLOOR - 16)
	}
	draw_gfx(f, .Garden_Bloom if bloomed else .Garden_Bare, x, BIN_FLOOR - 4)
}

draw_game :: proc(f: ^Frame, g: ^Game) {
	buf: [32]u8

	// Sky, sun and ground.
	cls(f, COLOR_NAVY)
	draw_gfx(f, .Sun, SCREEN_W - 28, 18)
	fill_rect(f, 0, BIN_FLOOR + 6, SCREEN_W, SCREEN_H - BIN_FLOOR - 6, COLOR_BLACK)
	fill_rect(f, 0, BIN_FLOOR + 4, SCREEN_W, 2, COLOR_DARK)

	// The bin: plank walls, the dark inside, the packed old layer under the floor.
	for y := BIN_TOP; y < BIN_FLOOR + 12; y += 8 {
		fill_rect(f, BIN_X - 4, y, 4, 7, COLOR_ORANGE)
		fill_rect(f, BIN_X + BIN_W, y, 4, 7, COLOR_ORANGE)
		fill_rect(f, BIN_X - 4, y + 7, 4, 1, COLOR_RED)
		fill_rect(f, BIN_X + BIN_W, y + 7, 4, 1, COLOR_RED)
	}
	fill_rect(f, BIN_X, BIN_TOP, BIN_W, BIN_FLOOR - BIN_TOP, COLOR_BLACK)
	fill_rect(f, BIN_X, BIN_FLOOR, BIN_W, 12, COLOR_PURPLE)
	for x := BIN_X + 3; x < BIN_X + BIN_W; x += 7 {
		set_px(f, x, BIN_FLOOR + 3 + (x % 3) * 2, COLOR_DARK)
	}
	for col in 0 ..< COLS {
		if g.air[col] > 0 {
			// An aired column: a pale strip at the rim, shrinking as the air runs out.
			w := int(g.air[col] / AIR_TIME * f32(CELL - 4))
			fill_rect(f, cell_x(col) + 2, BIN_TOP - 3, w, 2, COLOR_SKY)
		}
	}

	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			c := g.heap[col][row]
			draw_cell(f, cell_x(col), cell_y(row), c.kind, c.look, c.slime, c.heat)
		}
		if g.air[col] > AIR_TIME - 0.35 {
			// The fork, just after a turn, stuck in the top of the column.
			top := max(height(g, col), 1)
			draw_gfx(f, .Fork, cell_x(col), cell_y(top - 1) - 10)
		}
	}

	// Where the falling scrap will land, then the scrap itself.
	p := g.piece
	h := height(g, p.col)
	if h < ROWS {
		ly := cell_y(h)
		fill_rect(f, cell_x(p.col) + 2, ly + CELL - 1, CELL - 4, 1, COLOR_LIGHT)
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
	draw_gfx(f, .Barrow, BIN_X + BIN_W + 10, BIN_FLOOR - 10)

	// The street.
	for i in 0 ..< HOUSES {
		draw_house(f, i, i < g.houses)
	}

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

	print(f, "LEFT/RIGHT STEER  DOWN DROP  UP TURN", 4, SCREEN_H - 10, COLOR_MID)
}
