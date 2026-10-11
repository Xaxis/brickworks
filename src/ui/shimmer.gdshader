// The light that crosses a part's picture while it is still being drawn.
//
// Placed by where it is on screen rather than per tile, so every
// placeholder in sight is lit by the same band as it passes: a page of
// them reads as one surface loading, not forty squares pulsing on their
// own clocks.
//
// It lifts only what is already drawn, by multiplying its opacity, so
// the faint fill of a placeholder brightens and the space around it
// stays empty.
//
// Driven by TIME, which is the point: the tiles run no script while they
// wait, one scrolled out of sight is culled and costs nothing, and once
// nothing on screen is waiting nothing draws with this at all.
shader_type canvas_item;

// Seconds for the band to travel from one repeat to the next.
uniform float seconds = 1.5;
// Pixels between one band and the next, measured along the slant. Wider
// than the parts bin, so it never has two at once.
uniform float repeat = 760.0;
// The band's half-width, in pixels.
uniform float width = 110.0;
// How much brighter a placeholder is under the middle of the band.
uniform float strength = 1.4;

void fragment() {
	// On a slant, so it reads as light passing rather than as a wipe.
	float along = FRAGCOORD.x + FRAGCOORD.y * 0.45;
	float offset = mod(along - TIME * repeat / seconds, repeat) - repeat * 0.5;
	float light = exp(-(offset * offset) / (width * width));
	COLOR.a *= 1.0 + strength * light;
}
