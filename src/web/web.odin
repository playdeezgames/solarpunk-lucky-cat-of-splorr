#+build js
package main

// Thin browser layer (Odin wasm recipe boilerplate). odin.js drives `step` from its own
// requestAnimationFrame loop; the page copies the frame when platform_frame_ready says it changed, and
// forwards input as small integers.

import "base:runtime"
import "core:time"
import "tggd:game"

state: struct {
	rules:  game.Game,
	screen: game.Frame,
	ready:  bool,
}

main :: proc() {
	game.init_game(&state.rules, u64(time.now()._nsec))
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = c
	game.tick(&state.rules, dt)
	game.draw_game(&state.screen, &state.rules)
	game.resolve(&state.screen)
	state.ready = true
	return true
}

// A game.Command from a key, a gamepad button or a touch pad: the four directions, OK and Cancel.
@(export)
platform_command :: proc "c" (command: i32) {
	context = runtime.default_context()
	if command < 0 || command > i32(max(game.Command)) {
		return
	}
	game.command(&state.rules, game.Command(command))
}

// This frame's sound effects (game.Sound values), for the page to play; it then calls
// platform_sounds_clear.
@(export)
platform_sound_count :: proc "c" () -> i32 {
	return state.rules.sound_count
}

@(export)
platform_sound :: proc "c" (i: i32) -> i32 {
	if i < 0 || i >= state.rules.sound_count {
		return -1
	}
	return i32(state.rules.sounds[i])
}

@(export)
platform_sounds_clear :: proc "c" () {
	state.rules.sound_count = 0
}

// 1 when the frame holds pixels the page has not copied yet (and marks them taken).
@(export)
platform_frame_ready :: proc "c" () -> i32 {
	if !state.ready {
		return 0
	}
	state.ready = false
	return 1
}

@(export)
platform_frame_ptr :: proc "c" () -> rawptr {
	return &state.screen.rgba
}

@(export)
platform_screen_w :: proc "c" () -> i32 {
	return game.SCREEN_W
}

@(export)
platform_screen_h :: proc "c" () -> i32 {
	return game.SCREEN_H
}
