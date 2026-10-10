## Constructions that work, with the coordinates to build them at.
##
## The prompt tells a design what to aim for — stagger the courses, make
## a smooth edge, turn a part on its side. It does not say how, and "how"
## in this system is a part number and four numbers after it. A design
## that has been told to use a bracket and does not know where a
## bracket's sideways stud sits works it out from attachment_points, gets
## it wrong twice, and goes back to stacking bricks studs-up — which is
## the shape everything it builds ends up having.
##
## So: worked examples, small enough to read and exact enough to place.
## Every one of them is checked by src/dev/techniques_probe.gd against
## the same lattice a design is checked against, so a technique that
## stopped holding together could not survive a run of the suite. A
## library of things that do not build would be worse than no library.
##
## The parts are the ones LEGO's own designers reach for: the jumper
## plate for a half stud, the bracket and the headlight brick for a face
## turned sideways, wedge plates for a diagonal, staggered courses for a
## wall that survives being picked up.
class_name Techniques
extends RefCounted


## Everything in the library, in the order a model would need it.
static func all() -> Array:
	return [
		{
			"name": "staggered wall",
			"when": "any wall, and anything that has to survive being "
				+ "picked up",
			"why": "Courses whose joints land in the same column come "
				+ "apart along that line. Each brick has to sit across "
				+ "the joint below it, which means the end of every "
				+ "other course is a half-length brick.",
			"bricks": [
				{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3001", "color": 4, "x": 4, "y": 0, "z": 0, "rot": 0},
				{"part": "3003", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3001", "color": 4, "x": 2, "y": 3, "z": 0, "rot": 0},
				{"part": "3003", "color": 4, "x": 6, "y": 3, "z": 0, "rot": 0},
			],
		},
		{
			"name": "half stud offset",
			"when": "centring something that will not centre, and any "
				+ "detail that wants to sit between studs",
			"why": "A jumper plate (3794b) carries one stud at its "
				+ "middle, so whatever goes on it lands half a stud "
				+ "across from the grid. This is how a door gets "
				+ "centred in a three-stud wall.",
			"bricks": [
				{"part": "3020", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3794b", "color": 71, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3024", "color": 4, "x": 0.5, "y": 2, "z": 0, "rot": 0},
			],
		},
		{
			"name": "face turned sideways",
			"when": "a smooth panel, a grille, lettering, a vent — "
				+ "anything that should face out rather than up",
			"why": "A bracket (99207) carries studs on its side as well "
				+ "as its top. Ask attachment_points where they are "
				+ "rather than working it out: the side ones are not at "
				+ "a whole number of plates.",
			"bricks": [
				{"part": "3001", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "99207", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3068b", "color": 1, "x": 0, "y": 3, "z": 1.2,
					"rot": 0, "face": "+z"},
			],
		},
		{
			"name": "porthole or lamp",
			"when": "a round detail set into a wall — a porthole, a "
				+ "headlamp, a rivet, an instrument",
			"why": "A headlight brick (4070) has a stud in a recess on "
				+ "its face, so what goes on it sits half a plate into "
				+ "the wall instead of standing proud of it.",
			"bricks": [
				{"part": "3001", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "4070", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "6141", "color": 0, "x": 0, "y": 3.5, "z": 0.8,
					"rot": 0, "face": "+z"},
			],
		},
		{
			"name": "smooth diagonal",
			"when": "any edge that runs straight and is not square to "
				+ "the grid — a saucer rim, a swept wing, a bow, a "
				+ "bonnet",
			"why": "Wedge plates make a diagonal in one part. Stepping "
				+ "it instead gives a staircase, which is the single "
				+ "most visible difference between a model that looks "
				+ "designed and one that looks like graph paper. They "
				+ "are filed under Wing, left and right handed, one "
				+ "plate thick.",
			"bricks": [
				{"part": "3031", "color": 71, "x": 4, "y": 0, "z": 0, "rot": 0},
				{"part": "41769b", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "41770b", "color": 71, "x": 0, "y": 0, "z": 2, "rot": 1},
			],
		},
		{
			"name": "smooth top",
			"when": "a roof, a floor, a bonnet, a deck — any surface "
				+ "that is not meant to show studs",
			"why": "Tiles are plates without studs. A surface left "
				+ "studded reads as unfinished, and tiling it is the "
				+ "cheapest thing that makes a model look built rather "
				+ "than assembled.",
			"bricks": [
				{"part": "3022", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3022", "color": 71, "x": 2, "y": 0, "z": 0, "rot": 0},
				{"part": "3068b", "color": 15, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3068b", "color": 15, "x": 2, "y": 1, "z": 0, "rot": 0},
			],
		},
		{
			"name": "round tower",
			"when": "a chimney, a lighthouse, a silo, a column, a "
				+ "cannon — anything circular in plan",
			"why": "Round bricks stack like square ones and read as a "
				+ "cylinder from any angle. Stepping a circle out of "
				+ "square bricks never does.",
			"bricks": [
				{"part": "3941", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3941", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3941", "color": 4, "x": 0, "y": 6, "z": 0, "rot": 0},
			],
		},
		{
			"name": "wide round tower",
			"when": "a castle tower, a silo, a turret — anything round "
				+ "and more than a couple of studs across",
			"why": "Four 4x4 corner-round bricks make one course of an "
				+ "8x8 round tower, each turned a quarter further than "
				+ "the last. A round tower is a choice, not a castle's "
				+ "default: of 54 castle sets since 2010, 15 use this "
				+ "brick at all and none more than eight of it, where "
				+ "every castle built here stacked two hundred. Lion "
				+ "Knights' Castle, 4,405 parts, has none of it and 281 "
				+ "1x2 masonry bricks. When the brief does want a "
				+ "round one:\n"
				+ "The alternative is what a design falls into without "
				+ "it. A fill of an ellipse this small has no room for "
				+ "a long brick in any run, so it comes out as a "
				+ "staircase of 1x1s — measured on a castle run: 354 "
				+ "1x1 bricks, four towers' worth, in a 1,552 part model "
				+ "made of twenty shapes where a real set of that size "
				+ "has a hundred and seventy-three. Round out of square "
				+ "bricks never reads as round.\n"
				+ "The turn matters and cannot be guessed: stepping the "
				+ "rotations the other way round the quadrants still "
				+ "stacks, still checks as buildable, and fills the "
				+ "middle instead of leaving a tower. Measured by "
				+ "turning the finished ring a quarter about its own "
				+ "centre — the right way maps onto itself, the wrong "
				+ "way does not.",
			"bricks": [
				{"part": "48092", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "48092", "color": 71, "x": 4, "y": 0, "z": 0, "rot": 1},
				{"part": "48092", "color": 71, "x": 4, "y": 0, "z": 4, "rot": 2},
				{"part": "48092", "color": 71, "x": 0, "y": 0, "z": 4, "rot": 3},
				{"part": "48092", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "48092", "color": 71, "x": 4, "y": 3, "z": 0, "rot": 1},
				{"part": "48092", "color": 71, "x": 4, "y": 3, "z": 4, "rot": 2},
				{"part": "48092", "color": 71, "x": 0, "y": 3, "z": 4, "rot": 3},
			],
		},
		{
			"name": "taper",
			"when": "a tower, a funnel, a tree, a rock — anything "
				+ "narrower at the top than the bottom",
			"why": "Each course a stud narrower than the one below, "
				+ "centred on it. The silhouette comes from the taper, "
				+ "and a shape that should taper built as a box is one "
				+ "of the five faults worth looking for by name.",
			"bricks": [
				{"part": "3031", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3022", "color": 71, "x": 1, "y": 1, "z": 1, "rot": 0},
				{"part": "3024", "color": 71, "x": 1.5, "y": 2, "z": 1.5, "rot": 0},
			],
		},
		{
			"name": "window in a wall",
			"when": "a building — a house, a shop, a station, a tower "
				+ "with rooms in it",
			"why": "A window is a frame set into the wall, not a gap in "
				+ "it and not a brick of another colour: a fire station "
				+ "built here had forty-two aeroplane windows in white "
				+ "surrounds, and from a step back every one read as a "
				+ "blank. Real buildings use frames — 60592 (1x2x2), "
				+ "60593 (1x2x3), 60594 (1x4x3), and 60596 for a door "
				+ "(1x4x6). 60592, 60594 and 60596 are each in a "
				+ "quarter to a third of real house sets.\n"
				+ "The frame stands on a course like any brick and is "
				+ "three courses tall here; the courses either side are "
				+ "laid short so the bond still runs past it, and the "
				+ "course over it has to bridge it — a 1x4 arch is that "
				+ "and a lintel at once. In a real set glass clips into "
				+ "the frame (60602 for this one); the checker here "
				+ "reads glass as an overlap, so leave it out.",
			"bricks": [
				{"part": "3010", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 4, "y": 0, "z": 0, "rot": 0},
				{"part": "3622", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "60593", "color": 15, "x": 3, "y": 3, "z": 0, "rot": 0},
				{"part": "3622", "color": 4, "x": 5, "y": 3, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 0, "y": 6, "z": 0, "rot": 0},
				{"part": "3005", "color": 4, "x": 2, "y": 6, "z": 0, "rot": 0},
				{"part": "3005", "color": 4, "x": 5, "y": 6, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 6, "y": 6, "z": 0, "rot": 0},
				{"part": "3622", "color": 4, "x": 0, "y": 9, "z": 0, "rot": 0},
				{"part": "3622", "color": 4, "x": 5, "y": 9, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 0, "y": 12, "z": 0, "rot": 0},
				{"part": "3659", "color": 15, "x": 2, "y": 12, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 6, "y": 12, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 0, "y": 15, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 4, "y": 15, "z": 0, "rot": 0},
			],
		},
	]


## One by name, or an empty dictionary.
static func named(what: String) -> Dictionary:
	var wanted: String = what.strip_edges().to_lower()
	for one: Variant in all():
		var technique: Dictionary = one
		if str(technique["name"]).to_lower() == wanted:
			return technique
	# Near enough: "wedge" should find "smooth diagonal", and a design
	# that half-remembers a name should not be told nothing exists.
	for one: Variant in all():
		var technique: Dictionary = one
		if str(technique["name"]).to_lower().contains(wanted) \
				or wanted.contains(str(technique["name"]).to_lower()):
			return technique
	return {}


## The names, for when nothing matched.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for one: Variant in all():
		out.append(str((one as Dictionary)["name"]))
	return out
