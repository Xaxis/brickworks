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


## Everything in the library; show_technique lists it by [constant GROUPS].
static func all() -> Array:
	return [
		{
			"name": "staggered wall",
			"group": "walls and stone",
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
			"group": "basics",
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
			"group": "basics",
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
			"group": "basics",
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
			"group": "basics",
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
			"group": "basics",
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
			"group": "towers and columns",
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
			"group": "towers and columns",
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
				+ "The turn matters and cannot be guessed. This example "
				+ "had two of its four turned the wrong way — a bow tie, "
				+ "which stacks and checks as buildable just the same — "
				+ "and a ring's quarters are now read off the part itself "
				+ "and tested at eight points round the rim. A round plate "
				+ "over the courses ties the four columns into one. The "
				+ "round pattern lays all of this, any height, in one "
				+ "call: {\"pattern\": \"round\", \"diameter\": 8, "
				+ "\"stack\": [{\"plates\": 18}]}.",
			"bricks": [
				{"part": "48092", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "48092", "color": 71, "x": 4, "y": 0, "z": 0, "rot": 1},
				{"part": "48092", "color": 71, "x": 4, "y": 0, "z": 4, "rot": 0},
				{"part": "48092", "color": 71, "x": 0, "y": 0, "z": 4, "rot": 3},
				{"part": "48092", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 2},
				{"part": "48092", "color": 71, "x": 4, "y": 3, "z": 0, "rot": 1},
				{"part": "48092", "color": 71, "x": 4, "y": 3, "z": 4, "rot": 0},
				{"part": "48092", "color": 71, "x": 0, "y": 3, "z": 4, "rot": 3},
				{"part": "74611", "color": 71, "x": 0, "y": 6, "z": 0, "rot": 0},
			],
		},
		{
			"name": "taper",
			"group": "basics",
			"when": "a tower, a funnel, a tree, a rock — anything "
				+ "narrower at the top than the bottom",
			"why": "Each course narrower than the one below, centred "
				+ "on it. A step of one stud centres only on a jumper: "
				+ "the 1 x 1 stands on the middle stud of a 2 x 2 "
				+ "jumper (87580), where on a plain 2 x 2 it would be "
				+ "half a stud off every stud. The silhouette comes "
				+ "from the taper, and a shape that should taper built "
				+ "as a box is one of the five faults worth looking for "
				+ "by name.",
			"bricks": [
				{"part": "3031", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "87580", "color": 71, "x": 1, "y": 1, "z": 1, "rot": 0},
				{"part": "3024", "color": 71, "x": 1.5, "y": 2, "z": 1.5, "rot": 0},
			],
		},
		{
			"name": "window in a wall",
			"group": "windows and doors",
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
				+ "and a lintel at once. The glass, 60602 in "
				+ "trans-clear, clips into the frame where real sets put "
				+ "it — at the frame's own origin, which in these "
				+ "numbers is the frame's plus 0.2 across, 1 up and 0.6 "
				+ "in. Anywhere else it is an overlap.",
			"bricks": [
				{"part": "3010", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 4, "y": 0, "z": 0, "rot": 0},
				{"part": "3622", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "60593", "color": 15, "x": 3, "y": 3, "z": 0, "rot": 0},
				{"part": "60602", "color": 47, "x": 3.2, "y": 4, "z": 0.6, "rot": 0},
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
		{
			"name": "door in a wall",
			"group": "windows and doors",
			"when": "a building's way in — a house, a shop, a station's "
				+ "side door, a castle's postern",
			"why": "A door is a frame in the wall and a door in the "
				+ "frame. 60596, the 1x4x6 frame, is in a third of real "
				+ "house sets; 60623 (with panes) and 60616 (plain) hang "
				+ "in it. Real sets hang the door 32 LDU from the "
				+ "frame's middle and 5 in, which in these numbers is "
				+ "the frame's plus 0.2 across, 1 up and 0.2 out, at the "
				+ "frame's own turn — or turned half round for the "
				+ "other hand, same numbers. Anywhere else it is an "
				+ "overlap. The frame is six courses tall and the wall "
				+ "either side keeps its bond. Finish the wall level "
				+ "with its top: its two outer studs are notched for the "
				+ "hinge and drawn without LDraw's stud primitive, so "
				+ "the checker here takes them for solid plastic and "
				+ "refuses anything laid on them.",
			"bricks": [
				{"part": "3010", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 4, "y": 0, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 8, "y": 0, "z": 0, "rot": 0},
				{"part": "60596", "color": 15, "x": 4, "y": 3, "z": 0, "rot": 0},
				{"part": "60623", "color": 1, "x": 4.2, "y": 4, "z": -0.2, "rot": 0},
				{"part": "3010", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 8, "y": 3, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 0, "y": 6, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 2, "y": 6, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 8, "y": 6, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 10, "y": 6, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 0, "y": 9, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 8, "y": 9, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 0, "y": 12, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 2, "y": 12, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 8, "y": 12, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 10, "y": 12, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 0, "y": 15, "z": 0, "rot": 0},
				{"part": "3010", "color": 4, "x": 8, "y": 15, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 0, "y": 18, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 2, "y": 18, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 8, "y": 18, "z": 0, "rot": 0},
				{"part": "3004", "color": 4, "x": 10, "y": 18, "z": 0, "rot": 0},
			],
		},
		# What real sets build again and again, as they built it. Real sets
		# name their sub-models, and over 253 of them in LDraw's model
		# repository roof, door, seat, lamp, window and tree lead, then
		# furniture. Each of these is one of those sub-models as LEGO
		# built it, read into this app's numbers and checked like the
		# rest. A worked example moved a design where a part list did
		# not: told the window frames by number for three runs, a fire
		# station used none; shown one window, it used twenty-four.
		{
			"name": "lamp post",
			"group": "lights",
			"when": "a street, a square, a doorway, a quay",
			"why": "A real street lamp is a post and a lantern, not a yellow brick on a stick. As the LEGO Group built it in 4886 Building Bonanza: 7 parts, from LDraw's model repository (model by Robert Paciorek, CC BY 2.0).",
			"bricks": [
				{"part": "3941", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "3941", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 2},
				{"part": "3062b", "color": 0, "x": 0.5, "y": 6, "z": 0.5, "rot": 2},
				{"part": "3062b", "color": 0, "x": 0.5, "y": 9, "z": 0.5, "rot": 2},
				{"part": "3062b", "color": 0, "x": 0.5, "y": 12, "z": 0.5, "rot": 2},
				{"part": "3941", "color": 46, "x": 0, "y": 15, "z": 0, "rot": 2},
				{"part": "3043", "color": 0, "x": 0, "y": 18, "z": 0, "rot": 2},
			],
		},
		{
			"name": "tree",
			"group": "plants",
			"when": "a garden, a courtyard, the ground around a building or a castle",
			"why": "A real tree is a trunk and a canopy of leaf pieces at more than one height. As the LEGO Group built it in 4956 House: 13 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "3022", "color": 2, "x": 1, "y": 9, "z": 1, "rot": 0},
				{"part": "3660a", "color": 2, "x": 2, "y": 10, "z": 1, "rot": 1},
				{"part": "3660a", "color": 2, "x": 0, "y": 10, "z": 1, "rot": 3},
				{"part": "3001", "color": 2, "x": 1, "y": 13, "z": 0, "rot": 3},
				{"part": "3004", "color": 27, "x": 0, "y": 13, "z": 1, "rot": 3},
				{"part": "3004", "color": 27, "x": 3, "y": 13, "z": 1, "rot": 3},
				{"part": "3040b", "color": 2, "x": 0, "y": 16, "z": 2, "rot": 3},
				{"part": "3040b", "color": 2, "x": 1, "y": 16, "z": 0, "rot": 2},
				{"part": "3040b", "color": 2, "x": 2, "y": 16, "z": 1, "rot": 1},
				{"part": "3040b", "color": 2, "x": 2, "y": 16, "z": 2, "rot": 0},
				{"part": "3062b", "color": 70, "x": 1.5, "y": 6, "z": 1.5, "rot": 0},
				{"part": "3062b", "color": 70, "x": 1.5, "y": 3, "z": 1.5, "rot": 0},
				{"part": "3062b", "color": 70, "x": 1.5, "y": 0, "z": 1.5, "rot": 0},
			],
		},
		{
			"name": "bed",
			"group": "furniture and interiors",
			"when": "a room someone sleeps in: a house, an inn, a barracks, a castle keep",
			"why": "Interiors are what a real building set is full of and what every building built here has lacked. As the LEGO Group built it in 10297 Boutique Hotel: 15 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "3032", "color": 19, "x": 0, "y": 1, "z": 0, "rot": 3},
				{"part": "6141", "color": 19, "x": 0, "y": 0, "z": 5, "rot": 3},
				{"part": "6141", "color": 19, "x": 3, "y": 0, "z": 5, "rot": 3},
				{"part": "6141", "color": 19, "x": 0, "y": 0, "z": 0, "rot": 3},
				{"part": "6141", "color": 19, "x": 3, "y": 0, "z": 0, "rot": 3},
				{"part": "3710", "color": 320, "x": 0, "y": 2, "z": 0, "rot": 2},
				{"part": "3020", "color": 320, "x": 0, "y": 2, "z": 1, "rot": 2},
				{"part": "3020", "color": 320, "x": 0, "y": 2, "z": 3, "rot": 2},
				{"part": "87079", "color": 320, "x": 0, "y": 3, "z": 2, "rot": 2},
				{"part": "33909", "color": 15, "x": 2, "y": 3, "z": 0, "rot": 0},
				{"part": "33909", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "85984", "color": 15, "x": 2, "y": 4, "z": 0, "rot": 0},
				{"part": "85984", "color": 15, "x": 0, "y": 4, "z": 0, "rot": 0},
				{"part": "15068", "color": 320, "x": 2, "y": 2, "z": 4, "rot": 0},
				{"part": "15068", "color": 320, "x": 0, "y": 2, "z": 4, "rot": 0},
			],
		},
		{
			"name": "bench",
			"group": "furniture and interiors",
			"when": "a station, a park, a square, a waiting room",
			"why": "Seats in a row on a shared rail, as a real station has them. As the LEGO Group built it in 2150 Train Station: 6 parts, from LDraw's model repository (model by Robert Paciorek, CC BY 2.0).",
			"bricks": [
				{"part": "3623", "color": 0, "x": 1, "y": 0, "z": 0, "rot": 3},
				{"part": "3623", "color": 0, "x": 6, "y": 0, "z": 0, "rot": 3},
				{"part": "3034", "color": 0, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "4079", "color": 0, "x": 0, "y": 2, "z": 0.8, "rot": 0},
				{"part": "4079", "color": 0, "x": 3, "y": 2, "z": 0.8, "rot": 0},
				{"part": "4079", "color": 0, "x": 6, "y": 2, "z": 0.8, "rot": 0},
			],
		},
		{
			"name": "armchair",
			"group": "furniture and interiors",
			"when": "a room: an office, a parlour, a lounge",
			"why": "A chair is a seat, a back and arms, a few small parts. As the LEGO Group built it in 10246 Detective’s Office: 8 parts, from LDraw's model repository (model by Willy Tschager, CC BY 2.0).",
			"bricks": [
				{"part": "3679", "color": 71, "x": 1, "y": 0, "z": 1, "rot": 1},
				{"part": "99207", "color": 0, "x": 1, "y": 1, "z": 1, "rot": 2},
				{"part": "4079", "color": 70, "x": 0.8, "y": 2, "z": 1, "rot": 1},
				{"part": "99207", "color": 0, "x": 1, "y": 1, "z": 2, "rot": 0},
				{"part": "3839b", "color": 0, "x": 0.5, "y": 1, "z": 3.1, "rot": 0, "face": "+z"},
				{"part": "3839b", "color": 0, "x": 0.5, "y": 1, "z": 0.4, "rot": 2, "face": "-z"},
				{"part": "3069b", "color": 0, "x": 1, "y": 1, "z": 0.4, "rot": 2, "face": "-z"},
				{"part": "3069b", "color": 0, "x": 1, "y": 1, "z": 3.2, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "table",
			"group": "furniture and interiors",
			"when": "a kitchen, an inn, a hall, a café, a market",
			"why": "A table top on legs, at the height a minifigure sits to. As the LEGO Group built it in 31025 Mountain Hut: 10 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "3004", "color": 70, "x": 0, "y": 1, "z": 4, "rot": 0},
				{"part": "3020", "color": 70, "x": 0, "y": 4, "z": 1, "rot": 1},
				{"part": "3004", "color": 70, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "3023b", "color": 19, "x": 0, "y": 0, "z": 4, "rot": 0},
				{"part": "3023b", "color": 70, "x": 0, "y": 0, "z": 1, "rot": 0},
				{"part": "15573", "color": 15, "x": 0, "y": 5, "z": 3, "rot": 0},
				{"part": "6141", "color": 0, "x": 0.5, "y": 6, "z": 3, "rot": 0},
				{"part": "3062b", "color": 46, "x": 0.5, "y": 7, "z": 3, "rot": 0},
				{"part": "4740", "color": 0, "x": 0, "y": 10, "z": 2.5, "rot": 0},
				{"part": "3899", "color": 14, "x": 1, "y": 5, "z": 0.3, "rot": 0},
			],
		},
		{
			"name": "planter",
			"group": "plants",
			"when": "a window box, a doorstep, a balcony, a garden edge",
			"why": "Flowers are small parts in a second and third colour, which is most of what a real set's one-off pieces are. As the LEGO Group built it in 4956 House: 14 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "3795", "color": 70, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "6141", "color": 70, "x": 1, "y": 1, "z": 0, "rot": 1},
				{"part": "6141", "color": 70, "x": 1, "y": 1, "z": 2, "rot": 1},
				{"part": "6141", "color": 70, "x": 0, "y": 1, "z": 3, "rot": 1},
				{"part": "6141", "color": 70, "x": 1, "y": 1, "z": 4, "rot": 1},
				{"part": "6141", "color": 70, "x": 1, "y": 1, "z": 5, "rot": 1},
				{"part": "6141", "color": 70, "x": 1, "y": 2, "z": 0, "rot": 1},
				{"part": "6141", "color": 34, "x": 0, "y": 2, "z": 3, "rot": 1},
				{"part": "6141", "color": 34, "x": 1, "y": 2, "z": 5, "rot": 1},
				{"part": "6141", "color": 34, "x": 1, "y": 3, "z": 0, "rot": 1},
				{"part": "6141", "color": 34, "x": 1, "y": 1, "z": 1, "rot": 1},
				{"part": "6141", "color": 34, "x": 0, "y": 1, "z": 2, "rot": 1},
				{"part": "6141", "color": 4, "x": 1, "y": 2, "z": 4, "rot": 1},
				{"part": "6141", "color": 4, "x": 0, "y": 1, "z": 1, "rot": 1},
			],
		},
		{
			"name": "chimney",
			"group": "roofs and spires",
			"when": "any roof a building with a fire has",
			"why": "A real chimney has a cap and a pot, not just a stack. As the LEGO Group built it in 10182 Cafe Corner: 10 parts, from LDraw's model repository (model by Max Martin Richter, CC BY 2.0).",
			"bricks": [
				{"part": "3005", "color": 71, "x": 2, "y": 0, "z": 0, "rot": 0},
				{"part": "2877", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "2877", "color": 71, "x": 1, "y": 3, "z": 0, "rot": 2},
				{"part": "3005", "color": 72, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3024", "color": 72, "x": 1, "y": 6, "z": 0, "rot": 0},
				{"part": "3024", "color": 72, "x": 1, "y": 7, "z": 0, "rot": 0},
				{"part": "54200", "color": 72, "x": 0, "y": 6, "z": 0, "rot": 3},
				{"part": "54200", "color": 72, "x": 2, "y": 6, "z": 0, "rot": 1},
				{"part": "3062b", "color": 72, "x": 1, "y": 8, "z": 0, "rot": 1},
				{"part": "3070b", "color": 72, "x": 1, "y": 11, "z": 0, "rot": 1},
			],
		},
		{
			"name": "fence",
			"group": "rock and ground",
			"when": "a garden, a paddock, a yard, a forecourt",
			"why": "A fence of posts and rails, as a real set builds one. As the LEGO Group built it in 3189 Heartlake Stables: 3 parts, from LDraw's model repository (model by Takeshi Takahashi, CC BY 2.0).",
			"bricks": [
				{"part": "6079", "color": 15, "x": 0, "y": 1, "z": 0.5, "rot": 0},
				{"part": "3794a", "color": 2, "x": 1, "y": 0, "z": 0, "rot": 3},
				{"part": "3794a", "color": 2, "x": 6, "y": 0, "z": 0, "rot": 3},
			],
		},
		# The craft inside real sets, not only what their modellers split
		# out. Taken from LDraw's model repository by tools/omr.py:
		# `harvest` for named sub-models, and `clusters` for the groups of
		# parts round a bracket, an inverted slope, a cone or a plant inside
		# a big model, cut out where they stand on their own. Chosen by
		# what a castle, a fantasy set or a modular building is made of —
		# stone, corbels, spires, rock, interiors, light — and by the
		# style measures (tools/style.py): parts turned sideways, curves,
		# texture, growth. Each one built and looked at
		# (src/dev/technique_sheet_probe.gd) before it went in.
		{
			"name": "rough stone wall",
			"group": "walls and stone",
			"when": "a castle, a keep, a forge, a ruin: any wall that should read as stone",
			"why": "Masonry bricks (98283) in light grey with dark grey bricks set in at random, and the face broken up studs-out: bricks with studs on one side (11211) and headlight bricks (4070) carry grooved tiles turned to face out. One grey in plain bricks reads as plastic; two greys, masonry and a few faces turned out read as dressed stone. As the LEGO Group built it in 21325 Medieval Blacksmith: 24 parts, from LDraw's model repository (model by Vincent Messenet, CC BY 2.0).",
			"bricks": [
				{"part": "44861", "color": 0, "x": 2, "y": 0, "z": 0, "rot": 1},
				{"part": "54200", "color": 57, "x": 3, "y": 0, "z": 0, "rot": 3},
				{"part": "3622", "color": 71, "x": 1, "y": 0, "z": 0, "rot": 3},
				{"part": "3622", "color": 71, "x": 4, "y": 0, "z": 0, "rot": 3},
				{"part": "11211", "color": 72, "x": 2, "y": 0, "z": 2, "rot": 0},
				{"part": "11211", "color": 72, "x": 3, "y": 3, "z": 2, "rot": 0},
				{"part": "98283", "color": 71, "x": 1, "y": 3, "z": 2, "rot": 0},
				{"part": "98283", "color": 71, "x": 1, "y": 3, "z": 0, "rot": 3},
				{"part": "98283", "color": 71, "x": 4, "y": 3, "z": 0, "rot": 1},
				{"part": "3659", "color": 71, "x": 1, "y": 6, "z": 0, "rot": 0},
				{"part": "98283", "color": 71, "x": 1, "y": 6, "z": 1, "rot": 3},
				{"part": "98283", "color": 71, "x": 2, "y": 6, "z": 2, "rot": 0},
				{"part": "98283", "color": 71, "x": 4, "y": 6, "z": 1, "rot": 1},
				{"part": "4070", "color": 72, "x": 1, "y": 9, "z": 1, "rot": 3},
				{"part": "4070", "color": 72, "x": 4, "y": 9, "z": 1, "rot": 1},
				{"part": "3070b", "color": 72, "x": 0.8, "y": 9.5, "z": 1, "rot": 3, "face": "-x"},
				{"part": "3070b", "color": 72, "x": 4.8, "y": 9.5, "z": 1, "rot": 1, "face": "+x"},
				{"part": "11211", "color": 72, "x": 1, "y": 9, "z": 2, "rot": 0},
				{"part": "98283", "color": 71, "x": 3, "y": 9, "z": 2, "rot": 0},
				{"part": "98283", "color": 71, "x": 1, "y": 12, "z": 1, "rot": 3},
				{"part": "98283", "color": 71, "x": 4, "y": 12, "z": 1, "rot": 1},
				{"part": "3069b", "color": 72, "x": 2, "y": 0.5, "z": 3, "rot": 0, "face": "+z"},
				{"part": "3069b", "color": 72, "x": 3, "y": 3.5, "z": 3, "rot": 0, "face": "+z"},
				{"part": "3069b", "color": 72, "x": 1, "y": 9.5, "z": 3, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "weathered stone wall",
			"group": "walls and stone",
			"when": "an old wall, a ruin, a fortress that has stood a long time",
			"why": "Light grey with sand green bricks laid through it for moss and age, 2 x 2 facet bricks (87620) to knock the corner off, and a cheese slope turned sideways in the face. The second colour is what makes it old. As the LEGO Group built it in 9471 Uruk-hai Army: 18 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "32000", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "3004", "color": 71, "x": 2, "y": 0, "z": 0, "rot": 1},
				{"part": "3622", "color": 378, "x": 2, "y": 0, "z": 2, "rot": 1},
				{"part": "87620", "color": 71, "x": 3, "y": 0, "z": 4, "rot": 1},
				{"part": "4070", "color": 71, "x": 4, "y": 3, "z": 5, "rot": 2},
				{"part": "54200", "color": 71, "x": 4, "y": 3.5, "z": 4.4, "rot": 1, "face": "-z"},
				{"part": "2357", "color": 71, "x": 2, "y": 3, "z": 3, "rot": 0},
				{"part": "98283", "color": 71, "x": 2, "y": 3, "z": 1, "rot": 1},
				{"part": "3622", "color": 378, "x": 0, "y": 3, "z": 0, "rot": 2},
				{"part": "3005", "color": 71, "x": 0, "y": 6, "z": 0, "rot": 2},
				{"part": "3005", "color": 71, "x": 0, "y": 9, "z": 0, "rot": 2},
				{"part": "3005", "color": 378, "x": 2, "y": 6, "z": 4, "rot": 2},
				{"part": "3010", "color": 71, "x": 2, "y": 6, "z": 0, "rot": 3},
				{"part": "87620", "color": 71, "x": 3, "y": 6, "z": 4, "rot": 1},
				{"part": "3005", "color": 378, "x": 2, "y": 9, "z": 2, "rot": 2},
				{"part": "3004", "color": 71, "x": 2, "y": 9, "z": 3, "rot": 3},
				{"part": "3004", "color": 71, "x": 2, "y": 9, "z": 0, "rot": 3},
				{"part": "87620", "color": 71, "x": 3, "y": 9, "z": 4, "rot": 1},
			],
		},
		{
			"name": "corbelled wall walk",
			"group": "walls and stone",
			"when": "the top of a castle wall or tower, where the walk is wider than the wall",
			"why": "Inverted 45 slopes (3665) under the top course flare the wall out so the walkway oversails the face below: the corbel a castle's wall-walk stands on. A plate with a clip carries a flag or a torch. As the LEGO Group built it in 6080 King's Castle: 6 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "4085a", "color": 7, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "3024", "color": 7, "x": 0, "y": 0, "z": 2, "rot": 2},
				{"part": "3004", "color": 7, "x": 0, "y": 1, "z": 1, "rot": 1},
				{"part": "3023b", "color": 7, "x": 0, "y": 4, "z": 1, "rot": 3},
				{"part": "3665a", "color": 7, "x": 0, "y": 5, "z": 0, "rot": 2},
				{"part": "3665a", "color": 7, "x": 0, "y": 5, "z": 2, "rot": 0},
			],
		},
		{
			"name": "oversail on inverted slopes",
			"group": "walls and stone",
			"when": "an upper storey, a tower top or a gallery that stands out past the wall below",
			"why": "Inverted 2 x 2 slopes (3660) under the course above step the upper wall out over the lower one, with a band of reddish brown plates at the floor line. The shadow under the oversail is what makes a tower top read as a separate stage. As the LEGO Group built it in 10176 Royal King's Castle: 5 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "3660a", "color": 71, "x": 0, "y": 0, "z": 2, "rot": 2},
				{"part": "3023b", "color": 70, "x": 0, "y": 3, "z": 3, "rot": 0},
				{"part": "3660a", "color": 71, "x": 0, "y": 3, "z": 1, "rot": 2},
				{"part": "3023b", "color": 70, "x": 0, "y": 6, "z": 2, "rot": 0},
				{"part": "3660a", "color": 71, "x": 0, "y": 6, "z": 0, "rot": 2},
			],
		},
		{
			"name": "stone corbel",
			"group": "walls and stone",
			"when": "a ledge, a balcony or a floor held out from a wall or column",
			"why": "A tall inverted 75 slope (2449) under a plate holds the ledge out from its column with nothing underneath it, the way a stone corbel does. As the LEGO Group built it in 7327 Scorpion Pyramid: 7 parts, from LDraw's model repository (model by Christian Neumann, CC BY 2.0).",
			"bricks": [
				{"part": "2449", "color": 19, "x": 3, "y": 0, "z": 3, "rot": 3},
				{"part": "3005", "color": 19, "x": 4, "y": 9, "z": 3, "rot": 3},
				{"part": "2449", "color": 19, "x": 2, "y": 9, "z": 3, "rot": 3},
				{"part": "43888", "color": 72, "x": 5, "y": 0, "z": 3, "rot": 0},
				{"part": "3032", "color": 19, "x": 0, "y": 18, "z": 0, "rot": 0},
				{"part": "3794b", "color": 272, "x": 4, "y": 19, "z": 3, "rot": 0},
				{"part": "4589", "color": 297, "x": 4.5, "y": 20, "z": 3, "rot": 0},
			],
		},
		{
			"name": "balustrade",
			"group": "walls and stone",
			"when": "a terrace, a bridge, a balcony, a garden wall, a palace roof",
			"why": "Open bays of 1 x 3 arches (4490) and half-arch bricks (38585) on Technic 1 x 1 bricks, capped with plates and tiles: a rail that is light, open, and curved in every bay. As the LEGO Group built it in 10359 Fountain Garden: 22 parts, from LDraw's model repository (model by Orion Pobursky, CC BY 4.0).",
			"bricks": [
				{"part": "2420", "color": 15, "x": 0, "y": 0, "z": 9, "rot": 0},
				{"part": "6541", "color": 15, "x": 0, "y": 1, "z": 10, "rot": 3},
				{"part": "4490", "color": 15, "x": 0, "y": 1, "z": 7, "rot": 3},
				{"part": "3623", "color": 15, "x": 0, "y": 0, "z": 5, "rot": 3},
				{"part": "6541", "color": 15, "x": 0, "y": 1, "z": 6, "rot": 3},
				{"part": "4490", "color": 15, "x": 0, "y": 1, "z": 3, "rot": 3},
				{"part": "3623", "color": 15, "x": 0, "y": 0, "z": 1, "rot": 3},
				{"part": "6541", "color": 15, "x": 0, "y": 1, "z": 2, "rot": 3},
				{"part": "38585", "color": 15, "x": -1, "y": 1, "z": 0, "rot": 2},
				{"part": "4490", "color": 15, "x": 1, "y": 1, "z": 10, "rot": 2},
				{"part": "3623", "color": 15, "x": 3, "y": 0, "z": 10, "rot": 2},
				{"part": "6541", "color": 15, "x": 4, "y": 1, "z": 10, "rot": 0},
				{"part": "38585", "color": 15, "x": 5, "y": 1, "z": 10, "rot": 0},
				{"part": "3710", "color": 15, "x": 3, "y": 4, "z": 10, "rot": 0},
				{"part": "77844", "color": 15, "x": 0, "y": 4, "z": 8, "rot": 0},
				{"part": "3460", "color": 15, "x": 0, "y": 4, "z": 0, "rot": 3},
				{"part": "3070b", "color": 15, "x": 6, "y": 5, "z": 10, "rot": 3},
				{"part": "3070b", "color": 15, "x": 0, "y": 5, "z": 9, "rot": 3},
				{"part": "3070b", "color": 15, "x": 0, "y": 5, "z": 0, "rot": 3},
				{"part": "3069b", "color": 15, "x": 0, "y": 5, "z": 10, "rot": 0},
				{"part": "3710", "color": 15, "x": 2, "y": 5, "z": 10, "rot": 0},
				{"part": "3460", "color": 15, "x": 0, "y": 5, "z": 1, "rot": 3},
			],
		},
		{
			"name": "embossed brick wall",
			"group": "walls and stone",
			"when": "a house, a cottage, a workshop: a wall of small bricks rather than stone",
			"why": "Bricks with embossed bricks (15533) lay a face of small bricks in mortar courses in a few large parts, beside a 60592 window in a second colour. As the LEGO Group built it in 75980 Attack on The Burrow: 12 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "3005", "color": 84, "x": 2, "y": 0, "z": 0, "rot": 0},
				{"part": "15533", "color": 84, "x": 3, "y": 0, "z": 0, "rot": 0},
				{"part": "3022", "color": 379, "x": 0, "y": 4, "z": 0, "rot": 0},
				{"part": "3024", "color": 84, "x": 2, "y": 3, "z": 0, "rot": 3},
				{"part": "3024", "color": 84, "x": 2, "y": 4, "z": 0, "rot": 3},
				{"part": "3023b", "color": 84, "x": 1, "y": 5, "z": 0, "rot": 0},
				{"part": "15533", "color": 84, "x": 3, "y": 3, "z": 0, "rot": 0},
				{"part": "60592", "color": 379, "x": 0, "y": 5, "z": 1, "rot": 0},
				{"part": "60601", "color": 47, "x": 0.2, "y": 6, "z": 1.6, "rot": 0},
				{"part": "3023b", "color": 379, "x": 0, "y": 11, "z": 1, "rot": 0},
				{"part": "15533", "color": 84, "x": 2, "y": 6, "z": 0, "rot": 0},
				{"part": "3024", "color": 84, "x": 5, "y": 9, "z": 0, "rot": 0},
			],
		},
		{
			"name": "columns with capitals",
			"group": "towers and columns",
			"when": "a portico, a hall, a doorway, a temple, a cloister",
			"why": "1 x 1 x 6 round bricks with square bases (43888) for the shafts and half-arch bricks (38585) for capitals under a plate: classical columns at minifigure scale. As the LEGO Group built it in 10278 Police Station: 8 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "3623", "color": 19, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "54200", "color": 19, "x": 1, "y": 1, "z": 0, "rot": 0},
				{"part": "43888", "color": 19, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "43888", "color": 19, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "6141", "color": 19, "x": 2, "y": 19, "z": 0, "rot": 0},
				{"part": "6141", "color": 19, "x": 0, "y": 19, "z": 0, "rot": 0},
				{"part": "38585", "color": 19, "x": 0, "y": 20, "z": 0, "rot": 0},
				{"part": "38585", "color": 19, "x": 1, "y": 20, "z": 0, "rot": 3},
			],
		},
		{
			"name": "stone column",
			"group": "towers and columns",
			"when": "a pillar under an arch or a floor, a gatepost",
			"why": "Round 1 x 1 bricks for the shaft and a headlight brick at the top with a tile turned out on its face for the capital. As the LEGO Group built it in 4954 Model Town House: 6 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "3062b", "color": 71, "x": 0.5, "y": 0, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 71, "x": 0.5, "y": 3, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 71, "x": 0.5, "y": 6, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 71, "x": 0.5, "y": 9, "z": 0.5, "rot": 0},
				{"part": "4070", "color": 71, "x": 0.5, "y": 12, "z": 0.5, "rot": 0},
				{"part": "3070b", "color": 71, "x": 0.5, "y": 12.5, "z": 1.3, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "turned wooden pillar",
			"group": "towers and columns",
			"when": "a porch, a hall, a timber-framed building",
			"why": "Round 1 x 1 bricks and round plates in reddish brown with a tan cap: a post with the turned profile of a carpenter's pillar. As the LEGO Group built it in 10182 Cafe Corner: 6 parts, from LDraw's model repository (model by Max Martin Richter, CC BY 2.0).",
			"bricks": [
				{"part": "6141", "color": 70, "x": 0.5, "y": 0, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 70, "x": 0.5, "y": 1, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 70, "x": 0.5, "y": 4, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 70, "x": 0.5, "y": 7, "z": 0.5, "rot": 0},
				{"part": "6141", "color": 19, "x": 0.5, "y": 13, "z": 0.5, "rot": 0},
				{"part": "3062b", "color": 70, "x": 0.5, "y": 10, "z": 0.5, "rot": 0},
			],
		},
		{
			"name": "turret spire",
			"group": "roofs and spires",
			"when": "the top of a round turret, a tower, a wizard's or a castle's roofline",
			"why": "A 2 x 2 x 2 cone (3942c) in dark grey with a sand green 1 x 1 cone for the finial on a turret of round 2 x 2 bricks: the spire Hogwarts sets crown their towers with. As the LEGO Group built it in 75969 Hogwarts Astronomy Tower: 7 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "3023b", "color": 84, "x": 3, "y": 0, "z": 0, "rot": 3},
				{"part": "3020", "color": 19, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3941", "color": 19, "x": 0, "y": 2, "z": 0, "rot": 3},
				{"part": "3941", "color": 19, "x": 0, "y": 5, "z": 0, "rot": 3},
				{"part": "3004", "color": 19, "x": 3, "y": 2, "z": 0, "rot": 1},
				{"part": "3942c", "color": 72, "x": 0, "y": 8, "z": 0, "rot": 0},
				{"part": "59900", "color": 378, "x": 0.5, "y": 14, "z": 0.5, "rot": 0},
			],
		},
		{
			"name": "roof ridge",
			"group": "roofs and spires",
			"when": "a pitched roof whose two sides are hinged panels",
			"why": "The ridge of a roof built as two panels: hinge bases (3937) along a beam of Technic bricks take the panels' hinge tops (3938), set at whatever pitch the roof wants, with slopes and finials along the top. As the LEGO Group built it in 75954 Hogwarts Great Hall: 22 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "3703", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "2780", "color": 0, "x": 14.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "2780", "color": 0, "x": 10.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "2780", "color": 0, "x": 8.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "2780", "color": 0, "x": 0.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "2730", "color": 0, "x": 0, "y": 0, "z": 1, "rot": 2},
				{"part": "3703", "color": 0, "x": 10, "y": 0, "z": 1, "rot": 0},
				{"part": "2780", "color": 0, "x": 16.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "2780", "color": 0, "x": 24.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "2730", "color": 0, "x": 16, "y": 0, "z": 0, "rot": 2},
				{"part": "3710", "color": 70, "x": 21, "y": 3, "z": 1, "rot": 2},
				{"part": "4282", "color": 72, "x": 5, "y": 3, "z": 0, "rot": 2},
				{"part": "3710", "color": 70, "x": 1, "y": 3, "z": 1, "rot": 2},
				{"part": "3040b", "color": 308, "x": 1, "y": 3, "z": 0, "rot": 1},
				{"part": "3040b", "color": 308, "x": 23, "y": 3, "z": 0, "rot": 3},
				{"part": "3937", "color": 84, "x": 1, "y": 4, "z": 1, "rot": 0},
				{"part": "3937", "color": 84, "x": 3, "y": 4, "z": 1, "rot": 0},
				{"part": "3937", "color": 84, "x": 23, "y": 4, "z": 1, "rot": 0},
				{"part": "3937", "color": 84, "x": 21, "y": 4, "z": 1, "rot": 0},
				{"part": "3037", "color": 71, "x": 11, "y": 4, "z": 0, "rot": 0},
				{"part": "3005", "color": 19, "x": 1, "y": 6, "z": 0, "rot": 0},
				{"part": "3005", "color": 19, "x": 24, "y": 6, "z": 0, "rot": 0},
			],
		},
		{
			"name": "striped awning",
			"group": "roofs and spires",
			"when": "a shop front, a market stall, a café, an inn's door",
			"why": "Brackets turn the studs out of the wall, and cutout slopes and rounded tiles laid on them in two alternating colours make the stripes of an awning that leans out over the door. As the LEGO Group built it in 10278 Police Station: 35 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "3666", "color": 30, "x": 1, "y": 2.5, "z": 0.5, "rot": 0},
				{"part": "3009", "color": 30, "x": 1, "y": 3.5, "z": 0.5, "rot": 0},
				{"part": "44728", "color": 15, "x": 5, "y": 2.5, "z": 0.5, "rot": 0},
				{"part": "44728", "color": 15, "x": 3, "y": 2.5, "z": 0.5, "rot": 0},
				{"part": "44728", "color": 15, "x": 1, "y": 2.5, "z": 0.5, "rot": 0},
				{"part": "99780", "color": 15, "x": 2, "y": 7.5, "z": 0.5, "rot": 0},
				{"part": "99780", "color": 15, "x": 4, "y": 7.5, "z": 0.5, "rot": 0},
				{"part": "3023b", "color": 15, "x": 0, "y": 7.5, "z": 0.5, "rot": 0},
				{"part": "3023b", "color": 15, "x": 6, "y": 7.5, "z": 0.5, "rot": 0},
				{"part": "32952", "color": 15, "x": 0, "y": 2.5, "z": 0.5, "rot": 0},
				{"part": "32952", "color": 15, "x": 7, "y": 2.5, "z": 0.5, "rot": 0},
				{"part": "3666", "color": 30, "x": 1, "y": 8.5, "z": 0.5, "rot": 0},
				{"part": "3024", "color": 15, "x": 0, "y": 8.5, "z": 0.5, "rot": 0},
				{"part": "3666", "color": 70, "x": 1, "y": 2.5, "z": 1.7, "rot": 0, "face": "+z"},
				{"part": "15573", "color": 15, "x": 2, "y": 7.5, "z": 1.7, "rot": 0, "face": "+z"},
				{"part": "15573", "color": 15, "x": 4, "y": 7.5, "z": 1.7, "rot": 0, "face": "+z"},
				{"part": "6141", "color": 15, "x": 4.5, "y": 7.5, "z": 2.1, "rot": 0, "face": "+z"},
				{"part": "35480", "color": 70, "x": 1, "y": 0, "z": 2.1, "rot": 3, "face": "+z"},
				{"part": "35480", "color": 70, "x": 2, "y": 0, "z": 2.1, "rot": 3, "face": "+z"},
				{"part": "35480", "color": 70, "x": 3, "y": 0, "z": 2.1, "rot": 3, "face": "+z"},
				{"part": "35480", "color": 70, "x": 4, "y": 0, "z": 2.1, "rot": 3, "face": "+z"},
				{"part": "35480", "color": 70, "x": 5, "y": 0, "z": 2.1, "rot": 3, "face": "+z"},
				{"part": "35480", "color": 70, "x": 6, "y": 0, "z": 2.1, "rot": 3, "face": "+z"},
				{"part": "28192", "color": 70, "x": 1, "y": 2.5, "z": 1.7, "rot": 2, "face": "+z"},
				{"part": "28192", "color": 70, "x": 3, "y": 2.5, "z": 1.7, "rot": 2, "face": "+z"},
				{"part": "28192", "color": 70, "x": 5, "y": 2.5, "z": 1.7, "rot": 2, "face": "+z"},
				{"part": "28192", "color": 92, "x": 2, "y": 2.5, "z": 1.7, "rot": 2, "face": "+z"},
				{"part": "28192", "color": 92, "x": 4, "y": 2.5, "z": 1.7, "rot": 2, "face": "+z"},
				{"part": "28192", "color": 92, "x": 6, "y": 2.5, "z": 1.7, "rot": 2, "face": "+z"},
				{"part": "24246", "color": 92, "x": 2, "y": 0, "z": 2.5, "rot": 0, "face": "+z"},
				{"part": "24246", "color": 92, "x": 4, "y": 0, "z": 2.5, "rot": 0, "face": "+z"},
				{"part": "24246", "color": 92, "x": 6, "y": 0, "z": 2.5, "rot": 0, "face": "+z"},
				{"part": "24246", "color": 70, "x": 1, "y": 0, "z": 2.5, "rot": 0, "face": "+z"},
				{"part": "24246", "color": 70, "x": 3, "y": 0, "z": 2.5, "rot": 0, "face": "+z"},
				{"part": "24246", "color": 70, "x": 5, "y": 0, "z": 2.5, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "arched window",
			"group": "windows and doors",
			"when": "a tall window in a hall, a library, a chapel or a shop",
			"why": "Four 1 x 2 x 2 windows (60592) in a block under a half-round 1 x 4 window top (20309), with curved-top 1 x 1 bricks laid on their sides along a brick with studs on its side for the sill. As the LEGO Group built it in 10270 Bookshop: 14 parts, from LDraw's model repository (model by Ulrich Röder, CC BY 2.0).",
			"bricks": [
				{"part": "30414", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "49307", "color": 71, "x": 1, "y": 0.5, "z": 0, "rot": 1, "face": "+x"},
				{"part": "49307", "color": 71, "x": 1, "y": 0.5, "z": 1, "rot": 1, "face": "+x"},
				{"part": "49307", "color": 71, "x": 1, "y": 0.5, "z": 2, "rot": 1, "face": "+x"},
				{"part": "49307", "color": 71, "x": 1, "y": 0.5, "z": 3, "rot": 1, "face": "+x"},
				{"part": "60592", "color": 15, "x": 0, "y": 3, "z": 2, "rot": 1},
				{"part": "60601", "color": 47, "x": 0.6, "y": 4, "z": 2.2, "rot": 1},
				{"part": "60601", "color": 47, "x": 0.6, "y": 4, "z": 0.2, "rot": 1},
				{"part": "60592", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 1},
				{"part": "60601", "color": 47, "x": 0.6, "y": 10, "z": 0.2, "rot": 1},
				{"part": "60592", "color": 15, "x": 0, "y": 9, "z": 0, "rot": 1},
				{"part": "60601", "color": 47, "x": 0.6, "y": 10, "z": 2.2, "rot": 1},
				{"part": "60592", "color": 15, "x": 0, "y": 9, "z": 2, "rot": 1},
				{"part": "20309", "color": 15, "x": 0, "y": 15, "z": 0, "rot": 1},
			],
		},
		{
			"name": "window with shutters",
			"group": "windows and doors",
			"when": "a house, an inn, a townhouse front",
			"why": "The shutters are bricks and tiles turned sideways on 1 x 2 door-rail plates (32028) either side of two 60592 windows, so they lie flat on the wall in a second colour. As the LEGO Group built it in 10243 Parisian Restaurant: 27 parts, from LDraw's model repository (model by Willy Tschager, CC BY 2.0).",
			"bricks": [
				{"part": "99206", "color": 15, "x": 0, "y": 0, "z": 4, "rot": 0},
				{"part": "99206", "color": 15, "x": 0, "y": 0, "z": 2, "rot": 2},
				{"part": "3022", "color": 15, "x": 0, "y": 1, "z": 3, "rot": 0},
				{"part": "3069b", "color": 308, "x": 0, "y": 2, "z": 4, "rot": 3},
				{"part": "3069b", "color": 308, "x": 0, "y": 2, "z": 2, "rot": 3},
				{"part": "60592c01", "color": 15, "x": 1, "y": 2, "z": 4, "rot": 1},
				{"part": "60592c01", "color": 15, "x": 1, "y": 2, "z": 2, "rot": 1},
				{"part": "60592c01", "color": 15, "x": 1, "y": 8, "z": 2, "rot": 1},
				{"part": "60592c01", "color": 15, "x": 1, "y": 8, "z": 4, "rot": 1},
				{"part": "3024", "color": 15, "x": 0, "y": 0, "z": 6, "rot": 1, "face": "+z"},
				{"part": "32028", "color": 15, "x": 1, "y": 0, "z": 6, "rot": 1, "face": "+z"},
				{"part": "32028", "color": 15, "x": 1, "y": 5, "z": 6, "rot": 1, "face": "+z"},
				{"part": "32028", "color": 15, "x": 1, "y": 10, "z": 6, "rot": 1, "face": "+z"},
				{"part": "3004", "color": 330, "x": 0, "y": 0, "z": 6.4, "rot": 0, "face": "+z"},
				{"part": "3004", "color": 330, "x": 1, "y": 2.5, "z": 6.4, "rot": 1, "face": "+z"},
				{"part": "3622", "color": 330, "x": 1, "y": 7.5, "z": 6.4, "rot": 1, "face": "+z"},
				{"part": "3070b", "color": 15, "x": 0, "y": 0, "z": 7.6, "rot": 1, "face": "+z"},
				{"part": "6636", "color": 330, "x": 1, "y": 0, "z": 7.6, "rot": 1, "face": "+z"},
				{"part": "3024", "color": 15, "x": 0, "y": 0, "z": 1.6, "rot": 1, "face": "-z"},
				{"part": "32028", "color": 15, "x": 1, "y": 0, "z": 1.6, "rot": 1, "face": "-z"},
				{"part": "32028", "color": 15, "x": 1, "y": 5, "z": 1.6, "rot": 1, "face": "-z"},
				{"part": "32028", "color": 15, "x": 1, "y": 10, "z": 1.6, "rot": 1, "face": "-z"},
				{"part": "3004", "color": 330, "x": 0, "y": 0, "z": 0.4, "rot": 0, "face": "-z"},
				{"part": "3004", "color": 330, "x": 1, "y": 2.5, "z": 0.4, "rot": 1, "face": "-z"},
				{"part": "3622", "color": 330, "x": 1, "y": 7.5, "z": 0.4, "rot": 1, "face": "-z"},
				{"part": "3070b", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 1, "face": "-z"},
				{"part": "6636", "color": 330, "x": 1, "y": 0, "z": 0, "rot": 1, "face": "-z"},
			],
		},
		{
			"name": "postern arch",
			"group": "windows and doors",
			"when": "a small door or window head in a castle wall",
			"why": "A 1 x 3 arch (4490) in a wall of 1 x 1 and 1 x 2 bricks, with an inverted slope beside it stepping the wall out. As the LEGO Group built it in 6080 King's Castle: 6 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "3004", "color": 7, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "3005", "color": 7, "x": 3, "y": 0, "z": 0, "rot": 1},
				{"part": "3665a", "color": 7, "x": 4, "y": 0, "z": 0, "rot": 1},
				{"part": "3005", "color": 7, "x": 0, "y": 3, "z": 0, "rot": 1},
				{"part": "4490", "color": 7, "x": 1, "y": 3, "z": 0, "rot": 2},
				{"part": "3005", "color": 7, "x": 4, "y": 3, "z": 0, "rot": 1},
			],
		},
		{
			"name": "rock outcrop",
			"group": "rock and ground",
			"when": "a crag, a cliff face, the rock a tower or a forge stands on",
			"why": "Slopes, inverted slopes, a 2 x 2 double concave slope and a 65 slope stacked so each face leans a different way, with dark green bricks for moss. Rock is slopes in two greys at many angles, never a stack of bricks. As the LEGO Group built it in 9476 The Orc Forge: 10 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "3004", "color": 288, "x": 0, "y": 0, "z": 2, "rot": 3},
				{"part": "3005", "color": 288, "x": 0, "y": 3, "z": 2, "rot": 3},
				{"part": "3665a", "color": 72, "x": 0, "y": 3, "z": 3, "rot": 0},
				{"part": "3046", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "3040b", "color": 72, "x": 1, "y": 3, "z": 0, "rot": 2},
				{"part": "3665a", "color": 72, "x": 0, "y": 3, "z": 0, "rot": 2},
				{"part": "60481a", "color": 71, "x": 2, "y": 0, "z": 0, "rot": 2},
				{"part": "3710", "color": 28, "x": 0, "y": 6, "z": 1, "rot": 2},
				{"part": "3005", "color": 288, "x": 0, "y": 7, "z": 1, "rot": 3},
				{"part": "3040b", "color": 72, "x": 1, "y": 7, "z": 1, "rot": 0},
			],
		},
		{
			"name": "rocky ground with plants",
			"group": "rock and ground",
			"when": "the ground a castle, an outpost or a ruin stands on",
			"why": "Bricks and plates in grey stepped to different heights, the edges softened with hinged car-roof plates, and plant leaves (2423) growing out of the cracks. As the LEGO Group built it in 6066 Camouflaged Outpost: 13 parts, from LDraw's model repository (model by Takeshi Takahashi, CC BY 2.0).",
			"bricks": [
				{"part": "3036", "color": 7, "x": 0, "y": 0, "z": 3, "rot": 0},
				{"part": "3034", "color": 7, "x": 0, "y": 0, "z": 9, "rot": 0},
				{"part": "3795", "color": 7, "x": 0, "y": 1, "z": 5, "rot": 3},
				{"part": "3795", "color": 7, "x": 6, "y": 1, "z": 5, "rot": 3},
				{"part": "4213", "color": 7, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "4213", "color": 7, "x": 4, "y": 1, "z": 1, "rot": 0},
				{"part": "3001", "color": 7, "x": 3, "y": 1, "z": 6, "rot": 3},
				{"part": "3002", "color": 7, "x": 5, "y": 2, "z": 4, "rot": 3},
				{"part": "3002", "color": 7, "x": 2, "y": 2, "z": 3, "rot": 0},
				{"part": "3003", "color": 7, "x": 0, "y": 2, "z": 4, "rot": 0},
				{"part": "2423", "color": 2, "x": 0, "y": 2, "z": 7, "rot": 2},
				{"part": "2423", "color": 2, "x": 3, "y": 4, "z": 6, "rot": 2},
				{"part": "2423", "color": 2, "x": 1, "y": 5, "z": 3, "rot": 1},
			],
		},
		{
			"name": "stone with ivy",
			"group": "rock and ground",
			"when": "a wall, a gatepost or a ruin that has been there a long time",
			"why": "Plant leaves (2417) clipped to a bracket turned on its side, so the ivy climbs the face of the stone rather than standing on top of it. As the LEGO Group built it in 6071 Forestmen's Crossing: 14 parts, from LDraw's model repository (model by Takeshi Takahashi, CC BY 2.0).",
			"bricks": [
				{"part": "3023b", "color": 7, "x": 2, "y": 0, "z": 1, "rot": 0},
				{"part": "3710", "color": 7, "x": 1, "y": 1, "z": 1, "rot": 0},
				{"part": "3831", "color": 7, "x": 1, "y": 2, "z": 1, "rot": 2},
				{"part": "3003", "color": 7, "x": 3, "y": 2, "z": 1, "rot": 0},
				{"part": "3010", "color": 7, "x": 1, "y": 5, "z": 1, "rot": 0},
				{"part": "3010", "color": 7, "x": 1, "y": 8, "z": 1, "rot": 0},
				{"part": "3831", "color": 7, "x": 1, "y": 11, "z": 1, "rot": 2},
				{"part": "3004", "color": 7, "x": 3, "y": 11, "z": 1, "rot": 0},
				{"part": "3024", "color": 7, "x": 1, "y": 14, "z": 1, "rot": 0},
				{"part": "3024", "color": 7, "x": 4, "y": 14, "z": 1, "rot": 0},
				{"part": "2436a", "color": 7, "x": 1, "y": 12.5, "z": 1, "rot": 0},
				{"part": "3040b", "color": 7, "x": 1, "y": 15, "z": 1, "rot": 3},
				{"part": "3040b", "color": 7, "x": 3, "y": 15, "z": 1, "rot": 1},
				{"part": "2417", "color": 2, "x": 0.1, "y": 5.25, "z": 2.2, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "cobbled path",
			"group": "rock and ground",
			"when": "a path to a door, a yard, a village street",
			"why": "Round 1 x 1 tiles (98138) in dark tan and 3 x 3 round tiles (67095) set on a nougat plate with a rounded end, on olive green ground: a path that is not a rectangle. As the LEGO Group built it in 21325 Medieval Blacksmith: 16 parts, from LDraw's model repository (model by Vincent Messenet, CC BY 2.0).",
			"bricks": [
				{"part": "3034", "color": 330, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3034", "color": 330, "x": 1, "y": 1, "z": 1, "rot": 0},
				{"part": "41948", "color": 84, "x": 0, "y": 0, "z": 2, "rot": 0},
				{"part": "67095", "color": 84, "x": 1, "y": 1, "z": 3, "rot": 0},
				{"part": "67095", "color": 84, "x": 5, "y": 1, "z": 5, "rot": 0},
				{"part": "3023b", "color": 330, "x": 4, "y": 1, "z": 3, "rot": 3},
				{"part": "33909", "color": 71, "x": 5, "y": 1, "z": 3, "rot": 0},
				{"part": "33909", "color": 71, "x": 7, "y": 1, "z": 3, "rot": 0},
				{"part": "3068b", "color": 28, "x": 1, "y": 1, "z": 6, "rot": 0},
				{"part": "98138", "color": 28, "x": 0, "y": 1, "z": 5, "rot": 0},
				{"part": "98138", "color": 28, "x": 2, "y": 1, "z": 8, "rot": 0},
				{"part": "98138", "color": 28, "x": 3, "y": 1, "z": 9, "rot": 0},
				{"part": "98138", "color": 28, "x": 4, "y": 1, "z": 9, "rot": 0},
				{"part": "98138", "color": 28, "x": 5, "y": 1, "z": 8, "rot": 0},
				{"part": "98138", "color": 28, "x": 3, "y": 1, "z": 6, "rot": 0},
				{"part": "98138", "color": 28, "x": 4, "y": 1, "z": 5, "rot": 0},
			],
		},
		{
			"name": "staircase",
			"group": "rock and ground",
			"when": "a stair inside a building or up to a door",
			"why": "4 x 4 facet bricks (14413) turned on their sides make the treads and the slope under them in one part each, and triangular tiles (35787) make the stringer: a staircase that is smooth underneath. As the LEGO Group built it in 10278 Police Station: 7 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "14413", "color": 71, "x": 0.5, "y": 0, "z": 2.6, "rot": 3, "face": "+z"},
				{"part": "14413", "color": 71, "x": 0.5, "y": 0, "z": 1.4, "rot": 3, "face": "+z"},
				{"part": "14413", "color": 71, "x": 0.5, "y": 0, "z": 0.2, "rot": 3, "face": "+z"},
				{"part": "3069b", "color": 0, "x": 0.5, "y": 5, "z": 3.8, "rot": 3, "face": "+z"},
				{"part": "35787", "color": 0, "x": 1.5, "y": 5, "z": 3.8, "rot": 0, "face": "+z"},
				{"part": "35787", "color": 0, "x": 1.6, "y": 0.25, "z": 3.8, "rot": 2, "face": "+z"},
				{"part": "35787", "color": 0, "x": 3.5, "y": 0, "z": 3.8, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "hedge with flowers",
			"group": "plants",
			"when": "a garden, a courtyard, a window box, the foot of a wall",
			"why": "Bricks with studs on one side (11211) carry corner-round tiles turned out, so the hedge has a soft rounded face, with petal plates (24866) on its top and on its side. As the LEGO Group built it in 10297 Boutique Hotel: 10 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "3710", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "11211", "color": 2, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "11211", "color": 2, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "25269", "color": 2, "x": 0, "y": 1.5, "z": 1, "rot": 0, "face": "+z"},
				{"part": "25269", "color": 2, "x": 1, "y": 1.5, "z": 1, "rot": 3, "face": "+z"},
				{"part": "25269", "color": 2, "x": 3, "y": 1.5, "z": 1, "rot": 3, "face": "+z"},
				{"part": "25269", "color": 2, "x": 3, "y": 4, "z": 0, "rot": 3},
				{"part": "25269", "color": 2, "x": 0, "y": 4, "z": 0, "rot": 0},
				{"part": "24866", "color": 353, "x": 1, "y": 4, "z": 0, "rot": 0},
				{"part": "24866", "color": 353, "x": 2, "y": 1.5, "z": 1, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "clipped hedge",
			"group": "plants",
			"when": "a formal garden, a palace or a manor's grounds",
			"why": "Headlight bricks with cheese slopes turned to both sides and corner-round tiles on top: a hedge with its corners clipped round. As the LEGO Group built it in 10359 Fountain Garden: 9 parts, from LDraw's model repository (model by Orion Pobursky, CC BY 4.0).",
			"bricks": [
				{"part": "3623", "color": 0, "x": 1, "y": 0, "z": 0, "rot": 0},
				{"part": "4070", "color": 288, "x": 1, "y": 1, "z": 0, "rot": 3},
				{"part": "4070", "color": 288, "x": 3, "y": 1, "z": 0, "rot": 1},
				{"part": "3005", "color": 288, "x": 2, "y": 1, "z": 0, "rot": 1},
				{"part": "54200", "color": 288, "x": 3.8, "y": 1.5, "z": 0, "rot": 0, "face": "+x"},
				{"part": "54200", "color": 288, "x": 0.4, "y": 1.5, "z": 0, "rot": 2, "face": "-x"},
				{"part": "25269", "color": 288, "x": 1, "y": 4, "z": 0, "rot": 1},
				{"part": "25269", "color": 288, "x": 3, "y": 4, "z": 0, "rot": 1},
				{"part": "25269", "color": 288, "x": 2, "y": 4, "z": 0, "rot": 3},
			],
		},
		{
			"name": "leafy plant",
			"group": "plants",
			"when": "a pot, a corner of a garden, a forest floor",
			"why": "Tooth plates (49668) in two greens fanned out from a corner plate: leaves out of one small part used for what it looks like. As the LEGO Group built it in 5766 Log Cabin: 10 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "2420", "color": 70, "x": 1, "y": 0, "z": 1, "rot": 0},
				{"part": "49668", "color": 288, "x": 2, "y": 1, "z": 2, "rot": 0},
				{"part": "49668", "color": 27, "x": 1, "y": 1, "z": 2, "rot": 0},
				{"part": "49668", "color": 288, "x": 0, "y": 1, "z": 1, "rot": 3},
				{"part": "49668", "color": 27, "x": 0, "y": 2, "z": 1, "rot": 3},
				{"part": "49668", "color": 288, "x": 0, "y": 2, "z": 2, "rot": 3},
				{"part": "49668", "color": 27, "x": 2, "y": 2, "z": 2, "rot": 0},
				{"part": "49668", "color": 27, "x": 2, "y": 3, "z": 2, "rot": 1},
				{"part": "49668", "color": 288, "x": 1, "y": 3, "z": 2, "rot": 0},
				{"part": "49668", "color": 288, "x": 1, "y": 3, "z": 0, "rot": 2},
			],
		},
		{
			"name": "flower bed",
			"group": "plants",
			"when": "a garden, a border along a path or a wall",
			"why": "Round plates and 1 x 1 cones in red, yellow and orange on lime round plates for leaves, on a green plate: three colours of one-off parts in a dozen pieces. As the LEGO Group built it in 5891 Apple Tree House: 13 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "3020", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "6141", "color": 14, "x": 3, "y": 1, "z": 1, "rot": 0},
				{"part": "6141", "color": 4, "x": 1, "y": 1, "z": 1, "rot": 0},
				{"part": "6141", "color": 14, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "6141", "color": 27, "x": 2, "y": 1, "z": 1, "rot": 0},
				{"part": "6141", "color": 27, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "6141", "color": 27, "x": 1, "y": 1, "z": 0, "rot": 0},
				{"part": "6141", "color": 27, "x": 3, "y": 1, "z": 0, "rot": 0},
				{"part": "59900", "color": 14, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "59900", "color": 4, "x": 0, "y": 2, "z": 0, "rot": 0},
				{"part": "6141", "color": 14, "x": 1, "y": 2, "z": 0, "rot": 0},
				{"part": "6141", "color": 4, "x": 2, "y": 2, "z": 1, "rot": 0},
				{"part": "6141", "color": 25, "x": 3, "y": 2, "z": 0, "rot": 0},
			],
		},
		{
			"name": "bookcase",
			"group": "furniture and interiors",
			"when": "a library, a study, a wizard's tower, a shop",
			"why": "Books are bricks with studs on their sides and tiles turned out on them, in several colours and heights, in a frame of reddish brown tiles turned sideways. As the LEGO Group built it in 10270 Bookshop: 30 parts, from LDraw's model repository (model by Ulrich Röder, CC BY 2.0).",
			"bricks": [
				{"part": "3020", "color": 70, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "87580", "color": 70, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "87580", "color": 70, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "3024", "color": 378, "x": 2.5, "y": 2, "z": 0.5, "rot": 0},
				{"part": "3024", "color": 378, "x": 2.5, "y": 3, "z": 0.5, "rot": 0},
				{"part": "32028", "color": 71, "x": 2.1, "y": 2, "z": 0.5, "rot": 0, "face": "-x"},
				{"part": "47905", "color": 378, "x": 2.5, "y": 4, "z": 0.5, "rot": 1},
				{"part": "32952", "color": 272, "x": 0.5, "y": 2, "z": 0.5, "rot": 3},
				{"part": "3069b", "color": 3, "x": 1.7, "y": 2, "z": 0.5, "rot": 0, "face": "-x"},
				{"part": "63864", "color": 70, "x": 0.5, "y": 7, "z": 0.5, "rot": 0},
				{"part": "4162", "color": 70, "x": 0.1, "y": 2, "z": 0.5, "rot": 2, "face": "-x"},
				{"part": "63864", "color": 70, "x": 0.5, "y": 13, "z": 0.5, "rot": 0},
				{"part": "4162", "color": 70, "x": 3.5, "y": 2, "z": 0.5, "rot": 0, "face": "+x"},
				{"part": "32028", "color": 71, "x": 2.5, "y": 8, "z": 0.5, "rot": 0, "face": "+x"},
				{"part": "3024", "color": 84, "x": 0.5, "y": 8, "z": 0.5, "rot": 0},
				{"part": "3024", "color": 84, "x": 0.5, "y": 12, "z": 0.5, "rot": 0},
				{"part": "3024", "color": 1, "x": 2.5, "y": 17, "z": 0.5, "rot": 0},
				{"part": "3024", "color": 1, "x": 2.5, "y": 18, "z": 0.5, "rot": 0},
				{"part": "87087", "color": 1, "x": 0.5, "y": 9, "z": 0.5, "rot": 3},
				{"part": "87087", "color": 1, "x": 2.5, "y": 14, "z": 0.5, "rot": 1},
				{"part": "32952", "color": 25, "x": 1.5, "y": 8, "z": 0.5, "rot": 1},
				{"part": "3069b", "color": 4, "x": 2.9, "y": 8, "z": 0.5, "rot": 0, "face": "+x"},
				{"part": "32028", "color": 71, "x": 1.5, "y": 14, "z": 0.5, "rot": 0, "face": "+x"},
				{"part": "32952", "color": 4, "x": 0.5, "y": 14, "z": 0.5, "rot": 1},
				{"part": "3069b", "color": 3, "x": 1.9, "y": 14, "z": 0.5, "rot": 0, "face": "+x"},
				{"part": "87079", "color": 70, "x": 0, "y": 22, "z": 0, "rot": 0},
				{"part": "26604", "color": 0, "x": 2.5, "y": 19, "z": 0.5, "rot": 0},
				{"part": "26604", "color": 0, "x": 0.5, "y": 19, "z": 0.5, "rot": 3},
				{"part": "87087", "color": 0, "x": 1.5, "y": 19, "z": 0.5, "rot": 0},
				{"part": "2431", "color": 70, "x": 0, "y": 19.5, "z": 1.5, "rot": 0, "face": "+z"},
			],
		},
		{
			"name": "fireplace",
			"group": "furniture and interiors",
			"when": "a hall, a cabin, an inn, a castle's great room",
			"why": "A chimney breast of 1 x 4 bricks and 45 slopes with a 1 x 4 arch over the firebox, trans-neon-orange round plates for the fire, and a pair of horns on clip plates over the mantel. As the LEGO Group built it in 5766 Log Cabin: 24 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "3020", "color": 2, "x": 1, "y": 0, "z": 0, "rot": 0},
				{"part": "6141", "color": 38, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "6141", "color": 38, "x": 2, "y": 2, "z": 0, "rot": 0},
				{"part": "6141", "color": 38, "x": 3, "y": 1, "z": 0, "rot": 0},
				{"part": "6141", "color": 38, "x": 3, "y": 2, "z": 0, "rot": 0},
				{"part": "4865a", "color": 71, "x": 2, "y": 1, "z": 1, "rot": 2},
				{"part": "3040b", "color": 71, "x": 1, "y": 1, "z": 0, "rot": 0},
				{"part": "3040b", "color": 71, "x": 4, "y": 1, "z": 0, "rot": 0},
				{"part": "3659", "color": 71, "x": 1, "y": 4, "z": 0, "rot": 0},
				{"part": "3010", "color": 71, "x": 1, "y": 7, "z": 0, "rot": 0},
				{"part": "4081b", "color": 15, "x": 2, "y": 9.75, "z": 0, "rot": 0},
				{"part": "4081b", "color": 15, "x": 3, "y": 9.75, "z": 0, "rot": 0},
				{"part": "3024", "color": 19, "x": 1, "y": 10, "z": 0, "rot": 0},
				{"part": "3024", "color": 19, "x": 4, "y": 10, "z": 0, "rot": 0},
				{"part": "3023b", "color": 70, "x": 1, "y": 11, "z": 0, "rot": 0},
				{"part": "3023b", "color": 70, "x": 3, "y": 11, "z": 0, "rot": 0},
				{"part": "3010", "color": 71, "x": 1, "y": 12, "z": 0, "rot": 0},
				{"part": "3010", "color": 71, "x": 1, "y": 15, "z": 0, "rot": 0},
				{"part": "53451", "color": 15, "x": 0.8, "y": 10.25, "z": 1.3, "rot": 1},
				{"part": "53451", "color": 15, "x": 3.5, "y": 10.25, "z": 1.3, "rot": 3},
				{"part": "3623", "color": 19, "x": 1, "y": 18, "z": 0, "rot": 0},
				{"part": "3024", "color": 19, "x": 4, "y": 18, "z": 0, "rot": 0},
				{"part": "3040b", "color": 71, "x": 1, "y": 19, "z": 0, "rot": 3},
				{"part": "3040b", "color": 71, "x": 3, "y": 19, "z": 0, "rot": 1},
			],
		},
		{
			"name": "hearth",
			"group": "furniture and interiors",
			"when": "a kitchen, a cottage, a camp, a hobbit hole",
			"why": "A low cooking hearth in dark grey: round 1 x 1 bricks for the flue, a panel for the back and a brick with studs on its side for the front. As the LEGO Group built it in 30210 Frodo with Cooking Corner: 8 parts, from LDraw's model repository (model by Stan Isachenko, CC BY 2.0).",
			"bricks": [
				{"part": "11211", "color": 0, "x": 1, "y": 0, "z": 0, "rot": 0},
				{"part": "3004", "color": 72, "x": 3, "y": 0, "z": 0, "rot": 1},
				{"part": "3004", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "3020", "color": 0, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "4865b", "color": 72, "x": 1, "y": 4, "z": 0, "rot": 0},
				{"part": "3069b", "color": 72, "x": 1, "y": 4, "z": 1, "rot": 0},
				{"part": "3062b", "color": 72, "x": 0, "y": 4, "z": 0, "rot": 0},
				{"part": "3062b", "color": 72, "x": 3, "y": 4, "z": 0, "rot": 0},
			],
		},
		{
			"name": "anvil",
			"group": "furniture and interiors",
			"when": "a forge, a smithy, a dwarf or an orc's workshop",
			"why": "An inverted dish (4740) for the base and a brick with studs on two sides (47905) with cheese slopes and round plates turned out to make the horn and the heel: six parts that read as nothing else. As the LEGO Group built it in 9476 The Orc Forge: 7 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "4740", "color": 0, "x": 0, "y": 0, "z": 1, "rot": 0},
				{"part": "47905", "color": 0, "x": 0.5, "y": 2, "z": 1.5, "rot": 0},
				{"part": "6141", "color": 0, "x": 0.5, "y": 2.5, "z": 2.5, "rot": 0, "face": "+z"},
				{"part": "6141", "color": 0, "x": 0.5, "y": 2.5, "z": 1.1, "rot": 0, "face": "-z"},
				{"part": "54200", "color": 0, "x": 0.5, "y": 2.5, "z": 0.3, "rot": 2, "face": "-z"},
				{"part": "54200", "color": 0, "x": 0.5, "y": 2.5, "z": 2.9, "rot": 0, "face": "+z"},
				{"part": "6141", "color": 0, "x": 0.5, "y": 1, "z": 1.5, "rot": 0},
			],
		},
		{
			"name": "chest",
			"group": "furniture and interiors",
			"when": "a treasure room, a bedroom, a ship's hold, a dungeon",
			"why": "Two curved-top 1 x 1 bricks (49307) on a plate make the domed lid, and a plate with a clip on its side (11476) the lock. As the LEGO Group built it in 10267 Gingerbread House: 4 parts, from LDraw's model repository (model by Orion Pobursky, CC BY 2.0).",
			"bricks": [
				{"part": "3023b", "color": 30, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "11476", "color": 27, "x": 0, "y": 0.75, "z": 0, "rot": 0},
				{"part": "49307", "color": 30, "x": 0, "y": 2, "z": 0, "rot": 0},
				{"part": "49307", "color": 30, "x": 1, "y": 2, "z": 0, "rot": 0},
			],
		},
		{
			"name": "potion shelf",
			"group": "furniture and interiors",
			"when": "a wizard's study, an apothecary, a kitchen wall",
			"why": "A bracket (99780) turned up off the wall carries a plate with three transparent round 1 x 1 bricks for bottles: a shelf that hangs on the wall rather than standing on the floor. As the LEGO Group built it in 75953 Hogwarts Whomping Willow: 5 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "99780", "color": 70, "x": 1, "y": 0, "z": 1, "rot": 2},
				{"part": "3062b", "color": 33, "x": 1, "y": 1, "z": 1, "rot": 2},
				{"part": "3062b", "color": 34, "x": 2, "y": 1, "z": 1, "rot": 2},
				{"part": "3023b", "color": 70, "x": 1, "y": 4, "z": 1, "rot": 2},
				{"part": "3062b", "color": 47, "x": 2, "y": 5, "z": 1, "rot": 2},
			],
		},
		{
			"name": "dresser",
			"group": "furniture and interiors",
			"when": "a kitchen, an inn, a dining room",
			"why": "Headlight bricks stacked in reddish brown with jumper plates turned out on their faces for drawer fronts and handles, and bottles on top. As the LEGO Group built it in 10243 Parisian Restaurant: 22 parts, from LDraw's model repository (model by Willy Tschager, CC BY 2.0).",
			"bricks": [
				{"part": "3710", "color": 0, "x": 0.8, "y": 1.5, "z": 0, "rot": 1, "face": "+x"},
				{"part": "4070", "color": 70, "x": 0, "y": 1, "z": 0, "rot": 1},
				{"part": "4070", "color": 70, "x": 0, "y": 1, "z": 1, "rot": 1},
				{"part": "4070", "color": 70, "x": 0, "y": 1, "z": 2, "rot": 1},
				{"part": "4070", "color": 70, "x": 0, "y": 1, "z": 3, "rot": 1},
				{"part": "15573", "color": 70, "x": 1.2, "y": 1.5, "z": 2, "rot": 1, "face": "+x"},
				{"part": "15573", "color": 70, "x": 1.2, "y": 1.5, "z": 0, "rot": 1, "face": "+x"},
				{"part": "3710", "color": 0, "x": 0.8, "y": 4.5, "z": 0, "rot": 1, "face": "+x"},
				{"part": "4070", "color": 70, "x": 0, "y": 4, "z": 0, "rot": 1},
				{"part": "4070", "color": 70, "x": 0, "y": 4, "z": 1, "rot": 1},
				{"part": "4070", "color": 70, "x": 0, "y": 4, "z": 2, "rot": 1},
				{"part": "4070", "color": 70, "x": 0, "y": 4, "z": 3, "rot": 1},
				{"part": "15573", "color": 70, "x": 1.2, "y": 4.5, "z": 2, "rot": 1, "face": "+x"},
				{"part": "15573", "color": 70, "x": 1.2, "y": 4.5, "z": 0, "rot": 1, "face": "+x"},
				{"part": "32028", "color": 0, "x": 0, "y": 7, "z": 2, "rot": 1},
				{"part": "32028", "color": 0, "x": 0, "y": 7, "z": 0, "rot": 1},
				{"part": "32028", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "32028", "color": 0, "x": 0, "y": 0, "z": 2, "rot": 1},
				{"part": "95228", "color": 34, "x": 0, "y": 8, "z": 3, "rot": 1},
				{"part": "95228", "color": 47, "x": 0, "y": 8, "z": 2, "rot": 1},
				{"part": "95228", "color": 34, "x": 0, "y": 8, "z": 1, "rot": 1},
				{"part": "95228", "color": 40, "x": 0, "y": 8, "z": 0, "rot": 1},
			],
		},
		{
			"name": "sofa",
			"group": "furniture and interiors",
			"when": "a parlour, a hotel lounge, a sitting room",
			"why": "Bricks with curved tops for the back and the cushions, 2 x 2 bricks with a curved corner for the arms, on round plates for feet. As the LEGO Group built it in 10297 Boutique Hotel: 25 parts, from LDraw's model repository (model by Philippe Hurbain, CC BY 2.0).",
			"bricks": [
				{"part": "3460", "color": 0, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3020", "color": 320, "x": 4, "y": 2, "z": 0, "rot": 0},
				{"part": "3034", "color": 0, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "3020", "color": 320, "x": 0, "y": 2, "z": 0, "rot": 0},
				{"part": "3710", "color": 320, "x": 4, "y": 2, "z": 2, "rot": 0},
				{"part": "3710", "color": 320, "x": 0, "y": 2, "z": 2, "rot": 0},
				{"part": "85861", "color": 0, "x": 0, "y": 0, "z": 2, "rot": 0},
				{"part": "85861", "color": 0, "x": 7, "y": 0, "z": 2, "rot": 0},
				{"part": "85861", "color": 0, "x": 7, "y": 0, "z": 0, "rot": 0},
				{"part": "85861", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3710", "color": 320, "x": 2, "y": 3, "z": 0, "rot": 0},
				{"part": "3004", "color": 320, "x": 6, "y": 3, "z": 0, "rot": 0},
				{"part": "3004", "color": 320, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "37352", "color": 320, "x": 4, "y": 4, "z": 0, "rot": 0},
				{"part": "37352", "color": 320, "x": 2, "y": 4, "z": 0, "rot": 0},
				{"part": "3024", "color": 320, "x": 7, "y": 3, "z": 1, "rot": 0},
				{"part": "3024", "color": 320, "x": 7, "y": 4, "z": 1, "rot": 0},
				{"part": "3024", "color": 320, "x": 0, "y": 3, "z": 1, "rot": 0},
				{"part": "3024", "color": 320, "x": 0, "y": 4, "z": 1, "rot": 0},
				{"part": "67810", "color": 320, "x": 6, "y": 3, "z": 1, "rot": 0},
				{"part": "67810", "color": 320, "x": 0, "y": 3, "z": 1, "rot": 1},
				{"part": "25269", "color": 320, "x": 1, "y": 6, "z": 0, "rot": 0},
				{"part": "25269", "color": 320, "x": 6, "y": 6, "z": 0, "rot": 3},
				{"part": "3069b", "color": 320, "x": 0, "y": 6, "z": 0, "rot": 3},
				{"part": "3069b", "color": 320, "x": 7, "y": 6, "z": 0, "rot": 3},
			],
		},
		{
			"name": "four-poster bed",
			"group": "furniture and interiors",
			"when": "a castle bedchamber, a manor, a treehouse",
			"why": "The posts are oars held upside down in clip plates, and a curved slope makes the pillow end of the bedding. As the LEGO Group built it in 21318 Tree House: 17 parts, from LDraw's model repository (model by Orion Pobursky, CC BY 2.0).",
			"bricks": [
				{"part": "3021", "color": 70, "x": 2.5, "y": 2, "z": 1, "rot": 0},
				{"part": "3710", "color": 70, "x": 4.5, "y": 3, "z": 0, "rot": 3},
				{"part": "3020", "color": 70, "x": 2.5, "y": 3, "z": 0, "rot": 3},
				{"part": "34103", "color": 70, "x": 2.5, "y": 4, "z": 0, "rot": 0},
				{"part": "32124", "color": 70, "x": 1.5, "y": 2, "z": 3, "rot": 0},
				{"part": "60897", "color": 70, "x": 0.5, "y": 3, "z": 3, "rot": 3},
				{"part": "60897", "color": 70, "x": 5.5, "y": 3, "z": 3, "rot": 1},
				{"part": "3020", "color": 191, "x": 1.5, "y": 4, "z": 2, "rot": 0},
				{"part": "3023b", "color": 191, "x": 1.5, "y": 5, "z": 2, "rot": 3},
				{"part": "3068b", "color": 191, "x": 2.5, "y": 5, "z": 2, "rot": 3},
				{"part": "15068", "color": 191, "x": 4.5, "y": 4, "z": 2, "rot": 1},
				{"part": "49307", "color": 15, "x": 1.5, "y": 6, "z": 2, "rot": 1},
				{"part": "49307", "color": 15, "x": 1.5, "y": 6, "z": 3, "rot": 1},
				{"part": "4070", "color": 70, "x": 1.5, "y": 0, "z": 3, "rot": 0, "face": "-z"},
				{"part": "4070", "color": 70, "x": 5.5, "y": 0, "z": 3, "rot": 0, "face": "-z"},
				{"part": "87585", "color": 70, "x": 0.8, "y": 0, "z": 3, "rot": 3, "face": "down"},
				{"part": "87585", "color": 70, "x": 6.8, "y": 0, "z": 3, "rot": 3, "face": "down"},
			],
		},
		{
			"name": "log pile",
			"group": "furniture and interiors",
			"when": "beside a forge, a cabin, a hearth, a woodshed",
			"why": "Round 1 x 1 bricks laid on their sides with tree-stump round tiles on the ends: a pile of logs from parts turned sideways. As the LEGO Group built it in 21325 Medieval Blacksmith: 20 parts, from LDraw's model repository (model by Vincent Messenet, CC BY 2.0).",
			"bricks": [
				{"part": "3710", "color": 70, "x": 3.2, "y": 0, "z": 0, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 0, "z": 0, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 0, "z": 1, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 0, "z": 2, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 0, "z": 3, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 0.8, "y": 0, "z": 1, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 0.8, "y": 0, "z": 2, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 0.8, "y": 0, "z": 3, "rot": 3, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 1.6, "y": 0, "z": 0, "rot": 0, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 0.4, "y": 0, "z": 1, "rot": 0, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 0.4, "y": 0, "z": 2, "rot": 0, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 0.4, "y": 0, "z": 3, "rot": 0, "face": "-x"},
				{"part": "3623", "color": 70, "x": 3.2, "y": 2.5, "z": 0.5, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 2.5, "z": 0.5, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 2.5, "z": 1.5, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 2, "y": 2.5, "z": 2.5, "rot": 3, "face": "-x"},
				{"part": "3062b", "color": 308, "x": 0.8, "y": 2.5, "z": 2.5, "rot": 3, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 1.6, "y": 2.5, "z": 0.5, "rot": 0, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 1.6, "y": 2.5, "z": 1.5, "rot": 0, "face": "-x"},
				{"part": "98138p0n", "color": 70, "x": 0.4, "y": 2.5, "z": 2.5, "rot": 0, "face": "-x"},
			],
		},
		{
			"name": "wall lantern",
			"group": "lights",
			"when": "a doorway, a gate, a street wall, a tavern sign",
			"why": "A brick with a stud on one side (87087) holds a tap (4599) whose spout carries a black and a trans-neon-orange round plate: a lantern on a bracket off the wall. As the LEGO Group built it in 5766 Log Cabin: 4 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "6141", "color": 0, "x": 0.5, "y": 0, "z": 1.5, "rot": 0},
				{"part": "6141", "color": 38, "x": 0.5, "y": 1, "z": 1.5, "rot": 0},
				{"part": "4599b", "color": 0, "x": 0.5, "y": 2, "z": 1, "rot": 0},
				{"part": "87087", "color": 19, "x": 0.5, "y": 2.75, "z": 0.5, "rot": 0},
			],
		},
		{
			"name": "hanging lamp",
			"group": "lights",
			"when": "over a door, a counter or a table",
			"why": "A tap hung from a brick's side stud with an inverted dish (4740) for the shade and a trans-yellow cone for the bulb. As the LEGO Group built it in 10246 Detective’s Office: 4 parts, from LDraw's model repository (model by Willy Tschager, CC BY 2.0).",
			"bricks": [
				{"part": "87087", "color": 0, "x": 0, "y": 4.75, "z": 2.5, "rot": 2},
				{"part": "4599b", "color": 15, "x": 0.1, "y": 4, "z": 1.3, "rot": 0, "face": "-z"},
				{"part": "4740", "color": 15, "x": -0.5, "y": 3, "z": 0.5, "rot": 0},
				{"part": "59900", "color": 46, "x": 0, "y": 0, "z": 1, "rot": 0},
			],
		},
		{
			"name": "bedside lamp",
			"group": "lights",
			"when": "a bedroom, a study, a desk",
			"why": "A tap stood upright for the stand, a fez (85975) for the shade over a trans-yellow round plate, on a small cabinet of jumper plates on headlight bricks. As the LEGO Group built it in 75948 Hogwarts Clock Tower: 9 parts, from LDraw's model repository (model by Stefan Frenz, CC BY 2.0).",
			"bricks": [
				{"part": "4070", "color": 15, "x": 0, "y": 1, "z": 0.5, "rot": 0},
				{"part": "4070", "color": 15, "x": 1, "y": 1, "z": 0.5, "rot": 0},
				{"part": "15573", "color": 15, "x": 0, "y": 4, "z": 0.5, "rot": 0},
				{"part": "15573", "color": 15, "x": 0, "y": 1.5, "z": 1.3, "rot": 0, "face": "+z"},
				{"part": "15573", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "15573", "color": 15, "x": 1, "y": 0, "z": 0, "rot": 1},
				{"part": "4599b", "color": 297, "x": 0.5, "y": 5, "z": -0.5, "rot": 0},
				{"part": "6141", "color": 46, "x": 0.5, "y": 8, "z": 0.5, "rot": 0},
				{"part": "85975", "color": 297, "x": 0.5, "y": 9, "z": 0.5, "rot": 0},
			],
		},
		{
			"name": "campfire",
			"group": "lights",
			"when": "a camp, a hearth, a forge's fire, a beacon",
			"why": "Four trans-neon-orange round plates on a black 2 x 2 round plate: fire, in a grate or in the open. As the LEGO Group built it in 5766 Log Cabin: 5 parts, from LDraw's model repository (model by Marc Giraudet, CC BY 2.0).",
			"bricks": [
				{"part": "4032a", "color": 0, "x": 0, "y": 0, "z": 1, "rot": 0},
				{"part": "6141", "color": 38, "x": 0, "y": 1, "z": 2, "rot": 0},
				{"part": "6141", "color": 38, "x": 1, "y": 1, "z": 2, "rot": 0},
				{"part": "6141", "color": 38, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "6141", "color": 38, "x": 1, "y": 1, "z": 1, "rot": 0},
			],
		},
		# Angled, and as LEGO angles a wall. Real sets turn an assembly on a
		# 2x2 turntable far more than any other way — 13 assemblies turned
		# 45 degrees in six of the repository's sets, seven of them this
		# set's corner — and the checker read the top over its base as two
		# parts in one place until the parts pipeline learned shafts and
		# bores. This is the set's own sub-model, taken off its turntable
		# and put back on at its own angle by a section, so it is the
		# corner exactly as built.
		{
			"name": "corner on a turntable",
			"group": "angles",
			"when": "a corner entrance, a corner window or tower, a wall "
				+ "or anything else that stands at an angle to the street "
				+ "on a square base",
			"why": "A 2 x 2 turntable is a base (3680) and a top (3679) that "
				+ "turns on it about their shared middle. Build the base "
				+ "square, and the top and everything on it in a section "
				+ "turned about that middle, at any angle; the top's studs "
				+ "carry the rest. As the LEGO Group built it in 10182 Cafe Corner, "
				+ "the corner entrance's steps turned 45 degrees: 20 parts, "
				+ "from LDraw's model repository (model by Max Martin "
				+ "Richter, CC BY 2.0).",
			"sections": [
				{"name": "corner", "x": 1, "y": 0, "z": 1, "axis": "y", "degrees": 45},
			],
			"bricks": [
				{"part": "3680", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3679", "color": 71, "x": -1, "y": 0, "z": -1, "rot": 0, "section": "corner"},
				{"part": "3020", "color": 71, "x": -2, "y": 1, "z": -2, "rot": 0, "section": "corner"},
				{"part": "6180", "color": 71, "x": -3, "y": 1, "z": 0, "rot": 0, "section": "corner"},
				{"part": "2431", "color": 71, "x": -2, "y": 2, "z": -2, "rot": 0, "section": "corner"},
				{"part": "3023b", "color": 71, "x": 1, "y": 2, "z": -1, "rot": 3, "section": "corner"},
				{"part": "3023b", "color": 71, "x": -2, "y": 2, "z": -1, "rot": 3, "section": "corner"},
				{"part": "3021", "color": 71, "x": -1, "y": 2, "z": -1, "rot": 3, "section": "corner"},
				{"part": "2420", "color": 71, "x": 1, "y": 2, "z": 0, "rot": 1, "section": "corner"},
				{"part": "2420", "color": 71, "x": -3, "y": 2, "z": 0, "rot": 0, "section": "corner"},
				{"part": "3070b", "color": 71, "x": -3, "y": 2, "z": 3, "rot": 0, "section": "corner"},
				{"part": "3070b", "color": 71, "x": 2, "y": 2, "z": 3, "rot": 0, "section": "corner"},
				{"part": "6636", "color": 71, "x": -3, "y": 2, "z": 2, "rot": 0, "section": "corner"},
				{"part": "3070b", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0, "section": "corner"},
				{"part": "3069b", "color": 71, "x": 2, "y": 3, "z": 1, "rot": 3, "section": "corner"},
				{"part": "3069b", "color": 71, "x": -3, "y": 3, "z": 1, "rot": 3, "section": "corner"},
				{"part": "3069b", "color": 71, "x": 0, "y": 3, "z": 1, "rot": 2, "section": "corner"},
				{"part": "2431", "color": 71, "x": -2, "y": 3, "z": -1, "rot": 0, "section": "corner"},
				{"part": "3068b", "color": 71, "x": -2, "y": 3, "z": 0, "rot": 0, "section": "corner"},
				{"part": "3024", "color": 71, "x": 1, "y": 3, "z": 0, "rot": 0, "section": "corner"},
			],
		},
		{
			"name": "leaning on a hinge",
			"group": "angles",
			"when": "a spire's tip, a horn, a flagpole, a jib or anything "
				+ "else that leans out of the upright",
			"why": "A hinge brick (3937) is a base, and its top (3938) "
				+ "turns on it about a pin along its length. Build the base "
				+ "square, and the top and everything on it in a section "
				+ "whose origin is that pin: at the base's own x, 1.75 "
				+ "plates above its bottom, half a stud in. Inside the "
				+ "section the top sits at y=-0.75, and what it carries "
				+ "starts on its studs at y=1.25. Turn the section about x "
				+ "to lean it; to lean the other way, turn the base round "
				+ "(rot 2) and the section with it. As the LEGO Group built it in 6085 "
				+ "Black Monarch's Castle, the gatehouse flag leaning out 30 "
				+ "degrees: 6 parts, from LDraw's model repository (model by "
				+ "Stefan Frenz, CC BY 2.0).",
			"sections": [
				{"name": "flag", "x": 0, "y": 4.75, "z": 0.5, "axis": "x", "degrees": 30},
			],
			"bricks": [
				{"part": "3004", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3937", "color": 0, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3938", "color": 0, "x": 0, "y": -0.75, "z": -0.5, "rot": 0, "section": "flag"},
				{"part": "3794a", "color": 0, "x": 0, "y": 1.25, "z": -0.5, "rot": 0, "section": "flag"},
				{"part": "3957a", "color": 7, "x": 0.5, "y": 2.25, "z": -0.5, "rot": 0, "section": "flag"},
				{"part": "2335p41", "color": 1, "x": 0.7, "y": 8.75, "z": -0.2, "rot": 2, "section": "flag"},
			],
		},
		{
			"name": "hinged panels",
			"group": "round bodies",
			"when": "a dome, a sphere or any big curved shell: the surface as small "
				+ "flat panels, each tipped to the curve on a hinge, never plates "
				+ "stepped in",
			"why": "Each panel is plates 1 x 4 along it with tiles across them, built "
				+ "flat in its own section on a clip hinge (a bar on 60478's end, "
				+ "63868's clip on it); the plate over the hinge runs from the top "
				+ "half to the next base, so the panel is one piece whichever way it "
				+ "hangs. The panel above is a section within it, hinged at its "
				+ "far end and folded in by one band's angle — so a strip from the "
				+ "equator up is said once, in plates, and no angle is worked out "
				+ "for a brick. Here three bands of one strip, the first standing "
				+ "70 degrees up, each next folding 25 in, the strip faced 30 "
				+ "degrees round on the one round stud its base swivels on — "
				+ "nothing under the joint, since a clip's round reaches past the "
				+ "plates it joins. A dome is this strip repeated round its centre "
				+ "(repeat_section with around and yaw: read_guide \"round\"). "
				+ "10143, the Death Star II, builds its shell of panels so on "
				+ "click hinges, sixteen segments 22.5 degrees apart (find_techniques "
				+ "\"shell\").",
			"sections": [
				{"name": "band 1", "x": 1, "y": 6, "z": 0, "yaw": 30, "pitch": 70,
					"hinge": "clip"},
				{"name": "band 2", "within": "band 1", "x": 0, "y": -1, "z": 2,
					"pitch": -25, "hinge": "clip"},
				{"name": "band 3", "within": "band 2", "x": 0, "y": -1, "z": 2,
					"pitch": -25, "hinge": "clip"},
			],
			"bricks": [
				{"part": "3001", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3062b", "color": 72, "x": 1, "y": 3, "z": 0, "rot": 0},
				{"part": "3710", "color": 71, "x": -1, "y": 0, "z": 0, "rot": 1, "section": "band 1"},
				{"part": "3710", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 1, "section": "band 1"},
				{"part": "3710", "color": 71, "x": 1, "y": 0, "z": 0, "rot": 1, "section": "band 1"},
				{"part": "26603", "color": 71, "x": -1, "y": 1, "z": 0, "rot": 0, "section": "band 1"},
				{"part": "26603", "color": 71, "x": -1, "y": 1, "z": 2, "rot": 0, "section": "band 1"},
				{"part": "3710", "color": 71, "x": -1, "y": 0, "z": 0, "rot": 1, "section": "band 2"},
				{"part": "3710", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 1, "section": "band 2"},
				{"part": "3710", "color": 71, "x": 1, "y": 0, "z": 0, "rot": 1, "section": "band 2"},
				{"part": "26603", "color": 71, "x": -1, "y": 1, "z": 0, "rot": 0, "section": "band 2"},
				{"part": "26603", "color": 71, "x": -1, "y": 1, "z": 2, "rot": 0, "section": "band 2"},
				{"part": "3710", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 1, "section": "band 3"},
				{"part": "3069b", "color": 71, "x": 0, "y": 1, "z": 0, "rot": 1, "section": "band 3"},
				{"part": "3069b", "color": 71, "x": 0, "y": 1, "z": 2, "rot": 1, "section": "band 3"},
			],
		},
		{
			"name": "sideways skins",
			"group": "round bodies",
			"when": "a round band, a body lying on its side, an egg, a curved flank: "
				+ "round in the plane of a wall, where stacking would step it",
			"why": "A core with studs out on its sides carries a skin on each, "
				+ "built flat in a section — a plate the side's width, curved "
				+ "slopes falling away to its two ends — and stood up facing out: "
				+ "pitch -90, and yaw 0, 90, 180 or 270 to face the side it is on. "
				+ "Each skin's first row of tubes takes the side studs (11211 here, "
				+ "1.75 plates up its course), so it is held as a stud holds, and "
				+ "four of them read as one round band. The BB-8 sets build their "
				+ "spheres so, on cores of bricks and brackets with studs out.",
			"sections": [
				{"name": "skin front", "x": 0, "y": 7, "z": 4, "yaw": 0, "pitch": -90},
				{"name": "skin right", "x": 4, "y": 7, "z": 4, "yaw": 90, "pitch": -90},
				{"name": "skin back", "x": 4, "y": 7, "z": 0, "yaw": 180, "pitch": -90},
				{"name": "skin left", "x": 0, "y": 7, "z": 0, "yaw": -90, "pitch": -90},
			],
			"bricks": [
				{"part": "3031", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3003", "color": 0, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3003", "color": 0, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "3003", "color": 0, "x": 0, "y": 1, "z": 2, "rot": 0},
				{"part": "3003", "color": 0, "x": 2, "y": 1, "z": 2, "rot": 0},
				{"part": "3005", "color": 0, "x": 0, "y": 4, "z": 0, "rot": 0},
				{"part": "3005", "color": 0, "x": 3, "y": 4, "z": 0, "rot": 0},
				{"part": "3005", "color": 0, "x": 0, "y": 4, "z": 3, "rot": 0},
				{"part": "3005", "color": 0, "x": 3, "y": 4, "z": 3, "rot": 0},
				{"part": "3003", "color": 0, "x": 1, "y": 4, "z": 1, "rot": 0},
				{"part": "11211", "color": 0, "x": 1, "y": 4, "z": 3, "rot": 0},
				{"part": "11211", "color": 0, "x": 3, "y": 4, "z": 1, "rot": 1},
				{"part": "11211", "color": 0, "x": 1, "y": 4, "z": 0, "rot": 2},
				{"part": "11211", "color": 0, "x": 0, "y": 4, "z": 1, "rot": 3},
				{"part": "3031", "color": 0, "x": 0, "y": 7, "z": 0, "rot": 0},
				{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "section": "skin front"},
				{"part": "15068", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 3, "section": "skin front"},
				{"part": "15068", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1, "section": "skin front"},
				{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "section": "skin right"},
				{"part": "15068", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 3, "section": "skin right"},
				{"part": "15068", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1, "section": "skin right"},
				{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "section": "skin back"},
				{"part": "15068", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 3, "section": "skin back"},
				{"part": "15068", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1, "section": "skin back"},
				{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0, "section": "skin left"},
				{"part": "15068", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 3, "section": "skin left"},
				{"part": "15068", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1, "section": "skin left"},
			],
		},
		{
			"name": "round body",
			"group": "round bodies",
			"when": "anything round in section, four studs across — a rocket "
				+ "stage, a booster, a lighthouse's tower, a column, a funnel",
			"why": "Two cylinder halves back to back are a 4 x 4 round with "
				+ "one seam down it, five bricks tall; a 4 x 4 round brick is "
				+ "a band of another colour or the tie between two pairs of "
				+ "halves; a 4 x 4 cone and a 2 x 2 cone narrow it to a point. "
				+ "The rockets of LEGO® City sets are built this way (60228, 60351: "
				+ "cylinder halves, round plates, cones). Never square bricks "
				+ "stacked into a round. The round pattern lays it, any "
				+ "length, diameter 1 to 8, in one call: {\"pattern\": "
				+ "\"round\", \"diameter\": 4, \"stack\": [{\"plates\": 15}, "
				+ "{\"plates\": 3, \"color\": 0}, {\"plates\": 6}, {\"nose\": "
				+ "\"cone\"}]}.",
			"bricks": [
				{"part": "85941", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 2},
				{"part": "85941", "color": 15, "x": 0, "y": 0, "z": 2, "rot": 0},
				{"part": "87081", "color": 0, "x": 0, "y": 15, "z": 0, "rot": 0},
				{"part": "24593", "color": 15, "x": 0, "y": 18, "z": 0, "rot": 2},
				{"part": "24593", "color": 15, "x": 0, "y": 18, "z": 2, "rot": 0},
				{"part": "3943b", "color": 15, "x": 0, "y": 24, "z": 0, "rot": 0},
				{"part": "3942c", "color": 15, "x": 1, "y": 30, "z": 1, "rot": 0},
			],
		},
		{
			"name": "round body lying down",
			"group": "round bodies",
			"when": "a boiler, a fuselage, a submarine's hull, a tanker's "
				+ "tank, a log — round, and lying along the ground",
			"why": "The same round parts on their sides, studs pointing "
				+ "along the body: each holds the next by its studs, and the "
				+ "whole lies on its curve. Laid by hand that is a face and "
				+ "a quarter turn per part and a height that is not a whole "
				+ "plate; the round pattern says it with \"axis\": \"x\" (or "
				+ "z), and every band, cone and nose goes along with it.",
			"bricks": [
				{"part": "85941", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 2, "face": "+x"},
				{"part": "85941", "color": 0, "x": 0, "y": 0, "z": 2, "rot": 0, "face": "+x"},
				{"part": "60474", "color": 70, "x": 6, "y": 0, "z": 0, "rot": 0, "face": "+x"},
				{"part": "24593", "color": 0, "x": 6.4, "y": 0, "z": 0, "rot": 2, "face": "+x"},
				{"part": "24593", "color": 0, "x": 6.4, "y": 0, "z": 2, "rot": 0, "face": "+x"},
				{"part": "3960", "color": 0, "x": 8.8, "y": 0, "z": 0, "rot": 0, "face": "+x"},
			],
		},
		{
			"name": "dome and cone cap",
			"group": "round bodies",
			"when": "the top of anything round and wider than its stem — a "
				+ "fairing, a lighthouse's lantern roof, a tank's end, a "
				+ "mushroom",
			"why": "A ring of four 3 x 3 corner rounds, each turned so its "
				+ "curve faces out, tied above and below by 6 x 6 round "
				+ "plates; a 6 x 6 dish over it as the shoulder, and a 2 x 2 "
				+ "cone on the dish's middle studs. The round pattern's "
				+ "\"nose\": \"ogive\".",
			"bricks": [
				{"part": "11213", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "5152", "color": 15, "x": 0, "y": 1, "z": 0, "rot": 2},
				{"part": "5152", "color": 15, "x": 3, "y": 1, "z": 0, "rot": 1},
				{"part": "5152", "color": 15, "x": 3, "y": 1, "z": 3, "rot": 0},
				{"part": "5152", "color": 15, "x": 0, "y": 1, "z": 3, "rot": 3},
				{"part": "11213", "color": 15, "x": 0, "y": 4, "z": 0, "rot": 0},
				{"part": "44375b", "color": 15, "x": 0, "y": 5, "z": 0, "rot": 0},
				{"part": "3942c", "color": 15, "x": 2, "y": 7, "z": 2, "rot": 0},
			],
		},
		{
			"name": "smooth dome",
			"group": "round bodies",
			# A search with one of these words in it is told of this.
			"asked_by": ["dome", "domes", "domed", "hemisphere", "hemispherical",
				"observatory", "planetarium", "greenhouse", "igloo"],
			"when": "a smooth dome 16 studs across, glass or solid — an "
				+ "observatory, a greenhouse, a habitat, a planetarium, a "
				+ "lamp room, an orrery's cover",
			"why": "Four 87375 quarter domes, radius 8, on a ring of four "
				+ "58846 tapered 10 x 10 corners whose slope carries the dome's "
				+ "curve on out. A quarter's two handles are bars: the bottom "
				+ "one in two 61252 clips standing outward on 1 x 1 plates on "
				+ "the corners' studs, under the shell, and the top one in a "
				+ "61252 on a 2 x 2 round plate inside the crown, and a 2 x 2 "
				+ "round tile on those four clips' studs closes the crown; for a "
				+ "cap that shows, a 4 x 4 dish (3960) on the same clips instead, "
				+ "at x -2, y 20.75, z -2 here. The ring is open in the middle and "
				+ "holds nothing there: a deck of plates under it needs something "
				+ "under its middle, or a second layer crossing the first. A "
				+ "quarter goes "
				+ "on by its bottom bar: axis the way the handle runs, joint 0, "
				+ "x, y, z the middle of its two clips' line.",
			"bricks": [
				{"part": "58846", "color": 71, "x": -10, "y": 0, "z": 0, "rot": 0},
				{"part": "58846", "color": 71, "x": -10, "y": 0, "z": -10, "rot": 3},
				{"part": "58846", "color": 71, "x": 0, "y": 0, "z": -10, "rot": 2},
				{"part": "58846", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "3024", "color": 71, "x": -1, "y": 3, "z": 6, "rot": 0},
				{"part": "3024", "color": 71, "x": 0, "y": 3, "z": 6, "rot": 0},
				{"part": "3024", "color": 71, "x": -1, "y": 3, "z": -7, "rot": 0},
				{"part": "3024", "color": 71, "x": 0, "y": 3, "z": -7, "rot": 0},
				{"part": "3024", "color": 71, "x": -7, "y": 3, "z": 0, "rot": 0},
				{"part": "3024", "color": 71, "x": -7, "y": 3, "z": -1, "rot": 0},
				{"part": "3024", "color": 71, "x": 6, "y": 3, "z": 0, "rot": 0},
				{"part": "3024", "color": 71, "x": 6, "y": 3, "z": -1, "rot": 0},
				{"part": "61252", "color": 71, "x": -1, "y": 3.75, "z": 6, "rot": 0},
				{"part": "61252", "color": 71, "x": 0, "y": 3.75, "z": 6, "rot": 0},
				{"part": "61252", "color": 71, "x": -1, "y": 3.75, "z": -8, "rot": 2},
				{"part": "61252", "color": 71, "x": 0, "y": 3.75, "z": -8, "rot": 2},
				{"part": "61252", "color": 71, "x": -8, "y": 3.75, "z": 0, "rot": 3},
				{"part": "61252", "color": 71, "x": -8, "y": 3.75, "z": -1, "rot": 3},
				{"part": "61252", "color": 71, "x": 6, "y": 3.75, "z": 0, "rot": 1},
				{"part": "61252", "color": 71, "x": 6, "y": 3.75, "z": -1, "rot": 1},
				{"part": "4032a", "color": 71, "x": -1, "y": 18, "z": -1, "rot": 0},
				{"part": "61252", "color": 71, "x": -1, "y": 18.75, "z": 0, "rot": 0},
				{"part": "61252", "color": 71, "x": -2, "y": 18.75, "z": -1, "rot": 3},
				{"part": "61252", "color": 71, "x": 0, "y": 18.75, "z": -2, "rot": 2},
				{"part": "61252", "color": 71, "x": 0, "y": 18.75, "z": 0, "rot": 1},
				{"part": "14769", "color": 47, "x": -1, "y": 20, "z": -1, "rot": 0},
				{"part": "87375", "color": 47, "axis": "x", "joint": 0,
					"x": 0, "y": 4.75, "z": 7.5},
				{"part": "87375", "color": 47, "axis": "z", "joint": 0,
					"x": -7.5, "y": 4.75, "z": 0},
				{"part": "87375", "color": 47, "axis": "-x", "joint": 0,
					"x": 0, "y": 4.75, "z": -7.5},
				{"part": "87375", "color": 47, "axis": "-z", "joint": 0,
					"x": 7.5, "y": 4.75, "z": 0},
			],
		},
		{
			"name": "ring of cones under a round plate",
			"group": "round bodies",
			"when": "engine nozzles, the bells under a rocket, lamps under a "
				+ "shade, a funnel's feet",
			"why": "The edge of a 4 x 4 round plate with its corners off is an "
				+ "octagon of eight studs: a 1 x 1 cone on each, hanging by "
				+ "its stud, and a 2 x 2 truncated cone in the middle on the "
				+ "plate's centre tube. Cones stand wide end down, the shape "
				+ "of a bell. The round pattern's {\"cones\": 9}.",
			"bricks": [
				{"part": "59900", "color": 72, "x": 1, "y": 0, "z": 0, "rot": 0},
				{"part": "59900", "color": 72, "x": 2, "y": 0, "z": 0, "rot": 0},
				{"part": "59900", "color": 72, "x": 3, "y": 0, "z": 1, "rot": 0},
				{"part": "59900", "color": 72, "x": 3, "y": 0, "z": 2, "rot": 0},
				{"part": "59900", "color": 72, "x": 2, "y": 0, "z": 3, "rot": 0},
				{"part": "59900", "color": 72, "x": 1, "y": 0, "z": 3, "rot": 0},
				{"part": "59900", "color": 72, "x": 0, "y": 0, "z": 2, "rot": 0},
				{"part": "59900", "color": 72, "x": 0, "y": 0, "z": 1, "rot": 0},
				{"part": "98100", "color": 72, "x": 1, "y": 0, "z": 1, "rot": 0},
				{"part": "60474", "color": 0, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "87081", "color": 15, "x": 0, "y": 4, "z": 0, "rot": 0},
			],
		},
		{
			"name": "spokes with tiles",
			"group": "round bodies",
			"when": "grid fins, a gallery's brackets, a ship's yard stubs, "
				+ "rungs up a silo — something reaching a stud out of a round",
			"why": "One plate of the body laid as a bar right across and an "
				+ "arm each way, reaching a stud past the round on each side, "
				+ "with a tile on each reach (a grille tile reads as a grid "
				+ "fin). The round above stands on the plates as it would on "
				+ "a round plate. The round pattern's \"spokes\": 4 (or 2), "
				+ "with \"tile\" for another part.",
			"bricks": [
				{"part": "87081", "color": 0, "x": 1, "y": 0, "z": 1, "rot": 0},
				{"part": "3795", "color": 0, "x": 0, "y": 3, "z": 2, "rot": 0},
				{"part": "2412b", "color": 72, "x": 0, "y": 4, "z": 2, "rot": 1},
				{"part": "2412b", "color": 72, "x": 5, "y": 4, "z": 2, "rot": 1},
				{"part": "3022", "color": 0, "x": 2, "y": 3, "z": 0, "rot": 0},
				{"part": "2412b", "color": 72, "x": 2, "y": 4, "z": 0, "rot": 0},
				{"part": "3022", "color": 0, "x": 2, "y": 3, "z": 4, "rot": 0},
				{"part": "2412b", "color": 72, "x": 2, "y": 4, "z": 5, "rot": 0},
				{"part": "87081", "color": 0, "x": 1, "y": 4, "z": 1, "rot": 0},
			],
		},
		{
			"name": "curved skin panel",
			"group": "round bodies",
			"when": "the skin of a round body too wide for round bricks — a "
				+ "Saturn V stage, a big fuselage, a tank — hung on studs "
				+ "turned out",
			"why": "Plates, and curved bricks in pairs back to back across "
				+ "them, so the panel's face is an arch; built flat like this "
				+ "and hung on a core with studs on its sides (\"studs-out "
				+ "core\"), four of them make a round. As the LEGO Group built it in "
				+ "21309 NASA Apollo Saturn V, the second stage's skin: 16 "
				+ "parts, from LDraw's model repository (model by Jaco van der "
				+ "Molen, CC BY 2.0).",
			"bricks": [
				{"part": "3030", "color": 72, "x": 3, "y": 0, "z": 1, "rot": 0},
				{"part": "3034", "color": 19, "x": 4, "y": 1, "z": 2, "rot": 0},
				{"part": "3020", "color": 1, "x": 0, "y": 1, "z": 2, "rot": 0},
				{"part": "3710", "color": 19, "x": 2, "y": 0, "z": 1, "rot": 3},
				{"part": "50950", "color": 15, "x": 11, "y": 1, "z": 3, "rot": 0},
				{"part": "50950", "color": 15, "x": 11, "y": 1, "z": 0, "rot": 2},
				{"part": "24309", "color": 15, "x": 9, "y": 1, "z": 3, "rot": 0},
				{"part": "24309", "color": 15, "x": 7, "y": 1, "z": 3, "rot": 0},
				{"part": "24309", "color": 15, "x": 5, "y": 1, "z": 3, "rot": 0},
				{"part": "24309", "color": 15, "x": 3, "y": 1, "z": 3, "rot": 0},
				{"part": "24309", "color": 15, "x": 9, "y": 1, "z": 0, "rot": 2},
				{"part": "24309", "color": 15, "x": 7, "y": 1, "z": 0, "rot": 2},
				{"part": "24309", "color": 15, "x": 5, "y": 1, "z": 0, "rot": 2},
				{"part": "24309", "color": 15, "x": 3, "y": 1, "z": 0, "rot": 2},
				{"part": "24309", "color": 15, "x": 1, "y": 1, "z": 0, "rot": 2},
				{"part": "24309", "color": 15, "x": 1, "y": 1, "z": 3, "rot": 0},
			],
		},
		{
			"name": "studs-out core",
			"group": "round bodies",
			"when": "the core a skin hangs on: a round body too wide for round "
				+ "bricks, a column clad on four sides, a hull with smooth "
				+ "flanks",
			"why": "Brackets turned four ways round a 2 x 2 core, and on each "
				+ "side jumper plates and clip plates, so every side offers "
				+ "studs for a panel to hang on — the four faces of a round "
				+ "built flat and carried. As the LEGO Group built it in 21309 NASA "
				+ "Apollo Saturn V: 26 parts, from LDraw's model repository "
				+ "(model by Jaco van der Molen, CC BY 2.0).",
			"bricks": [
				{"part": "99207", "color": 4, "x": 2, "y": 0, "z": 3, "rot": 0},
				{"part": "99207", "color": 4, "x": 2, "y": 0, "z": 2, "rot": 2},
				{"part": "3003", "color": 19, "x": 2, "y": 1, "z": 2, "rot": 0},
				{"part": "44728", "color": 72, "x": 3, "y": 0, "z": 2, "rot": 1},
				{"part": "44728", "color": 72, "x": 2, "y": 0, "z": 2, "rot": 3},
				{"part": "15573", "color": 71, "x": 4.2, "y": 0, "z": 2, "rot": 3, "face": "+x"},
				{"part": "15573", "color": 71, "x": 4.2, "y": 2.5, "z": 2, "rot": 3, "face": "+x"},
				{"part": "15573", "color": 71, "x": 2, "y": 2.5, "z": 1.4, "rot": 0, "face": "-z"},
				{"part": "15573", "color": 71, "x": 2, "y": 0, "z": 1.4, "rot": 0, "face": "-z"},
				{"part": "15573", "color": 71, "x": 1.4, "y": 2.5, "z": 2, "rot": 1, "face": "-x"},
				{"part": "15573", "color": 71, "x": 1.4, "y": 0, "z": 2, "rot": 1, "face": "-x"},
				{"part": "15573", "color": 71, "x": 2, "y": 2.5, "z": 4.2, "rot": 2, "face": "+z"},
				{"part": "15573", "color": 71, "x": 2, "y": 0, "z": 4.2, "rot": 2, "face": "+z"},
				{"part": "92280", "color": 14, "x": 1.5, "y": 0, "z": 4.6, "rot": 2, "face": "+z"},
				{"part": "92280", "color": 14, "x": 2.5, "y": 2.5, "z": 4.6, "rot": 0, "face": "+z"},
				{"part": "92280", "color": 14, "x": 4.6, "y": 2.5, "z": 1.5, "rot": 1, "face": "+x"},
				{"part": "92280", "color": 14, "x": 4.6, "y": 0, "z": 2.5, "rot": 3, "face": "+x"},
				{"part": "92280", "color": 14, "x": 1.5, "y": 2.5, "z": 0.5, "rot": 2, "face": "-z"},
				{"part": "92280", "color": 14, "x": 2.5, "y": 0, "z": 0.5, "rot": 0, "face": "-z"},
				{"part": "92280", "color": 14, "x": 0.5, "y": 2.5, "z": 2.5, "rot": 3, "face": "-x"},
				{"part": "92280", "color": 14, "x": 0.5, "y": 0, "z": 1.5, "rot": 1, "face": "-x"},
				{"part": "15573", "color": 71, "x": 2.5, "y": 0, "z": 0.6, "rot": 1, "face": "-z"},
				{"part": "15573", "color": 71, "x": 2.5, "y": 0, "z": 5, "rot": 3, "face": "+z"},
				{"part": "15573", "color": 71, "x": 0.6, "y": 0, "z": 2.5, "rot": 2, "face": "-x"},
				{"part": "15573", "color": 71, "x": 5, "y": 0, "z": 2.5, "rot": 0, "face": "+x"},
				{"part": "3003", "color": 19, "x": 2, "y": 5, "z": 2, "rot": 3},
			],
		},
		{
			"name": "grille band",
			"group": "round bodies",
			"when": "corrugation, vents, ribbing, a band of machinery round a "
				+ "body or along a hull",
			"why": "Grille tiles side by side on a plate read as ribbed metal, "
				+ "a plain tile beside them as the smooth skin it breaks. As "
				+ "the LEGO Group built it in 21309 NASA Apollo Saturn V, the first "
				+ "stage's corrugated band: 10 parts, from LDraw's model "
				+ "repository (model by Jaco van der Molen, CC BY 2.0).",
			"bricks": [
				{"part": "3832", "color": 71, "x": 2, "y": 0, "z": 0, "rot": 0},
				{"part": "2412b", "color": 15, "x": 4, "y": 1, "z": 0, "rot": 0},
				{"part": "2412b", "color": 15, "x": 6, "y": 1, "z": 0, "rot": 0},
				{"part": "2412b", "color": 15, "x": 8, "y": 1, "z": 0, "rot": 0},
				{"part": "2412b", "color": 15, "x": 8, "y": 1, "z": 1, "rot": 0},
				{"part": "2412b", "color": 15, "x": 6, "y": 1, "z": 1, "rot": 0},
				{"part": "2412b", "color": 15, "x": 4, "y": 1, "z": 1, "rot": 0},
				{"part": "2431", "color": 15, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "2431", "color": 0, "x": 0, "y": 1, "z": 1, "rot": 0},
				{"part": "87079", "color": 15, "x": 10, "y": 1, "z": 0, "rot": 0},
			],
		},
		{
			"name": "cone bell on round plates",
			"group": "round bodies",
			"when": "a big engine bell, a nozzle, a horn of a gramophone, a "
				+ "bell — a cone hung under round plates",
			"why": "A 3 x 3 cone, wide end down, under two 2 x 2 round plates "
				+ "that take it to the body above. As the LEGO Group built it in 21309 "
				+ "NASA Apollo Saturn V, an F-1 engine: 3 parts, from LDraw's "
				+ "model repository (model by Jaco van der Molen, CC BY 2.0).",
			"bricks": [
				{"part": "6233", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "4032b", "color": 71, "x": 0.5, "y": 6, "z": 0.5, "rot": 0},
				{"part": "4032b", "color": 71, "x": 0.5, "y": 7, "z": 0.5, "rot": 0},
			],
		},
		{
			"name": "round tip",
			"group": "round bodies",
			"when": "the point of a nose, a mast top, an aerial's foot, a "
				+ "finial",
			"why": "A 1 x 1 round brick, a round plate and a cone: a tip that "
				+ "narrows in three steps. As the LEGO Group built it in 21309 NASA "
				+ "Apollo Saturn V: 3 parts, from LDraw's model repository "
				+ "(model by Jaco van der Molen, CC BY 2.0).",
			"bricks": [
				{"part": "3062b", "color": 15, "x": 0.5, "y": 0, "z": 0.5, "rot": 0},
				{"part": "6141", "color": 15, "x": 0.5, "y": 3, "z": 0.5, "rot": 0},
				{"part": "59900", "color": 15, "x": 0.5, "y": 4, "z": 0.5, "rot": 0},
			],
		},
		{
			"name": "struts pinned to a Technic course",
			"group": "machines and joints",
			"when": "legs folded against a body, stays, a frame's uprights, a "
				+ "ladder's rails — beams that join with pins, not studs",
			"why": "A course with a Technic brick at the middle of each side, "
				+ "its hole running out through that side; a friction pin in "
				+ "each hole, and a Technic beam on the pin's other half "
				+ "standing up the body. The pin is the joint: a beam turned "
				+ "on it in a section is a leg deployed. The round pattern's "
				+ "{\"technic\": true, \"struts\": 4}.",
			"bricks": [
				{"part": "3700", "color": 0, "x": 4, "y": 0, "z": 2, "rot": 1},
				{"part": "3700", "color": 0, "x": 1, "y": 0, "z": 2, "rot": 1},
				{"part": "3700", "color": 0, "x": 2, "y": 0, "z": 4, "rot": 0},
				{"part": "3700", "color": 0, "x": 2, "y": 0, "z": 1, "rot": 0},
				{"part": "3003", "color": 0, "x": 2, "y": 0, "z": 2, "rot": 0},
				{"part": "2780", "color": 0, "x": 2.6, "y": 0.75, "z": 4, "rot": 1},
				{"part": "32524", "color": 0, "x": 2.5, "y": 0.75, "z": 5, "rot": 2, "face": "+z"},
				{"part": "2780", "color": 0, "x": 2.6, "y": 0.75, "z": 0, "rot": 1},
				{"part": "32524", "color": 0, "x": 2.5, "y": 0.75, "z": 0, "rot": 2, "face": "+z"},
				{"part": "2780", "color": 0, "x": 4, "y": 0.75, "z": 2.6, "rot": 0},
				{"part": "32524", "color": 0, "x": 5, "y": 0.75, "z": 2.5, "rot": 3, "face": "+x"},
				{"part": "2780", "color": 0, "x": 0, "y": 0.75, "z": 2.6, "rot": 0},
				{"part": "32524", "color": 0, "x": 0, "y": 0.75, "z": 2.5, "rot": 3, "face": "+x"},
				{"part": "24593", "color": 15, "x": 1, "y": 3, "z": 1, "rot": 2},
				{"part": "24593", "color": 15, "x": 1, "y": 3, "z": 3, "rot": 0},
			],
		},
		{
			"name": "two rounds pinned side by side",
			"group": "machines and joints",
			"when": "boosters on a core, twin funnels, a pair of tanks, silos "
				+ "in a row — round things that stand together as one",
			"why": "Each with a Technic course at the same height, touching; "
				+ "one friction pin across the joint, half in each brick's "
				+ "hole, holds them — how Artemis's boosters go on its core "
				+ "(10341 carries 114 friction pins and 108 pin connectors). "
				+ "The round pattern's \"beside\": {\"count\": 2}.",
			"bricks": [
				{"part": "3700", "color": 0, "x": 7, "y": 0, "z": 1, "rot": 1},
				{"part": "3700", "color": 0, "x": 4, "y": 0, "z": 1, "rot": 1},
				{"part": "3700", "color": 0, "x": 5, "y": 0, "z": 3, "rot": 0},
				{"part": "3700", "color": 0, "x": 5, "y": 0, "z": 0, "rot": 0},
				{"part": "3003", "color": 0, "x": 5, "y": 0, "z": 1, "rot": 0},
				{"part": "87081", "color": 15, "x": 4, "y": 3, "z": 0, "rot": 0},
				{"part": "3960", "color": 15, "x": 4, "y": 6, "z": 0, "rot": 0},
				{"part": "3700", "color": 0, "x": 3, "y": 0, "z": 1, "rot": 1},
				{"part": "3700", "color": 0, "x": 0, "y": 0, "z": 1, "rot": 1},
				{"part": "3700", "color": 0, "x": 1, "y": 0, "z": 3, "rot": 0},
				{"part": "3700", "color": 0, "x": 1, "y": 0, "z": 0, "rot": 0},
				{"part": "3003", "color": 0, "x": 1, "y": 0, "z": 1, "rot": 0},
				{"part": "24593", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 2},
				{"part": "24593", "color": 15, "x": 0, "y": 3, "z": 2, "rot": 0},
				{"part": "3943b", "color": 15, "x": 0, "y": 9, "z": 0, "rot": 0},
				{"part": "3942c", "color": 15, "x": 1, "y": 15, "z": 1, "rot": 0},
				{"part": "2780", "color": 0, "x": 3, "y": 0.75, "z": 1.6, "rot": 0},
			],
		},
		{
			"name": "fin root on a Technic pin",
			"group": "machines and joints",
			"when": "a fin, a winglet, a stabiliser, anything that sticks out "
				+ "and has to stay put",
			"why": "Two Technic bricks face to face with a friction pin "
				+ "through both, so the root cannot slide off; a slope over "
				+ "them shapes the fin's leading edge and palisade bricks "
				+ "finish its ends. As the LEGO Group built it in 21309 NASA Apollo "
				+ "Saturn V, a first-stage fin's root: 6 parts, from LDraw's "
				+ "model repository (model by Jaco van der Molen, CC BY 2.0).",
			"bricks": [
				{"part": "3700", "color": 71, "x": 1, "y": 0, "z": 0, "rot": 0},
				{"part": "2780", "color": 0, "x": 1.6, "y": 0.75, "z": 0, "rot": 3},
				{"part": "3700", "color": 71, "x": 1, "y": 0, "z": 1, "rot": 0},
				{"part": "3037", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "30136", "color": 71, "x": 3, "y": 0, "z": 0, "rot": 3},
				{"part": "30136", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 3},
			],
		},
		{
			"name": "eye with a highlight",
			"group": "faces and features",
			"when": "an eye that looks back at you — an owl's, a cat's, a "
				+ "dragon's, a figure's, a robot's lens; two of them make a face",
			"why": "A 2 x 2 round plate with one centre stud (18674) in the "
				+ "iris's colour, on a bracket so it faces out, and on that stud "
				+ "a 1 x 1 round tile printed with a black eye and its white "
				+ "highlight (98138p07, the tile white). The glint is what makes "
				+ "it look alive: a plain black dot reads as a hole, and a square "
				+ "1 x 1 tile as a pixel. Two a stud apart, a plate proud of the "
				+ "face, are what a set's animal is known by. Smaller, the printed "
				+ "tile alone in a headlight brick's recess (4070, as \"porthole "
				+ "or lamp\"); a 2 x 2 round tile printed with an eye (14769px3) "
				+ "is the same in one part.",
			"bricks": [
				{"part": "3004", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "99207", "color": 71, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "18674", "color": 14, "x": 0, "y": 3, "z": 1.2, "rot": 0,
					"face": "+z"},
				{"part": "98138p07", "color": 15, "x": 0.5, "y": 4.25, "z": 1.6,
					"rot": 0, "face": "+z"},
			],
		},
		{
			"name": "round face",
			"group": "faces and features",
			"when": "the face of anything that looks at you — an owl's facial "
				+ "disc, a cat's or a bear's face, a robot's head, a clock — on a "
				+ "head built round",
			"why": "A face is features on a round, not a panel of square tiles: "
				+ "a 4 x 4 round plate (60474) on a bracket as the disc, an eye "
				+ "with its highlight on each side of its upper studs, and a beak "
				+ "on a jumper between them and under. Each feature is a part, so "
				+ "the face reads from across a room, and the disc's edge is what "
				+ "makes the head read round. A 6 x 6 round plate (11213) takes "
				+ "the eyes a stud further apart; a darker rim round the disc, as "
				+ "a barn owl's is, is quarter round tiles (25269) or curved "
				+ "slopes laid round it. On a head said as a shape, say the face "
				+ "on the shape — \"face\": {\"facing\": \"+z\", \"x\", \"y\", \"z\": "
				+ "its middle, \"across\": 6} — and it is laid there on side-stud "
				+ "bricks behind the curve, the disc flush with it: a shell of "
				+ "tiles has no studs out for a disc to grip.",
			"bricks": [
				{"part": "3004", "color": 19, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "99207", "color": 19, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "60474", "color": 15, "x": -1, "y": 0.5, "z": 1.2, "rot": 0,
					"face": "+z"},
				{"part": "18674", "color": 25, "x": -1, "y": 5.5, "z": 1.6, "rot": 0,
					"face": "+z"},
				{"part": "18674", "color": 25, "x": 1, "y": 5.5, "z": 1.6, "rot": 0,
					"face": "+z"},
				{"part": "98138p07", "color": 15, "x": -0.5, "y": 6.75, "z": 2, "rot": 0,
					"face": "+z"},
				{"part": "98138p07", "color": 15, "x": 1.5, "y": 6.75, "z": 2, "rot": 0,
					"face": "+z"},
				{"part": "3794b", "color": 15, "x": 0, "y": 3, "z": 1.6, "rot": 0,
					"face": "+z"},
				{"part": "54200", "color": 19, "x": 0.5, "y": 3, "z": 2, "rot": 0,
					"face": "+z"},
			],
		},
		{
			"name": "beak or snout",
			"group": "faces and features",
			"when": "a bird's beak, a dog's or a bear's nose, a dragon's snout, "
				+ "anything pointed out of the middle of a face",
			"why": "A cheese slope (54200) on a jumper plate (3794b), so it sits "
				+ "on the face's middle, half a stud over: its thick end under the "
				+ "eyes and its slope falling away down the face, the shape of a "
				+ "beak seen from the side. Two side by side are a wider bill; a "
				+ "tooth plate (49668) under it hooks it, as a raptor's is; for a "
				+ "muzzle, a 2 x 2 curved slope (15068) on the bracket instead.",
			"bricks": [
				{"part": "3004", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "99207", "color": 15, "x": 0, "y": 3, "z": 0, "rot": 0},
				{"part": "3794b", "color": 15, "x": 0, "y": 3, "z": 1.2, "rot": 0,
					"face": "+z"},
				{"part": "54200", "color": 14, "x": 0.5, "y": 3, "z": 1.6, "rot": 0,
					"face": "+z"},
			],
		},
		{
			"name": "ears or tufts",
			"group": "faces and features",
			"when": "an owl's ear tufts, a cat's, a fox's or a bear's ears, a "
				+ "dragon's horns — the two points on a head that make its outline",
			"why": "A slope at each top corner of the head, falling outward, the "
				+ "middle of the head left between them: 45 degree slopes (3040b) "
				+ "stand as pointed ears, 1 x 1 cheese slopes as small tufts, "
				+ "curved slopes (11477) as rounded ones. A mirrored pair turned to "
				+ "fall away from each other; without them a head is a box from "
				+ "the front.",
			"bricks": [
				{"part": "3795", "color": 19, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3040b", "color": 19, "x": 0, "y": 1, "z": 0, "rot": 3},
				{"part": "3040b", "color": 19, "x": 4, "y": 1, "z": 0, "rot": 1},
			],
		},
		{
			"name": "talons",
			"group": "faces and features",
			"when": "a bird's feet, a dragon's or a beast's claws, a raptor's grip "
				+ "on a branch or a post",
			"why": "Three tooth plates side by side (49668, the tooth in line), "
				+ "their teeth pointing forward off a 1 x 3 plate: three toes, each "
				+ "ending in a claw, with a 1 x 1 round brick (3062b) standing on "
				+ "the middle one as the leg. Black claws on a yellow foot for an "
				+ "eagle; for an owl, dark grey, the leg a round brick in its "
				+ "breast's colour. A bare white cylinder on a plate reads as a "
				+ "peg, not a leg.",
			"bricks": [
				{"part": "3623", "color": 14, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "49668", "color": 0, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "49668", "color": 0, "x": 1, "y": 1, "z": 0, "rot": 0},
				{"part": "49668", "color": 0, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "3062b", "color": 15, "x": 1, "y": 2, "z": 0, "rot": 0},
			],
		},
		{
			"name": "headlamps and grille",
			"group": "faces and features",
			"when": "a vehicle's face — a car's, a truck's, a train's or a "
				+ "robot's front: the two lights and the grille it is known by",
			"why": "Headlight bricks (4070) at the two ends with a trans-clear "
				+ "round plate (6141) in each recess, so the lamp sits into the "
				+ "face, and between them a brick with studs on its side (11211) "
				+ "carrying a grille tile (2412b) flush with them; a plate over the "
				+ "top ties them. A car's front as Speed Champions builds one: "
				+ "lamps, a grille and the body's colour round them, never a flat "
				+ "face of plain bricks.",
			"bricks": [
				{"part": "3710", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "4070", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "4070", "color": 4, "x": 3, "y": 1, "z": 0, "rot": 0},
				{"part": "11211", "color": 4, "x": 1, "y": 1, "z": 0, "rot": 0},
				{"part": "6141", "color": 47, "x": 0, "y": 1.5, "z": 0.8, "rot": 0,
					"face": "+z"},
				{"part": "6141", "color": 47, "x": 3, "y": 1.5, "z": 0.8, "rot": 0,
					"face": "+z"},
				{"part": "2412b", "color": 0, "x": 1, "y": 1.5, "z": 1, "rot": 0,
					"face": "+z"},
				{"part": "3710", "color": 4, "x": 0, "y": 4, "z": 0, "rot": 0},
			],
		},
		{
			"name": "raked screen and falling roof",
			"group": "windows and doors",
			"when": "a cabin's or a canopy's front and roof — a car's, a truck's or a "
				+ "train's cab, a cockpit — built by hand; on a shape, say \"screen\" on "
				+ "the cabin's solid instead and the same is laid for you",
			"why": "A windscreen (92583, 3 x 6 x 2) stands on the plates at the foot of "
				+ "its rake and leans back to its top row, two studs at its corners; the "
				+ "cabin's back pillars rise beside the seats to the same height, and the "
				+ "roof plate lies on the windscreen's top studs and the pillars, so the "
				+ "glass holds the roof's front as a set's does. The roof falls behind it to "
				+ "the tail in curved slopes, a fastback, never a flat lid on a box; tiles "
				+ "over the rest. Here the front is towards +z: turn it with rot.",
			"bricks": [
				{"part": "3036", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 1},
				{"part": "92583", "color": 40, "x": 0, "y": 1, "z": 4, "rot": 0},
				{"part": "3622", "color": 4, "x": 0, "y": 1, "z": 1, "rot": 1},
				{"part": "3622", "color": 4, "x": 5, "y": 1, "z": 1, "rot": 1},
				{"part": "3622", "color": 4, "x": 0, "y": 4, "z": 1, "rot": 1},
				{"part": "3622", "color": 4, "x": 5, "y": 4, "z": 1, "rot": 1},
				{"part": "3032", "color": 4, "x": 0, "y": 7, "z": 1, "rot": 0},
				{"part": "15068", "color": 4, "x": 0, "y": 8, "z": 1, "rot": 2},
				{"part": "15068", "color": 4, "x": 2, "y": 8, "z": 1, "rot": 2},
				{"part": "15068", "color": 4, "x": 4, "y": 8, "z": 1, "rot": 2},
				{"part": "3069b", "color": 4, "x": 0, "y": 8, "z": 3, "rot": 1},
				{"part": "87079", "color": 4, "x": 1, "y": 8, "z": 3, "rot": 0},
				{"part": "3069b", "color": 4, "x": 5, "y": 8, "z": 3, "rot": 1},
			],
		},
		{
			"name": "towball hitch",
			"group": "machines and joints",
			"when": "a trailer, a caravan, a wagon or a tender pulled behind something "
				+ "on wheels of its own: coupled, so the two are one model",
			"why": "A plate with a towball on its side (14417) on the back of what "
				+ "pulls, its ball standing out past the end, and on the front of what "
				+ "follows the plate with the socket (14704) turned to face it, over the "
				+ "ball, both on their vehicle's top at the same height: the ball in the "
				+ "socket holds the two together and lets the trailer swing. The socket's "
				+ "studs stand two studs on from the ball's, so both stay on one grid with "
				+ "a stud between the two. x, y and z are each part's corner as the app "
				+ "reads it, the ball and the socket hanging below and beyond their "
				+ "plates: a plate standing at y is said at y - 0.5.",
			"bricks": [
				{"part": "3020", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "14417", "color": 0, "x": 1, "y": 0.5, "z": 1, "rot": 0},
				{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 3, "rot": 0},
				{"part": "14704", "color": 0, "x": 1, "y": 0.5, "z": 2, "rot": 2},
			],
		},
		{
			"name": "magnet coupling",
			"group": "machines and joints",
			"when": "a train's cars, a locomotive and its tender, carriages and wagons: "
				+ "coupled end to end as the LEGO® train sets couple theirs",
			"why": "A buffer beam with a sealed magnet (64422) on the end of each car, "
				+ "its tongue on a 2 x 2 plate over the car's last two rows and the beam "
				+ "with its buffers hanging past the end, the two magnets touching between "
				+ "the cars, seven studs between the plates' middles: the Emerald Night "
				+ "(10194) couples its tender so. The beam hangs five and a half plates "
				+ "under its tongue, so the car stands that high (here on bricks). x, y "
				+ "and z are each beam's corner as the app reads it: its tongue's middle "
				+ "is 3.5 studs along x and 1.5 studs along its length (3.5 for the beam "
				+ "turned back) from it, and its tongue's foot is at y + 5.5.",
			"bricks": [
				{"part": "3001", "color": 0, "x": 2, "y": 0, "z": 0, "rot": 1},
				{"part": "3001", "color": 0, "x": 2, "y": 3, "z": 0, "rot": 1},
				{"part": "3958", "color": 2, "x": 0, "y": 6, "z": 0, "rot": 0},
				{"part": "3022", "color": 0, "x": 2, "y": 7, "z": 4, "rot": 0},
				{"part": "64422", "color": 0, "x": -0.5, "y": 2.5, "z": 3.5, "rot": 0},
				{"part": "3001", "color": 0, "x": 2, "y": 0, "z": 13, "rot": 1},
				{"part": "3001", "color": 0, "x": 2, "y": 3, "z": 13, "rot": 1},
				{"part": "3958", "color": 2, "x": 0, "y": 6, "z": 11, "rot": 0},
				{"part": "3022", "color": 0, "x": 2, "y": 7, "z": 11, "rot": 0},
				{"part": "64422", "color": 0, "x": -0.5, "y": 2.5, "z": 8.5, "rot": 2},
			],
		},
		{
			"name": "lid or hatch raised on hinges",
			"group": "creative touches",
			"when": "a play feature shown working — a hatch, a lid, a canopy, "
				+ "a bonnet, a chest or a trapdoor standing open, so what is "
				+ "under it shows",
			"why": "Two 1 x 2 hinge bricks (3937) along the back edge, their "
				+ "tops (3938) turning on the pin, and the lid on the tops' "
				+ "studs in a section whose origin is the pin: at the base's "
				+ "x, 1.75 plates above its bottom, half a stud in, turned "
				+ "about x. Inside it the tops sit at y=-0.75 and the lid on "
				+ "them at y=1.25. A negative angle lifts the lid's free edge "
				+ "(towards +z); 0 shuts it. What opens is what people try "
				+ "first on a set, and a lid left raised says so in a picture: "
				+ "put what it hides under it — a seat, an engine, a treasure.",
			"sections": [
				{"name": "lid", "x": 0, "y": 2.75, "z": 0.5, "axis": "x", "degrees": -60},
			],
			"bricks": [
				{"part": "3020", "color": 71, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3937", "color": 71, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3937", "color": 71, "x": 2, "y": 1, "z": 0, "rot": 0},
				{"part": "3938", "color": 71, "x": 0, "y": -0.75, "z": -0.5, "rot": 0,
					"section": "lid"},
				{"part": "3938", "color": 71, "x": 2, "y": -0.75, "z": -0.5, "rot": 0,
					"section": "lid"},
				{"part": "3031", "color": 4, "x": 0, "y": 1.25, "z": -0.5, "rot": 0,
					"section": "lid"},
			],
		},
		{
			"name": "small creature",
			"group": "creative touches",
			"when": "a story in one part — a mouse at an owl's feet, a cat on a "
				+ "sill, a frog by the water, a bird on a branch, a rat in a "
				+ "cellar, a spider in a ruin",
			"why": "LEGO® creatures are single parts that stand on a stud: "
				+ "search_parts \"animal\" for the one the story needs (33320 "
				+ "frog, 35757 mouse, 41835 songbird, 13786 cat, 40234 rat, "
				+ "30238 spider). Set it where the eye finds it a moment after "
				+ "the subject — at a foot, on a sill, by the water — on a "
				+ "round plate or a jumper, so it sits half a stud off the grid "
				+ "the way a living thing does, never in a row.",
			"bricks": [
				{"part": "3022", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "3794b", "color": 2, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "33320", "color": 10, "x": 0.5, "y": 2, "z": 0, "rot": 0},
			],
		},
		{
			"name": "display stand with a nameplate",
			"group": "creative touches",
			"when": "any display model — a rocket, a ship, a vehicle, a "
				+ "figure — that should stand the way it is shown",
			"why": "A black base, a column holding the model up, and a 6 x 8 "
				+ "slope at ten degrees across the front as the plaque: the "
				+ "part the LEGO Group's own display sets carry their name on (4515p04 "
				+ "is the U.S.S. Enterprise's nameplate, 4515d03 the Hubble's). "
				+ "Search for a printed one with the subject's name; a plain "
				+ "one with a printed 2 x 6 tile on a plate in front of it "
				+ "reads the same.",
			"bricks": [
				{"part": "41539", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
				{"part": "4515", "color": 0, "x": 0, "y": 1, "z": 0, "rot": 0},
				{"part": "3941", "color": 0, "x": 3, "y": 1, "z": 6, "rot": 0},
				{"part": "3941", "color": 0, "x": 3, "y": 4, "z": 6, "rot": 0},
				{"part": "3941", "color": 0, "x": 3, "y": 7, "z": 6, "rot": 0},
				{"part": "4032a", "color": 72, "x": 3, "y": 10, "z": 6, "rot": 0},
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
	# Near enough: "diagonal" should find "smooth diagonal", and a design
	# that half-remembers a name should not be told nothing exists. In
	# whole words (SubjectWords): as letters, "ear" found the hearth before
	# the ears, and "ant" the planter.
	for one: Variant in all():
		var technique: Dictionary = one
		if SubjectWords.names(str(technique["name"]), wanted):
			return technique
	# A name inside what was asked, as whole words: "a castle bookcase"
	# is the bookcase. Not as letters, or "street lamp" finds the tree.
	for one: Variant in all():
		var technique: Dictionary = one
		var name: String = str(technique["name"]).to_lower()
		if (" %s " % wanted).contains(" %s " % name):
			return technique
	# Then the one sharing most words with it: "stone corbel" is the
	# corbel whatever else its name says.
	var best: Dictionary = {}
	var most: int = 0
	var asked: PackedStringArray = wanted.split(" ", false)
	for one: Variant in all():
		var technique: Dictionary = one
		var shared: int = 0
		for word: String in str(technique["name"]).to_lower().split(" ", false):
			if word.length() > 3 and asked.has(word):
				shared += 1
		if shared > most:
			most = shared
			best = technique
	return best


## The worked technique that builds a feature, by the words of its name
## and of what it is for: "eyes" is the eye with a highlight, "ear tufts"
## the ears or tufts, "headlamps" the headlamps and grille. Words are seen
## through their plurals; a name word counts twice what a word of its use
## does. {} when nothing shares a name word with it.
static func for_feature(feature: String) -> Dictionary:
	var asked: PackedStringArray = RealSnippets.words(feature)
	var best: Dictionary = {}
	var most: int = 0
	for one: Variant in all():
		var technique: Dictionary = one
		var named: PackedStringArray = RealSnippets.words(str(technique["name"]))
		var used: PackedStringArray = RealSnippets.words(str(technique["when"]))
		var score: int = 0
		var by_name: bool = false
		for word: String in asked:
			if named.has(word):
				score += 2
				by_name = true
			elif used.has(word):
				score += 1
		if by_name and score > most:
			most = score
			best = technique
	return best


## The names, for when nothing matched.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for one: Variant in all():
		out.append(str((one as Dictionary)["name"]))
	return out


## What each construction is for, in the order a model needs them. With
## sixty names in one line a design looking for a roof reads them all;
## grouped, it reads one group.
##
## Angles came last, and not for want of real ones: real sets turn a
## wall on a turntable (3679 over 3680 at one origin: 13 assemblies
## turned 45 degrees in six sets, seven of them 10182 Cafe Corner's
## corner entrance, corner windows and tower), on hinge bricks or hinge
## plates, and hang banners and torches on clips on bars, and the checker
## read every one of those as two parts in one place until the parts
## pipeline recorded shafts and bores (Joints.rounds). A worked example
## that only passed by being built wrong would have taught it wrong.
const GROUPS: Array[String] = ["basics", "walls and stone",
	"towers and columns", "round bodies", "faces and features",
	"machines and joints", "angles",
	"roofs and spires", "windows and doors", "rock and ground", "plants",
	"furniture and interiors", "lights", "creative touches"]


## Every name, by group: "basics: a, b; walls and stone: c, d".
static func listing() -> String:
	var out := PackedStringArray()
	for group: String in GROUPS:
		var in_it := PackedStringArray()
		for one: Variant in all():
			var technique: Dictionary = one
			if str(technique.get("group", "")) == group:
				in_it.append(str(technique["name"]))
		if not in_it.is_empty():
			out.append("%s: %s" % [group, ", ".join(in_it)])
	return "; ".join(out)
