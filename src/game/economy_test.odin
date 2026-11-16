#+build !js
package game

import "core:testing"

@(test)
shop_opens_pauses_and_closes :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	command(&g, .Cancel)
	testing.expect(t, g.shop.open)
	y := g.piece.y
	tick(&g, 0.25)
	testing.expect_value(t, g.piece.y, y) // paused
	command(&g, .West) // ignored by the shop
	testing.expect_value(t, g.piece.col, 0)
	command(&g, .Cancel)
	testing.expect(t, !g.shop.open)
}

@(test)
buying_a_house_needs_soil :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.soil = 9
	testing.expect(t, !buy(&g, SHOP_HOUSE))
	g.soil = 15
	testing.expect(t, buy(&g, SHOP_HOUSE))
	testing.expect_value(t, g.houses, 1)
	testing.expect_value(t, g.soil, 5)
	testing.expect_value(t, g.chat.line, BLOOM_LINES[0])
	testing.expect(t, fall_speed(&g) > FALL_SPEED)
	testing.expect(t, green_chance(&g) > GREEN_CHANCE)
}

@(test)
street_tops_out_at_eight :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.soil = 10_000
	for _ in 0 ..< HOUSES {
		testing.expect(t, buy(&g, SHOP_HOUSE))
	}
	testing.expect(t, !buy(&g, SHOP_HOUSE))
	testing.expect_value(t, g.houses, HOUSES)
	testing.expect(t, abs(green_chance(&g) - GREEN_CHANCE) < 1e-5) // the street's mix evens out
}

@(test)
upgrades_level_up_to_three :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.soil = 10_000
	for _ in 0 ..< UPGRADE_MAX {
		testing.expect(t, buy(&g, 1 + int(Upgrade.Fork)))
	}
	testing.expect(t, !buy(&g, 1 + int(Upgrade.Fork)))
	testing.expect_value(t, fork_max(&g), FORK_MAX + 3)
	testing.expect_value(t, g.fork, FORK_MAX + 3)
	testing.expect_value(t, g.soil, 10_000 - 15 - 40 - 90)
}

@(test)
sieve_carries_part_soil :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	g.levels[.Sieve] = 1 // 1.5 soil a compost
	bank_soil(&g)
	testing.expect_value(t, g.soil, 1)
	bank_soil(&g)
	testing.expect_value(t, g.soil, 3)
}

@(test)
worms_and_fan_boost :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	put(&g, 0, .Brown)
	put(&g, 1, .Green)
	g.levels[.Worms] = 2
	g.piece.col = 5
	tick(&g, 0.25)
	testing.expect(t, abs(g.heap[1][0].heat - HEAT_RATE * 1.7 * 0.25) < 1e-4)
	g.levels[.Fan] = 1
	put(&g, 2, .Brown, .Brown)
	testing.expect(t, turn(&g, 2))
	testing.expect_value(t, g.air[2], f32(AIR_TIME + 4))
}

@(test)
chatter_waits_for_the_controls :: proc(t: ^testing.T) {
	g: Game
	fresh(&g)
	for _ in 0 ..< 40 {
		tick(&g, 0.25)
		g.piece.y = SPAWN_Y
	}
	testing.expect_value(t, g.chat.line, "")
	g.chat.lands = LEARN_LANDS
	tick(&g, 0.25)
	testing.expect(t, g.chat.line != "")
}
