package game

// Neighbour chatter along the bottom of the screen. The controls show until the player has the hang of
// them; then a line every CHAT_EVERY seconds from whoever lives on the street, and a thank-you when a
// house blooms. Written by Claude.

CHAT_EVERY :: 9.0
CHAT_HOLD :: 7.0 // seconds a line stays up
LEARN_LANDS :: 12 // scraps landed before the controls give way to chatter

NEIGHBOURS := [HOUSES]string{"PRIYA, NO.1", "DES, NO.2", "MRS OKAFOR, NO.3", "THEO, NO.4", "THE BAKERS, NO.5", "JUNE, NO.6", "SAM & SAM, NO.7", "OLD MO, NO.8"}

// What each neighbour says when their house blooms.
BLOOM_LINES := [HOUSES]string {
	"Panels are up. The kettle runs on sun now.",
	"Ivy on the bricks. It's cooler inside already.",
	"A barrel for the rain. Never buying water again.",
	"The turbine hums. I find it very calming.",
	"Tomatoes on the roof! Bread and tomatoes!",
	"Panels. Mine are tidier than Priya's.",
	"We grew vines. Well, the vines grew.",
	"About time. I've been waiting forty years.",
}

// Lines anyone on a bloomed house might say; before anyone has bloomed, the grey street grumbles.
GREY_LINES := [?]string {
	"Another grey morning on Ash Street.",
	"They say a bin can change a street. Who says?",
	"Peels go in the bin. The bin is the plan.",
	"Mind the mix, love. Greens need their browns.",
}
GREEN_LINES := [?]string {
	"The bees found us. Nobody told them.",
	"Swapped my car for a cargo bike. And a nap.",
	"The air smells of tomatoes and sun.",
	"Leaves are browns. Coffee grounds are greens.",
	"Give the heap a turn when it sulks.",
	"Grass clippings. Loads of them. Sorry.",
	"Who knew rot could be so hopeful?",
	"The street's getting greener. I can hear it.",
}
SLIME_LINES := [?]string {"Something smells, love. Give it a turn.", "Is that the bin? It's the bin.", "Too many greens in a pile. Air it out."}

Chat :: struct {
	who:   string,
	line:  string,
	t:     f32, // seconds the line has left on screen
	next:  f32, // seconds until the next line
	lands: int, // scraps landed (to retire the controls hint)
}

say :: proc(g: ^Game, who, line: string) {
	g.chat.who = who
	g.chat.line = line
	g.chat.t = CHAT_HOLD
	g.chat.next = CHAT_EVERY
}

chat_bloom :: proc(g: ^Game, house: int) {
	say(g, NEIGHBOURS[house], BLOOM_LINES[house])
}

chat_tick :: proc(g: ^Game, dt: f32) {
	g.chat.t = max(g.chat.t - dt, 0)
	if g.shop.open || g.chat.lands < LEARN_LANDS {
		return
	}
	g.chat.next -= dt
	if g.chat.next > 0 {
		return
	}
	slimy := false
	for col in 0 ..< COLS {
		for row in 0 ..< ROWS {
			if g.heap[col][row].slime {
				slimy = true
			}
		}
	}
	who := NEIGHBOURS[rand_int(g, HOUSES)]
	if g.houses > 0 {
		who = NEIGHBOURS[rand_int(g, g.houses)]
	}
	switch {
	case slimy:
		say(g, who, SLIME_LINES[rand_int(g, len(SLIME_LINES))])
	case g.houses == 0:
		say(g, who, GREY_LINES[rand_int(g, len(GREY_LINES))])
	case:
		say(g, who, GREEN_LINES[rand_int(g, len(GREEN_LINES))])
	}
}
