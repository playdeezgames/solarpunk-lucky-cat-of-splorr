package game

// Software renderer: a 384x216 landscape screen of Sweetie-16 palette indices, resolved to RGBA for
// the page. Text is the 6x8 DINOBYTE font (font.odin). Boilerplate from the SPLORR!! Odin wasm recipe.

SCREEN_W :: 384
SCREEN_H :: 216

TILE :: 16
GLYPH_W :: 6
GLYPH_H :: 8

Frame :: struct {
	px:   [SCREEN_W * SCREEN_H]u8, // palette indices
	rgba: [SCREEN_W * SCREEN_H]u32, // 0xAABBGGRR (little-endian R,G,B,A bytes)
}

PALETTE := [16]u32 {
	0x1A1C2C, 0x5D275D, 0xB13E53, 0xEF7D57, 0xFFCD75, 0xA7F070, 0x38B764, 0x257179,
	0x29366F, 0x3B5DC9, 0x41A6F6, 0x73EFF7, 0xF4F4F4, 0x94B0C2, 0x566C86, 0x333C57,
}

COLOR_BLACK :: 0
COLOR_PURPLE :: 1
COLOR_RED :: 2
COLOR_ORANGE :: 3
COLOR_YELLOW :: 4
COLOR_LIME :: 5
COLOR_GREEN :: 6
COLOR_TEAL :: 7
COLOR_NAVY :: 8
COLOR_BLUE :: 9
COLOR_SKY :: 10
COLOR_CYAN :: 11
COLOR_WHITE :: 12
COLOR_LIGHT :: 13
COLOR_MID :: 14
COLOR_DARK :: 15

// Order matches NAMES in tools/gen_gfx.py.
Gfx :: enum {
	Green_Peel,
	Green_Lettuce,
	Green_Grass,
	Brown_Leaf,
	Brown_Card,
	Brown_Twig,
	Compost_A,
	Compost_B,
	Compost_C,
	Fork,
	Barrow,
	Cat,
	Roof,
	Wall,
	Roof_Solar,
	Roof_Farm,
	Vines,
	Turbine,
	Barrel,
	Garden_Bare,
	Garden_Bloom,
	Sun,
	Cat_Wave,
}

// A colour swap for one draw: identity unless changed.
Remap :: [16]u8

IDENTITY :: Remap{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}

cls :: proc(f: ^Frame, c: u8) {
	for &p in f.px {
		p = c
	}
}

set_px :: proc(f: ^Frame, x, y: int, c: u8) {
	if x < 0 || y < 0 || x >= SCREEN_W || y >= SCREEN_H {
		return
	}
	f.px[y * SCREEN_W + x] = c
}

get_px :: proc(f: ^Frame, x, y: int) -> u8 {
	if x < 0 || y < 0 || x >= SCREEN_W || y >= SCREEN_H {
		return 0
	}
	return f.px[y * SCREEN_W + x]
}

fill_rect :: proc(f: ^Frame, x, y, w, h: int, c: u8) {
	for yy in y ..< y + h {
		for xx in x ..< x + w {
			set_px(f, xx, yy, c)
		}
	}
}

// Draws a picture; colour 0 is transparent. `flip` mirrors it left to right; `scale` is whole pixels.
draw_gfx :: proc(f: ^Frame, g: Gfx, x, y: int, flip := false, remap := IDENTITY, scale := 1) {
	pic := &GFX[g]
	for i in 0 ..< TILE * TILE {
		c := pic[i]
		if c == 0 {
			continue
		}
		col := i % TILE
		if flip {
			col = TILE - 1 - col
		}
		if scale == 1 {
			set_px(f, x + col, y + i / TILE, remap[c])
		} else {
			fill_rect(f, x + col * scale, y + (i / TILE) * scale, scale, scale, remap[c])
		}
	}
}

text_width :: proc(text: string) -> int {
	return len(text) * GLYPH_W
}

// Monospaced print of bytes as code page 437; returns the width drawn.
print :: proc(f: ^Frame, text: string, x, y: int, color: u8 = COLOR_WHITE) -> int {
	for i in 0 ..< len(text) {
		print_glyph(f, text[i], x + i * GLYPH_W, y, color)
	}
	return text_width(text)
}

print_glyph :: proc(f: ^Frame, ch: u8, x, y: int, color: u8) {
	bits := FONT[ch]
	for row in 0 ..< GLYPH_H {
		for col in 0 ..< GLYPH_W {
			if bits & (1 << uint(row * GLYPH_W + col)) != 0 {
				set_px(f, x + col, y + row, color)
			}
		}
	}
}

// Writes palette indices through the palette into rgba.
resolve :: proc(f: ^Frame) {
	for p, i in f.px {
		c := PALETTE[p & 15]
		f.rgba[i] = 0xFF000000 | (c & 0xFF) << 16 | (c >> 8 & 0xFF) << 8 | (c >> 16 & 0xFF)
	}
}

// Formats n with thousands commas into buf; returns the text.
commas :: proc(buf: []u8, n: i64) -> string {
	v := n
	neg := v < 0
	if neg {
		v = -v
	}
	tmp: [32]u8
	i := len(tmp)
	digits := 0
	for {
		if digits > 0 && digits % 3 == 0 {
			i -= 1
			tmp[i] = ','
		}
		i -= 1
		tmp[i] = u8('0' + v % 10)
		v /= 10
		digits += 1
		if v == 0 {
			break
		}
	}
	if neg {
		i -= 1
		tmp[i] = '-'
	}
	k := copy(buf, tmp[i:])
	return string(buf[:k])
}
