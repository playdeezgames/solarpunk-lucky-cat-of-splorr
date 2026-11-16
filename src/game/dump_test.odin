#+build !js
package game

// Renders a frame natively to a PPM, for screenshots and checking art without a browser:
// odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:DUMP_PLAY=/path/play.ppm -define:ODIN_TEST_NAMES=game.dump_play
// DUMP_HOUSES sets how many houses have bloomed.

import "core:os"
import "core:testing"

DUMP_PLAY :: #config(DUMP_PLAY, "")
DUMP_HOUSES :: #config(DUMP_HOUSES, 3)
DUMP_SHOP :: #config(DUMP_SHOP, false)

write_ppm :: proc(path: string, f: ^Frame) -> bool {
	data := make([]u8, 15 + SCREEN_W * SCREEN_H * 3)
	defer delete(data)
	header := "P6\n384 216\n255\n"
	copy(data, header)
	o := len(header)
	for p in f.px {
		c := PALETTE[p & 15]
		data[o], data[o + 1], data[o + 2] = u8(c >> 16), u8(c >> 8), u8(c)
		o += 3
	}
	return os.write_entire_file(path, data[:o]) == nil
}

@(test)
dump_play :: proc(t: ^testing.T) {
	if DUMP_PLAY == "" {
		return
	}
	g: Game
	init_game(&g, 42)
	g.houses = DUMP_HOUSES
	g.soil = 37
	// A heap mid-game: a few rows of mixed scraps, some compost, one slimy patch, a turned column.
	put(&g, 0, .Brown, .Green, .Brown, .Green, .Green)
	put(&g, 1, .Compost, .Brown, .Green, .Green, .Green, .Green)
	put(&g, 2, .Green, .Brown, .Compost, .Brown)
	put(&g, 3, .Brown, .Green, .Brown, .Green, .Brown, .Green, .Brown)
	put(&g, 4, .Brown, .Brown, .Brown)
	put(&g, 5, .Green, .Brown)
	for c in 0 ..< COLS {
		for r in 0 ..< ROWS {
			g.heap[c][r].look = u8((c * 7 + r * 3) % LOOKS)
		}
	}
	g.heap[1][4].slime = true
	g.heap[1][3].slime = true
	g.heap[3][1].heat = 0.8
	g.heap[3][3].heat = 0.4
	g.heap[5][0].heat = 0.2
	g.air[4] = AIR_TIME - 0.1
	g.fork = 2
	g.piece = Piece{kind = .Green, look = 1, col = 4, y = 6.3}
	g.chat.lands = LEARN_LANDS
	say(&g, NEIGHBOURS[2], BLOOM_LINES[2])
	g.levels[.Worms] = 1
	g.shop.open = DUMP_SHOP
	g.shop.cursor = 2
	f := new(Frame)
	defer free(f)
	draw_game(f, &g)
	testing.expect(t, write_ppm(DUMP_PLAY, f))
}
