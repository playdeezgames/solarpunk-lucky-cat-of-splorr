package game

// Soil, the street and the shop. Soil is spent on greening the next house (the goal) or on four
// upgrades. Each bloomed house brings a neighbour: scraps fall a little faster and the green/brown mix
// shifts with who moved in. Prices and boosts are Claude's placeholders (DESIGN.md).

HOUSE_PRICES := [HOUSES]i64{12, 28, 48, 75, 110, 150, 200, 270}
// How each house's neighbour shifts the chance of a green (they sum to 0 over the street).
HOUSE_GREEN := [HOUSES]f32{0.08, -0.08, 0.05, -0.05, 0.10, -0.10, 0.0, 0.0}
FALL_PER_HOUSE :: 0.15 // rows a second added per bloomed house
DELIVER_PER_HOUSE :: 0.12 // seconds taken off the delivery per bloomed house

Upgrade :: enum u8 {
	Fork, // a pip more strength, and faster refill
	Worms, // greens heat faster
	Fan, // turning airs a column for longer
	Sieve, // more soil per compost
}

UPGRADE_MAX :: 3
UPGRADE_PRICES := [Upgrade][UPGRADE_MAX]i64 {
	.Fork  = {20, 55, 120},
	.Worms = {25, 70, 150},
	.Fan   = {20, 55, 120},
	.Sieve = {35, 80, 160},
}
UPGRADE_NAMES := [Upgrade]string {
	.Fork  = "FORK",
	.Worms = "WORMS",
	.Fan   = "SOLAR FAN",
	.Sieve = "SIEVE",
}
UPGRADE_TEXT := [Upgrade]string {
	.Fork  = "A sturdier fork: more turns, quicker rest.",
	.Worms = "Red wigglers. Greens rot faster.",
	.Fan   = "Turned columns stay aired longer.",
	.Sieve = "Sift more soil from each compost.",
}

// Shop rows: the next house first, then the upgrades, sound, start over, Back.
SHOP_HOUSE :: 0
SHOP_SOUND :: 1 + len(Upgrade)
SHOP_RESTART :: SHOP_SOUND + 1
SHOP_BACK :: SHOP_RESTART + 1
SHOP_ROWS :: SHOP_BACK + 1

Shop :: struct {
	open:    bool,
	cursor:  int,
	confirm: bool, // start over was chosen once; a second OK starts a fresh street
}

fork_max :: proc(g: ^Game) -> int {return FORK_MAX + g.levels[.Fork]}
fork_refill :: proc(g: ^Game) -> f32 {return FORK_REFILL - 0.8 * f32(g.levels[.Fork])}
worm_boost :: proc(g: ^Game) -> f32 {return 1 + 0.35 * f32(g.levels[.Worms])}
air_time :: proc(g: ^Game) -> f32 {return AIR_TIME + 4 * f32(g.levels[.Fan])}
soil_per_compost :: proc(g: ^Game) -> f32 {return (1 + 0.5 * f32(g.levels[.Sieve])) * (2 if g.cat_found else 1)}
fall_speed :: proc(g: ^Game) -> f32 {return FALL_SPEED + FALL_PER_HOUSE * f32(g.houses)}
deliver_time :: proc(g: ^Game) -> f32 {return DELIVER - DELIVER_PER_HOUSE * f32(g.houses)}

green_chance :: proc(g: ^Game) -> f32 {
	c := f32(GREEN_CHANCE)
	for i in 0 ..< g.houses {
		c += HOUSE_GREEN[i]
	}
	return clamp(c, 0.25, 0.75)
}

// One compost out of the hatch.
bank_soil :: proc(g: ^Game) {
	g.soil_frac += soil_per_compost(g)
	whole := i64(g.soil_frac)
	g.soil += whole
	g.soil_frac -= f32(whole)
}

next_house_price :: proc(g: ^Game) -> (i64, bool) {
	if g.houses >= HOUSES {
		return 0, false
	}
	return HOUSE_PRICES[g.houses], true
}

upgrade_price :: proc(g: ^Game, u: Upgrade) -> (i64, bool) {
	lv := g.levels[u]
	if lv >= UPGRADE_MAX {
		return 0, false
	}
	return UPGRADE_PRICES[u][lv], true
}

open_shop :: proc(g: ^Game) {
	g.shop = Shop{open = true}
	play(g, .Open)
}

close_shop :: proc(g: ^Game) {
	g.shop.open = false
	play(g, .Close)
}

shop_command :: proc(g: ^Game, c: Command) {
	switch c {
	case .North:
		g.shop.confirm = false
		g.shop.cursor = (g.shop.cursor + SHOP_ROWS - 1) % SHOP_ROWS
		play(g, .Move)
	case .South:
		g.shop.confirm = false
		g.shop.cursor = (g.shop.cursor + 1) % SHOP_ROWS
		play(g, .Move)
	case .Ok:
		buy(g, g.shop.cursor)
	case .Cancel:
		close_shop(g)
	case .West, .East:
	}
}

// Buys the shop row; returns whether anything was bought.
buy :: proc(g: ^Game, row: int) -> bool {
	switch row {
	case SHOP_BACK:
		close_shop(g)
		return false
	case SHOP_SOUND:
		g.muted = !g.muted
		play(g, .Buy)
		return false
	case SHOP_RESTART:
		if !g.shop.confirm {
			g.shop.confirm = true
			play(g, .Deny)
			return false
		}
		new_street(g)
		return false
	}
	if row == SHOP_HOUSE {
		price, ok := next_house_price(g)
		if !ok || g.soil < price {
			play(g, .Deny)
			return false
		}
		g.soil -= price
		g.houses += 1
		play(g, .Bloom)
		chat_bloom(g, g.houses - 1)
		if g.houses == HOUSES {
			finish_street(g)
		}
		return true
	}
	u := Upgrade(row - 1)
	price, ok := upgrade_price(g, u)
	if !ok || g.soil < price {
		play(g, .Deny)
		return false
	}
	g.soil -= price
	g.levels[u] += 1
	if u == .Fork {
		g.fork += 1 // the new pip comes ready
	}
	play(g, .Buy)
	return true
}
