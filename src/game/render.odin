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

// Mulch: compost gone grey.
MULCH :: Remap{0, 15, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 13, 14}
// A soggy egg box (it has fed one green): darker, wetter card.
SOGGY :: Remap{0, 15, 2, 1, 3, 5, 6, 7, 8, 9, 10, 11, 14, 13, 14, 15}

scrap_gfx :: proc(kind: Kind, sort: Sort, look: u8) -> (Gfx, bool) {
	l := int(look) % LOOKS
	switch kind {
	case .Green:
		#partial switch sort {
		case .Grounds:
			return .Green_Grounds, true
		case .Citrus:
			return .Green_Citrus, true
		}
		return Gfx(int(Gfx.Green_Peel) + l), true
	case .Brown:
		if sort == .Egg_Box {
			return .Brown_Egg_Box, true
		}
		return Gfx(int(Gfx.Brown_Leaf) + l), true
	case .Compost:
		return Gfx(int(Gfx.Compost_A) + l), true
	case .Junk:
		return .Junk_Packet, true
	case .None:
	}
	return .Sun, false
}

piece_cell :: proc(p: Piece) -> Cell {
	return Cell{kind = p.kind, sort = p.sort, look = p.look}
}

draw_cell :: proc(f: ^Frame, x, y: int, c: Cell) {
	pic, ok := scrap_gfx(c.kind, c.sort, c.look)
	if !ok {
		return
	}
	slime, heat := c.slime, c.heat
	remap := IDENTITY
	switch {
	case slime:
		remap = SLIME
	case c.mulch:
		remap = MULCH
	case c.fed > 0:
		remap = SOGGY
	}
	draw_gfx(f, pic, x, y, remap = remap)
	if c.kind == .Green && heat > 0 && !slime {
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

	// Sky, sun and ground: smog over a grey street, clearing to blue as it greens.
	SKIES :: [HOUSES + 1]u8{COLOR_DARK, COLOR_DARK, COLOR_NAVY, COLOR_NAVY, COLOR_NAVY, COLOR_BLUE, COLOR_BLUE, COLOR_BLUE, COLOR_SKY}
	skies := SKIES
	cls(f, skies[g.houses])
	draw_gfx(f, .Sun, SCREEN_W - 28, 22, remap = GREY if g.houses < 2 else IDENTITY)
	fill_rect(f, 0, 0, SCREEN_W, 15, COLOR_BLACK)
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
	draw_packed_corner(f, g)
	for col in 0 ..< COLS {
		if g.air[col] > 0 {
			// An aired column: a pale strip at the rim, shrinking as the air runs out.
			w := int(g.air[col] / air_time(g) * f32(CELL - 4))
			fill_rect(f, cell_x(col) + 2, BIN_TOP - 3, w, 2, COLOR_SKY)
		}
	}

	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			draw_cell(f, cell_x(col), cell_y(row), g.heap[col][row])
		}
		if g.forked[col] > 0 {
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
	if g.waiting <= 0 {
		py := BIN_FLOOR - int(p.y * CELL) - CELL
		draw_cell(f, cell_x(p.col), py, piece_cell(p))
	} else {
		// On its way: a dotted marker over the column it will arrive at.
		for i in 0 ..< 3 {
			if int(g.waiting * 6) % 3 != i {
				fill_rect(f, cell_x(p.col) + 3 + i * 4, BIN_TOP - 10, 2, 2, COLOR_LIGHT)
			}
		}
	}

	// Next scraps.
	fill_rect(f, BIN_X + BIN_W + 6, BIN_TOP - 3, 30, 66, COLOR_BLACK)
	print(f, "NEXT", BIN_X + BIN_W + 9, BIN_TOP, COLOR_LIGHT)
	for i in 0 ..< QUEUE {
		q := g.queue[i]
		draw_cell(f, BIN_X + BIN_W + 13, BIN_TOP + 10 + i * 17, piece_cell(q))
	}
	draw_heat(f, g)

	// The barrow under the hatch.
	draw_gfx(f, .Barrow, BIN_X + BIN_W + 10, BIN_FLOOR - 10)

	// The street, and the cat once she is found.
	for i in 0 ..< HOUSES {
		draw_house(f, i, i < g.houses)
	}
	if g.cat_found {
		draw_cat(f, g)
	}

	// Top line: soil and fork strength.
	x := print(f, "SOIL ", 4, 4, COLOR_LIGHT) + 4
	x += print(f, commas(buf[:], g.soil), x, 4, COLOR_YELLOW)
	if g.cat_found {
		x += print(f, " X2", x, 4, COLOR_WHITE)
	}
	x += 12
	x += print(f, "FORK ", x, 4, COLOR_LIGHT)
	for i in 0 ..< fork_max(g) {
		fill_rect(f, x + i * 8, 5, 6, 6, COLOR_LIME if i < g.fork else COLOR_DARK)
	}
	// The street's progress and the next house's price.
	sx := STREET_X + 20
	sx += print(f, "STREET ", sx, 4, COLOR_LIGHT)
	sx += print(f, commas(buf[:], i64(g.houses)), sx, 4, COLOR_LIME)
	sx += print(f, "/8", sx, 4, COLOR_LIGHT) + 12
	if price, ok := next_house_price(g); ok {
		sx += print(f, "NEXT ", sx, 4, COLOR_LIGHT)
		sx += print(f, commas(buf[:], price), sx, 4, COLOR_YELLOW if g.soil >= price else COLOR_MID)
		print(f, " E", sx, 4, COLOR_LIGHT if g.soil >= price else COLOR_MID)
	}

	// Bottom lines: the tutorial's goal while it runs, then the neighbours.
	if !g.tut.done {
		print(f, ">", 4, SCREEN_H - 20, COLOR_YELLOW)
		print_wrapped(f, GOALS[g.tut.step], 12, SCREEN_H - 20, (SCREEN_W - 16) / GLYPH_W, COLOR_WHITE)
	} else if g.chat.t > 0 {
		print(f, g.chat.who, 4, SCREEN_H - 20, COLOR_LIME)
		print(f, g.chat.line, 4, SCREEN_H - 10, COLOR_WHITE)
	}
	if g.spilled > 0 {
		sp := print(f, "SPILLED ", BIN_X, BIN_TOP - 12, COLOR_MID) + BIN_X
		print(f, commas(buf[:], g.spilled), sp, BIN_TOP - 12, COLOR_RED)
	}

	if g.shop.open {
		draw_shop(f, g)
	}
	if g.finished {
		draw_end(f, g)
	}
	if g.tut.card != .None {
		draw_card(f, g, g.tut.card)
	}
}

// The heap's heat: a thermometer between the next scraps and the barrow, and the soil multiplier.
draw_heat :: proc(f: ^Frame, g: ^Game) {
	buf: [8]u8
	X :: BIN_X + BIN_W + 6
	Y :: BIN_TOP + 66
	fill_rect(f, X, Y, 30, 56, COLOR_BLACK)
	print(f, "HEAT", X + 3, Y + 3, COLOR_LIGHT)
	BAR_H :: 28
	fill_rect(f, X + 11, Y + 14, 8, BAR_H, COLOR_DARK)
	h := int(g.warmth * BAR_H + 0.5)
	col: u8 = COLOR_YELLOW if g.warmth < 0.34 else COLOR_ORANGE if g.warmth < 0.67 else COLOR_RED
	fill_rect(f, X + 11, Y + 14 + BAR_H - h, 8, h, col)
	// x1.0 to x3.0, one decimal.
	m := int(warm_mult(g) * 10 + 0.5)
	n := 0
	buf[n] = 'X'; n += 1
	buf[n] = u8('0' + m / 10); n += 1
	buf[n] = '.'; n += 1
	buf[n] = u8('0' + m % 10); n += 1
	print(f, string(buf[:n]), X + 3, Y + 45, COLOR_WHITE)
}

// A tutorial card over the street: a title (with the scrap it is about), the text, and how to go on.
draw_card :: proc(f: ^Frame, g: ^Game, tip: Tip) {
	card := CARDS[tip]
	X :: STREET_X - 8
	Y :: 20
	W :: SCREEN_W - X - 6
	H :: 160
	fill_rect(f, X - 1, Y - 1, W + 2, H + 2, COLOR_YELLOW)
	fill_rect(f, X, Y, W, H, COLOR_BLACK)
	tx := X + 8
	if card.pic != .None {
		c := Cell{kind = card.pic, sort = card.sort}
		draw_cell(f, X + 8, Y + 6, c)
		tx += 22
	}
	print(f, card.title, tx, Y + 10, COLOR_YELLOW)
	print_wrapped(f, card.text, X + 8, Y + 30, (W - 16) / GLYPH_W, COLOR_WHITE)
	print(f, "SPACE: GOT IT", X + 8, Y + H - 14, COLOR_LIME)
}

// The shop, over the street: the next house, the four upgrades, Back; the chosen row's description.
draw_shop :: proc(f: ^Frame, g: ^Game) {
	buf: [32]u8
	X :: STREET_X - 8
	Y :: 20
	W :: SCREEN_W - X - 6
	H :: 164
	ROW_H :: 12
	fill_rect(f, X - 1, Y - 1, W + 2, H + 2, COLOR_LIGHT)
	fill_rect(f, X, Y, W, H, COLOR_BLACK)
	print(f, "THE BIN SHED", X + 8, Y + 6, COLOR_YELLOW)
	sx := X + W - 8 - text_width("SOIL ") - text_width(commas(buf[:], g.soil))
	sx += print(f, "SOIL ", sx, Y + 6, COLOR_LIGHT)
	print(f, commas(buf[:], g.soil), sx, Y + 6, COLOR_YELLOW)

	for row in 0 ..< SHOP_ROWS {
		y := Y + 20 + row * ROW_H
		sel := row == g.shop.cursor
		if sel {
			fill_rect(f, X + 4, y - 3, W - 8, ROW_H, COLOR_DARK)
			print(f, ">", X + 8, y, COLOR_YELLOW)
		}
		name: string
		price: i64
		ok: bool
		level := -1
		switch {
		case row == SHOP_HOUSE:
			name = "GREEN THE NEXT HOUSE"
			price, ok = next_house_price(g)
		case row == SHOP_BACK:
			name = "BACK TO THE HEAP"
		case row == SHOP_SOUND:
			name = "SOUND OFF" if g.muted else "SOUND ON"
		case row == SHOP_HELP:
			name = "HOW TO PLAY"
		case row == SHOP_RESTART:
			name = "SURE? SPACE AGAIN" if g.shop.confirm else "START A FRESH STREET"
		case:
			u := Upgrade(row - 1)
			name = UPGRADE_NAMES[u]
			price, ok = upgrade_price(g, u)
			level = g.levels[u]
		}
		print(f, name, X + 18, y, COLOR_WHITE if sel else COLOR_LIGHT)
		if level >= 0 {
			for i in 0 ..< UPGRADE_MAX {
				fill_rect(f, X + 100 + i * 7, y + 1, 5, 5, COLOR_LIME if i < level else COLOR_DARK)
			}
		}
		if row < SHOP_SOUND {
			label := commas(buf[:], price) if ok else "DONE"
			col: u8 = COLOR_MID
			if ok {
				col = COLOR_YELLOW if g.soil >= price else COLOR_RED
			}
			print(f, label, X + W - 10 - text_width(label), y, col)
		}
	}

	text := "Back to turning."
	switch {
	case g.shop.cursor == SHOP_HOUSE:
		text = "A garden and a neighbour. Scraps come faster." if g.houses < HOUSES else "Every house is green."
	case g.shop.cursor == SHOP_SOUND:
		text = "Blips and plops."
	case g.shop.cursor == SHOP_HELP:
		text = "The whole bin on one card."
	case g.shop.cursor == SHOP_RESTART:
		text = "Back to a grey street. Your best time stays."
	case g.shop.cursor == SHOP_BACK:
	case:
		text = UPGRADE_TEXT[Upgrade(g.shop.cursor - 1)]
	}
	print_wrapped(f, text, X + 8, Y + H - 34, (W - 16) / GLYPH_W, COLOR_LIGHT)
	print(f, "UP/DOWN  SPACE BUY  ESC CLOSE", X + 8, Y + H - 12, COLOR_MID)
}

// Prints text broken at spaces into lines of at most `width` characters, 10 pixels apart.
print_wrapped :: proc(f: ^Frame, text: string, x, y, width: int, color: u8) {
	rest := text
	line_y := y
	for len(rest) > 0 {
		n := len(rest)
		if n > width {
			n = width
			for n > 0 && rest[n] != ' ' {
				n -= 1
			}
			if n == 0 {
				n = width
			}
		}
		print(f, rest[:n], x, line_y, color)
		rest = rest[n:]
		for len(rest) > 0 && rest[0] == ' ' {
			rest = rest[1:]
		}
		line_y += 10
	}
}

// Cracks in the packed layer under the bottom-left column as it is turned again and again, then the
// hole the cat came out of.
CRACKS := [CAT_TURNS][4][2]int {
	{{7, 0}, {7, 1}, {8, 2}, {8, 3}},
	{{8, 4}, {7, 5}, {6, 6}, {9, 4}},
	{{10, 5}, {11, 6}, {5, 7}, {4, 8}},
	{{12, 7}, {3, 9}, {12, 8}, {13, 9}},
	{{2, 10}, {14, 10}, {6, 8}, {10, 8}},
	{{1, 11}, {15, 11}, {7, 9}, {9, 9}},
}

draw_packed_corner :: proc(f: ^Frame, g: ^Game) {
	x := cell_x(CAT_COL)
	if g.cat_found {
		fill_rect(f, x + 2, BIN_FLOOR + 1, CELL - 4, 10, COLOR_BLACK)
		return
	}
	for i in 0 ..< g.corner_run {
		for p in CRACKS[i] {
			set_px(f, x + p[0], BIN_FLOOR + p[1], COLOR_BLACK)
		}
	}
}

CAT_SEAT_X :: BIN_X + BIN_W + 28
CAT_SEAT_Y :: BIN_FLOOR - 16
CAT_JUMP :: 1.0 // seconds for her jump out of the floor

// Gold, for the statue: white to yellow, light to orange.
GOLD :: Remap{0, 1, 2, 3, 3, 5, 6, 7, 8, 9, 10, 11, 4, 3, 14, 15}

// The cat leaps out of the floor to sit by the barrow, waving; at the end she stands in gold on a plinth.
draw_cat :: proc(f: ^Frame, g: ^Game) {
	if g.finished {
		fill_rect(f, CAT_SEAT_X - 1, CAT_SEAT_Y + 6, 18, 10, COLOR_LIGHT)
		fill_rect(f, CAT_SEAT_X, CAT_SEAT_Y + 7, 16, 9, COLOR_MID)
		draw_gfx(f, .Cat, CAT_SEAT_X, CAT_SEAT_Y - 10, remap = GOLD)
		return
	}
	x, y := CAT_SEAT_X, CAT_SEAT_Y
	if g.cat_t < CAT_JUMP {
		t := g.cat_t / CAT_JUMP
		x0, y0 := f32(cell_x(CAT_COL)), f32(BIN_FLOOR)
		x = int(x0 + (f32(CAT_SEAT_X) - x0) * t)
		y = int(y0 + (f32(CAT_SEAT_Y) - y0) * t - 90 * t * (1 - t) * 4 / 2)
	}
	wave := int(g.cat_t * 3) % 2 == 1
	draw_gfx(f, .Cat_Wave if wave else .Cat, x, y)
}

// mm:ss
clock :: proc(buf: []u8, seconds: f64) -> string {
	s := int(seconds)
	m := s / 60
	s %= 60
	n := 0
	tmp: [16]u8
	digits := commas(tmp[:], i64(m))
	n += copy(buf[n:], digits)
	buf[n] = ':'
	n += 1
	buf[n] = u8('0' + s / 10)
	buf[n + 1] = u8('0' + s % 10)
	return string(buf[:n + 2])
}

draw_end :: proc(f: ^Frame, g: ^Game) {
	buf: [32]u8
	X :: STREET_X - 8
	Y :: 24
	W :: SCREEN_W - X - 6
	H :: 96
	fill_rect(f, X - 1, Y - 1, W + 2, H + 2, COLOR_LIME)
	fill_rect(f, X, Y, W, H, COLOR_BLACK)
	print(f, "ASH STREET IS GREEN", X + 8, Y + 8, COLOR_LIME)
	x := print(f, "TIME ", X + 8, Y + 24, COLOR_LIGHT) + X + 8
	x += print(f, clock(buf[:], g.time), x, Y + 24, COLOR_YELLOW) + 12
	x += print(f, "BEST ", x, Y + 24, COLOR_LIGHT)
	print(f, clock(buf[:], g.best_time), x, Y + 24, COLOR_YELLOW)
	x = print(f, "COMPOST ", X + 8, Y + 36, COLOR_LIGHT) + X + 8
	print(f, commas(buf[:], g.compost), x, Y + 36, COLOR_YELLOW)
	x = print(f, "MULCH ", X + 8, Y + 46, COLOR_LIGHT) + X + 8
	x += print(f, commas(buf[:], g.mulched), x, Y + 46, COLOR_YELLOW) + 12
	x += print(f, "SPILLED ", x, Y + 46, COLOR_LIGHT)
	print(f, commas(buf[:], g.spilled), x, Y + 46, COLOR_YELLOW)
	if g.cat_found {
		print_wrapped(f, "The lucky cat stands in gold by the bin.", X + 8, Y + 62, (W - 16) / GLYPH_W, COLOR_WHITE)
	} else {
		print_wrapped(f, "Something lucky is still down there.", X + 8, Y + 62, (W - 16) / GLYPH_W, COLOR_LIGHT)
	}
	print(f, "SPACE: A FRESH STREET", X + 8, Y + H - 14, COLOR_LIGHT)
}
