## The rest of the app, for a session driving it from outside.
##
## The assistant's tools design a model and change it. A person in the
## window can do more with it than that: choose what it stands on, give it
## build steps of their own, lay a hose between two connectors, swing a
## hinge, undo, open another model, see what it needs from their
## collection, render it, and export it for Studio or BrickLink. A session
## over MCP is the person's designer and editor, and one that cannot do
## those cannot do what the person can.
##
## So these are those, each a thin wrapper over the code the window's own
## command runs (Shell, FlexTool, PosePanel, RenderDialog, Exports, main's
## floor and booklet) and never a second implementation of it: one undo
## step where it changes the model, and a refusal that says what to fix.
##
## Served by CommandSocket beside the assistant's own, so the desktop's MCP
## port, My Claude and the connector all have them. Not given to the
## in-app design loop, which designs what it was asked for and leaves the
## rest of the window to the person in front of it.
##
## [constant COMMANDS] says which tool does what each of the window's
## commands does, and [constant WINDOW_ONLY] why the rest are the window's
## alone. src/dev/mcp_sync_probe.gd fails when a command is in neither, so
## a command added to the menus with no way for a session to do the same
## is caught the day it is added, and not when someone asks for it.
class_name AppTools
extends RefCounted

## main.gd.
var app: Node
var assistant: Assistant
## Whether a link to this computer may be fetched (_fetch): a probe serves
## its own files from here.
var fetch_near: bool = false
## The Claude chat whose call is running, as the relay names it, or "":
## set by CommandSocket around each call (undo keeps to its own changes).
var chat: String = ""
## The gallery, read for a session (GalleryTool, 2026-10-13).
var _gallery: GalleryTool


## The window's commands (Shell) a session does with a tool: command id, or
## a prefix ending in "*", -> the tool.
const COMMANDS: Dictionary = {
	"new": "clear_model", "clear": "clear_model", "open": "open_model", "library": "open_model",
	"save": "save_model", "save_as": "save_model", "versions": "open_model",
	"export_all": "export_model",
	"export_ldraw": "export_model", "export_io": "export_model", "export_3d": "export_model",
	"export_picture": "export_model", "export_bricklink": "export_model",
	"export_rebrickable": "export_model", "instructions": "export_model",
	"render": "render_model",
	"undo": "undo", "redo": "undo",
	"cut_parts": "edit_model", "copy": "edit_model", "paste": "edit_model",
	"duplicate": "edit_model", "delete": "edit_model", "paint": "edit_model",
	"replace": "edit_model", "make_submodel": "edit_model",
	"step_*": "edit_steps", "timeline": "edit_steps", "booklet_*": "edit_booklet",
	"floor_*": "set_floor",
	"flex": "lay_flex", "reshape_flex": "lay_flex",
	"pose": "pose_model", "mode_hinge": "pose_model",
	"parts_list": "parts_list", "collection": "parts_list", "collection_need": "parts_list",
	"collection_build": "parts_list",
	"minifig": "add_minifig", "mosaic": "make_art", "part_maker": "make_part",
	"stability": "review_model", "ask_claude": "selection",
	"brickify": "brickify", "import_mesh": "brickify", "print_part": "print_part",
	"sticker": "print_part", "printed_versions": "print_part",
	"make_unique": "make_unique",
	"suggest_sections": "suggest_sections", "evaluate_section": "evaluate_section",
	"break_out": "break_out_section", "put_back": "break_out_section",
	"simulate": "simulate_mechanism",
	"hidden_colours": "colour_hidden_parts",
}

## The window's commands no tool does, each with why. A command that is
## in neither this nor COMMANDS fails the sync probe.
const WINDOW_ONLY: Dictionary = {
	"import_*": "reads a file from the person's disk, picked in a dialog; open_model opens the app's own models",
	"share": "publishes the model on the web as the person, for anyone with the link and, ticked, in the public gallery: theirs to decide",
	"account": "signing in is the person's",
	"quit": "closes the app the session is driving",
	"new_window": "opens another tab or window for the person, on a model of its own; a session works in the tab it is connected to, and clear_model begins a new model there",
	"connector": "connects Claude to this tab; a session is already connected",
	"select_*": "picks parts for the person's next command; a session names parts by number (look_at_model) and reads the person's pick with selection",
	"hide": "what the person sees; view_model where= looks at one box of the model",
	"isolate": "what the person sees; view_model where= looks at one box of the model",
	"show_all": "what the person sees; view_model where= looks at one box of the model",
	"lock": "keeps the person's own mouse off parts; a session changes only the parts it names",
	"unlock": "keeps the person's own mouse off parts; a session changes only the parts it names",
	"mirror": "a session lays the mirror image itself, with edit_model's add or the mirror shape",
	"leave_submodel": "which sub-assembly the person's mouse edits inside; a session names an assembly by its box (edit_model)",
	"enter_assembly": "which sub-assembly the person's mouse edits inside; a session names an assembly by its box (edit_model)",
	"leave_assembly": "which sub-assembly the person's mouse edits inside; a session names an assembly by its box (edit_model)",
	"rename_assembly": "a session names an assembly when it makes one (edit_model's assemblies)",
	"view_*": "the person's camera; view_model from= looks from any side",
	"mode_*": "what the person's mouse does; a session's changes are edit_model's",
	"fit": "the person's camera; view_model frames what it looks at",
	"explode": "what the person sees; a session weighs each section with evaluate_section and looks with view_model where=",
	"fit_model": "the person's camera; view_model frames what it looks at",
	"fit_selection": "the person's camera; view_model frames what it looks at",
	"ortho": "the person's camera; view_model from= looks from any side",
	"turn_left": "the person's camera; view_model from= looks from any side",
	"turn_right": "the person's camera; view_model from= looks from any side",
	"grid": "a grid drawn for the person's mouse",
	"cut": "the person's view inside; view_model where= looks at one box of the model",
	"cut_*": "the person's view inside; view_model where= looks at one box of the model",
	"xray": "the person's view inside; view_model where= looks at one box of the model",
	"panel_*": "the window's panels",
	"show_properties": "the window's panels",
	"full_screen": "the window's panels",
	"rotate_held": "the part in the person's hand; a session gives rot= and face=",
	"tip_held": "the part in the person's hand; a session gives rot= and face=",
	"measure": "a ruler for the person; a session's coordinates are already studs and plates",
	"find_colour": "a field the person types a colour's name into, for their next part; a session gives the LDraw colour code (edit_model's color and recolor)",
	"reseat": "squares up parts a file left between studs; a session's parts are on the lattice already",
	"settings": "the person's preferences, whether the assistant is in the window among them: theirs to choose, and with it off the connector is off, so no session is there to ask",
	"keys": "help for the person",
	"tour": "help for the person",
	"website": "help for the person",
	"about": "help for the person",
}

## What a session reads about these, served by read_guide("app") — every
## tool here is named in it, which the sync probe checks.
const GUIDE := """THE REST OF THE APP
Besides designing, a session can do what the person does from the menus. \
Each change is one undo step.
 - clear_model takes everything off for a new model, as New does; \
save_model writes it with the person's models; make_part makes a part \
the LEGO Group has not made, when search_parts finds no real one that will do.
 - set_floor: what the model stands on — a baseplate 8 to 192 studs in \
eights, in a colour baseplates come in, a grid floor, or nothing (a car \
or a ship stands on a table). part_of_model=true counts the baseplate as \
a part and makes it step 1 of the booklet.
 - edit_steps: the build steps the booklet and the timeline follow. With \
no op it lists them; "next"/"prev" move parts a step, "new" makes a step \
of them, "earlier"/"later"/"merge"/"delete" act on a step by its number.
 - booklet_layout reads the booklet's pages and how each step is printed, \
changing nothing; edit_booklet sets one step's view (turn=, tilt=, \
"usual"), zoom=, size=, page= ("new", "alone"), parts=, callout= and the \
booklet's per_page=, as the timeline's Booklet row does; place=, text= and \
arrow= lay a page out by hand.
 - lay_flex: a hose, a pneumatic tube, a flexible axle, a string or a \
chain, laid between two connectors (pin holes, axles, studs) of two parts \
by number, or round two sprockets; item= lays an existing one again.
 - pose_model: lists the joints (a sub-assembly on a hinge, a turntable \
or a clip) and swings one to an angle, as far as it has room. \
animate_model: poses at moments, played smoothly between and rendered as \
an animation.
 - Motions: a model keeps its own named movements in its file ("Open the \
doors", "Steer left and right"), played by its real joints as a drag moves \
them. list_motions lists them, and suggests some from what moves; \
define_motion keeps one (tracks of keys on joints named as move_part names \
them, or a driver turned so many times); play_motion plays one (reverse, \
a sequence), leaving the model where it ends; render_motion renders one as \
a WebP and an MP4, as a job.
 - move_part: moves a part on its joint as the person's drag does, \
with everything built on it, the gears it drives, and the balance after; \
with only part= it says what would move and changes nothing; with no part= \
it lists what moves in the model (steering, a boom...) and the parts to take hold of.
 - simulate_mechanism: turns a gear train from its driver (a crank, an \
axle, a sub-assembly named Crank or Motor) as Tools, Simulate does: each \
arm's turns per driver turn, its period in a reference's turns (Earth \
years) against the real one, what locks it, what floats, and the balance \
over the whole cycle, with a picture; record=true keeps a WebP and an MP4, \
as a job. Name each arm's sub-assembly after what it carries (Earth, Mars) \
and the crank Crank. What stands on studs (a turntable's base on a plate) \
is held with what it stands on; a frame held by nothing the parts record \
is held still when named Frame.
 - undo: takes the last change back, or several; redo=true puts it back.
 - open_model: lists the person's saved models and the examples, and \
opens one. It cannot be undone: save_model first. Each save is kept, the \
last 20: name= with versions=true lists a model's, version=N opens one. \
link= opens a copy of a gallery model, as Open in Brickworks does; \
library= opens LDraw's model of a real set (gallery library=true finds them).
 - parts_list: the model's parts by part and colour with element ids; \
which="need" what the person's collection is short of; "buildable" What \
can I build?: saved models, examples and real sets' models by how much is owned.
 - render_model: a picture or a turntable worth keeping, Quick, Good or \
Best, up to 4K, saved where Render saves.
 - export_model: the model as LDraw, a BrickLink Studio .io, a 3D file \
(GLB, glTF, OBJ, STL), a picture, a BrickLink wanted list, a Rebrickable \
parts list, or the building instructions as a booklet, written where \
Export writes; all_models is every saved model in one .zip.
 - brickify: a 3D model (OBJ, STL, glTF, PLY, 3MF, VOX, FBX) laid in LEGO® bricks at the size asked, \
as one sub-assembly: file= its path on this computer, url= a link the app \
fetches, or pick=true opens the window's file dialog for the person, after \
which brickify with neither lays what they chose.
 - print_part: a picture (svg= you draw, picture_data= a picture the person \
gave you, as base64, or picture_url=) printed on a part where it stands, or \
with sticker=true stuck on one of its faces; or the LEGO Group's own: \
version= one of the part's printed versions (versions= lists them), \
sticker_part= a sticker LDraw has, stuck on a face.
 - make_unique: one copy of a sub-assembly cut loose from the others, so \
changing it changes no other.
 - suggest_sections: how a builder would split the model into sections, \
as a set into numbered bags: each connected, one piece, a sensible size, \
joined to the rest by few joints, in build order, with which way it comes \
off. Read-only; it shows them in the person's model tree. make_sections \
makes them sub-assemblies (all, or sections= each a name and the \
suggestions it is made of, merging any), as one undo step.
 - break_out_section: pulls a section (a sub-assembly) away from the model \
the way it comes off, to work on, as one undo step; put_back=true puts it \
exactly where it was; all=true puts every one back. A file is always \
written with them back in place.
 - evaluate_section: a section alone, read-only: its parts list, weight, \
whether it holds together (the build check on it alone) and stands \
(Balance), what joins it to the rest and what that carries, and its own \
steps.
 - colour_hidden_parts: the parts nobody sees in the finished model, \
coloured by section, build stage or side as big sets are inside, so a \
builder finds their place; measured from every side, so nothing seen \
changes. It previews unless apply=true and agreed=true: offer it at the \
end of a big model built in sections, and apply it only once the person \
says yes.
 - gallery: what people built and shared at brickworks.diy/gallery, searched \
(q, kind, size, technic, instructions, sort); open=<id> reads one as a \
reference — its size, parts, credit, licence and picture. Read-only. Credit \
its builder and keep to its licence in anything made from it.
 - job: what takes long on a big model (render_model, animate_model's \
rendering, render_motion, export_model's studio, picture and instructions, make_art, \
brickify) \
answers at once with a job number while it works in the app. job {"id": N} \
waits up to 10 s for it to end, then says how far it has got, or gives its \
answer once done; call it about every 10 s until then. cancel=true stops \
it. Nothing else can be done in the app while a job runs."""


func definitions() -> Array:
	var none: Dictionary = {"type": "object", "properties": {}, "additionalProperties": false}
	var colours := PackedStringArray()
	for pair: Array in ModelFloor.COLOURS:
		colours.append("%d %s" % [int(pair[0]), str(pair[1])])
	var end: Dictionary = {"type": "object", "additionalProperties": false,
		"required": ["brick"],
		"properties": {
			"brick": {"type": "integer", "description": "the part's number in look_at_model"},
			"x": {"type": "number", "description": "studs: the connector nearest this, when the part has several"},
			"y": {"type": "number", "description": "plates"},
			"z": {"type": "number", "description": "studs"},
		}}
	return [
		{
			"name": "set_floor",
			"description": ("Choose what the model stands on, as View, Floor does: a baseplate "
				+ "(studs across and deep, in eights from 8 to 192, in a colour baseplates "
				+ "come in), a grid floor with no plate, or none — a vehicle stands on a "
				+ "table, a scene on a baseplate in its ground's colour. part_of_model=true "
				+ "makes the baseplate a part of the model: counted, saved, step 1 of the "
				+ "booklet. Nothing built moves. With nothing given it says what it is now."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"kind": {"type": "string", "enum": ModelFloor.KINDS},
				"across": {"type": "integer", "description": "studs along x; 16, 32 and 48 are the square ones the LEGO Group sells"},
				"deep": {"type": "integer", "description": "studs along z; the same as across when omitted"},
				"colour": {"type": "integer", "description": "LDraw code: " + ", ".join(colours)},
				"part_of_model": {"type": "boolean"},
			}},
		},
		{
			"name": "edit_steps",
			"description": ("The model's build steps, the order the booklet and the timeline "
				+ "follow, as Edit, Build steps changes them. op \"list\" (the default) gives "
				+ "them with the part numbers in each; \"next\" or \"prev\" moves bricks= a "
				+ "step later or earlier; \"new\" makes a new step of bricks=; \"earlier\", "
				+ "\"later\", \"merge\" (with the next) and \"delete\" act on step=, a number "
				+ "from the list. A model with no steps of its own is given the worked-out "
				+ "ones first, in the same undo step."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"op": {"type": "string", "enum": ["list", "next", "prev", "new", "earlier",
					"later", "merge", "delete"]},
				"bricks": {"type": "array", "items": {"type": "integer"},
					"description": "part numbers from look_at_model, for next, prev and new"},
				"step": {"type": "integer", "description": "a step's number, for earlier, later, merge and delete"},
				"from": {"type": "integer", "description": "list from this step; 1 when omitted"},
			}},
		},
		{
			"name": "booklet_layout",
			"description": ("The booklet's pages as Instructions would print them now, without "
				+ "drawing a picture: each page with the steps on it, and for each step how its "
				+ "designer set it (turned, tilted, zoomed, larger or smaller, a new page or a "
				+ "page alone, its parts list left off), which sub-assemblies are built in a "
				+ "callout box and which on pages of their own, and the most steps a page. "
				+ "Steps the booklet turns round by itself are decided when it is drawn. "
				+ "Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"from": {"type": "integer", "description": "list from this page; 2, the first page of steps, when omitted"},
			}},
		},
		{
			"name": "edit_booklet",
			"description": ("Set how the booklet prints a step, as the timeline's Booklet row "
				+ "and Build, Booklet page do; one undo step, saved with the model (a turn "
				+ "as LDraw's 0 ROTSTEP, which LPub, LDCad and Studio read). step= a number "
				+ "from booklet_layout or edit_steps. turn= degrees round from the usual "
				+ "angle and tilt= degrees higher, held for the steps after it until turned "
				+ "again, or turn=\"usual\"; zoom= 0.5 to 3 (in on what the step adds); "
				+ "size= 0.6 to 2 on the page; page= \"new\", \"alone\" or \"auto\"; "
				+ "parts= false leaves its parts list off; sign= false leaves off the turn sign "
				+ "a step turned more than 60 degrees round or 45 up or down gets; callout= false builds the "
				+ "sub-assembly the step puts on on pages of its own; per_page= 1, 2, 4 or "
				+ "0 (as they fit) for the whole booklet; highlight= false leaves the new parts "
				+ "unoutlined in the whole booklet. The page by hand, one undo step each and "
				+ "alone in a call: place= moves an item of the step's page to x, y (and w, h) "
				+ "in mm on the 269 x 199 page, as dragging it on Lay out the page does "
				+ "(item picture, parts, callout or number; note with index= for words or a "
				+ "picture added; remove=true takes a note off, back=true puts an item back "
				+ "where the booklet lays it); text= puts words on the step's page; arrow= draws "
				+ "an arrow on it, from x1, y1 to x2, y2, bent through bx, by if given, red (where "
				+ "a part goes in) or black, 0.45, 0.9 or 1.4 mm wide, or with index= changes or "
				+ "removes one. What is placed goes with its step when the pages change. "
				+ "booklet_layout says where each is, and what was moved off what it overlapped. "
				+ "A model with no steps of its own is given the "
				+ "worked-out ones first, in the same undo step."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["step"], "properties": {
				"step": {"type": "integer"},
				"highlight": {"type": "boolean"},
				"place": {"type": "object", "description": "{item, x, y, w, h, index, remove}: w and h kept when omitted",
					"properties": {
						"item": {"type": "string", "enum": ["picture", "parts", "callout", "number", "note"]},
						"x": {"type": "number"}, "y": {"type": "number"},
						"w": {"type": "number"}, "h": {"type": "number"},
						"index": {"type": "integer", "description": "which note, from 0, for item note"},
						"remove": {"type": "boolean"},
						"back": {"type": "boolean", "description": "true: where the booklet lays it out again"}}},
				"text": {"type": "object", "description": "{words, x, y, w, h, size}: mm, size the letters' height (4 when omitted)",
					"properties": {
						"words": {"type": "string"},
						"x": {"type": "number"}, "y": {"type": "number"},
						"w": {"type": "number"}, "h": {"type": "number"},
						"size": {"type": "number"}}},
				"arrow": {"type": "object", "description": "{x1, y1, x2, y2, bx, by, colour, width, index, remove}: mm; colour red or black, width 0.45, 0.9 or 1.4; index= an arrow of the step's page to change, remove=true to take it off",
					"properties": {
						"x1": {"type": "number"}, "y1": {"type": "number"},
						"x2": {"type": "number"}, "y2": {"type": "number"},
						"bx": {"type": "number"}, "by": {"type": "number"},
						"colour": {"type": "string", "enum": ["red", "black"]},
						"width": {"type": "number"},
						"index": {"type": "integer"},
						"remove": {"type": "boolean"}}},
				"turn": {"description": "degrees round (-180 to 180), or \"usual\""},
				"tilt": {"type": "number", "description": "degrees higher (-60 to 45)"},
				"zoom": {"type": "number"},
				"size": {"type": "number"},
				"page": {"type": "string", "enum": ["new", "alone", "auto"]},
				"parts": {"type": "boolean"},
				"sign": {"type": "boolean", "description": "false: no turn sign on the step"},
				"callout": {"type": "boolean"},
				"per_page": {"type": "integer", "enum": [0, 1, 2, 4]},
			}},
		},
		{
			"name": "lay_flex",
			"description": ("Lay a hose, tube, string or chain, as Build, Hose, tube or chain "
				+ "does: kind ribbed_hose, pneumatic_tube, flex_hose or flex_axle between two "
				+ "parts' pin holes, axles or pins; string between two studs; chain or tread "
				+ "round sprockets= (two or more gears in one plane). The real length that "
				+ "fits is chosen, and it bends no tighter than the real one can. It goes in "
				+ "as one sub-assembly, named in the answer; item= that name lays it again "
				+ "between new ends."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["kind"], "properties": {
				"kind": {"type": "string", "enum": FlexTool.KIND_ORDER},
				"from": end, "to": end,
				"sprockets": {"type": "array", "items": {"type": "integer"},
					"description": "part numbers of the gears a chain or tread goes round"},
				"color": {"type": "integer", "description": "LDraw colour; black when omitted"},
				"item": {"type": "string", "description": "a hose already laid, by its name in an earlier answer"},
			}},
		},
		{
			"name": "pose_model",
			"description": ("Swing a part about its joint, as Build, Pose does: a sub-assembly "
				+ "on a hinge, a turntable or a clip on a bar. With no joint it lists them, "
				+ "numbered, with the angle each is at. joint= (number or name) and degrees= "
				+ "(from where it was built, -180 to 180) swings it as far as it has room; the "
				+ "answer says where it stopped if something is in the way."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"joint": {"type": "string", "description": "its number or name in the list"},
				"degrees": {"type": "number"},
			}},
		},
		{
			"name": "move_part",
			"description": ("Move a part about its joint as the person's drag on it does. With no "
				+ "part= it changes nothing and says what moves in the model: what its link's card "
				+ "says (steering, a boom, doors...) with the part to take hold of, and every part "
				+ "on a joint. With part=, its "
				+ "whole rigid body and everything beyond it turn on the joint between it and "
				+ "what stays (a locked part, what stands on the baseplate, else the body "
				+ "with the most parts, or a heavier one standing on the floor): a hinge, a "
				+ "clip on a bar, a turntable, a pin or an axle in a round "
				+ "hole, a ball, a 1x1 round part on one stud. part= a part's number "
				+ "(look_at_model) or a sub-assembly's name. With nothing else it changes "
				+ "nothing and says what would move, on what, and how the model stands. "
				+ "degrees= turns it that far from where it is (a ball: about axis=), along= "
				+ "slides it that many studs along a bar or an axle; it stops where it meets "
				+ "the model, gears it drives turn by their teeth, a joint without friction "
				+ "swings down under its own weight once let go, and the answer says what moved, "
				+ "where its joint then stands from where it was built (twice 20° stands at 40°), "
				+ "and how the model stands then. A part held at both ends (a four-bar, a crank "
				+ "with its rod and piston, a steering's arms) moves as its loop allows, and says "
				+ "so where it locks. spin= lets it go turning that many degrees a second, as a "
				+ "flick does: a wheel, a gear train or a turntable on free bearings coasts and "
				+ "slows against their friction, and the answer says how far it spun and where "
				+ "it stopped. A model turned past its edge falls over and says how it lies, "
				+ "unless it stands on the baseplate's studs. to= [x, y, z] in studs instead draws "
				+ "the part to that point by its whole chain of joints back to what stays, each "
				+ "within its range. One undo step."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"part": {"type": "string", "description": "a part's number, or a sub-assembly's "
					+ "name; leave it out to list what moves"},
				"degrees": {"type": "number", "description": "turn from where it is now"},
				"along": {"type": "number", "description": "studs to slide along its line"},
				"spin": {"type": "number", "description": "let go turning this many degrees a second about its joint (after degrees=, if given): it coasts"},
				"axis": {"type": "array", "items": {"type": "number"}, "minItems": 3, "maxItems": 3,
					"description": "a ball's turn about this way (x y z), with degrees="},
				"to": {"type": "array", "items": {"type": "number"}, "minItems": 3, "maxItems": 3,
					"description": "a point in studs (x y z, as move_part says where a joint is): the part drawn there by its chain of joints"},
			}},
		},
		{
			"name": "animate_model",
			"description": ("Animate the model: poses at moments, "
				+ "played smoothly between (an arm raised over two seconds and lowered "
				+ "again, doors opening), the model turned round once as well if asked, and "
				+ "rendered as an animation (a WebP, and an MP4 where ffmpeg is installed) "
				+ "where Render saves. keys: [{\"t\": seconds, \"angles\": {joint: degrees}}], "
				+ "joints by number or name from pose_model's list, or a part on its joint as "
				+ "move_part names it (\"#14\": a steering, a wheel, an arm on its pin), each "
				+ "in degrees from where it was built. Rendering needs the app "
				+ "in a window and is a job (job gives the result). The keys are kept as the "
				+ "model's motion \"Animation\" (list_motions, play_motion), which the person plays "
				+ "in Build, Motions…; render=false only keeps them."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"keys": {"type": "array", "items": {"type": "object", "additionalProperties": false,
					"required": ["t", "angles"], "properties": {
						"t": {"type": "number", "description": "seconds from the start"},
						"angles": {"type": "object", "description":
							"joint (number or name) -> degrees from where it was built",
							"additionalProperties": {"type": "number"}},
					}}},
				"turntable": {"type": "boolean", "description": "turn the model round once over it"},
				"render": {"type": "boolean", "description": "true when omitted"},
			}},
		},
		{
			"name": "list_motions",
			"description": ("The model's own motions, kept in its file (\"Open the doors\", "
				+ "\"Steer left and right\"): each with its joints as move_part names them, their "
				+ "keys (seconds, and places from where the model was built: degrees turned, or "
				+ "studs slid), its driver, or the motions it plays in order (a sequence), and what "
				+ "it was last found to do: where each joint ended, or where it stopped and on what. "
				+ "A joint whose part is gone, or a sequence's motion that is gone, is said so. Then motions suggested from what moves (doors, steering, a "
				+ "boom, a turntable, gears, a rack), each tried for room, which define_motion "
				+ "keeps. Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"suggest": {"type": "boolean", "description": "suggest motions from what moves; true when omitted"},
			}},
		},
		{
			"name": "define_motion",
			"description": ("Keep a named motion in the model, as a builder names it (\"Open the "
				+ "dome\"), played by the real joints as a drag moves them. tracks= each a joint "
				+ "(a part's number \"#80\" or a sub-assembly's name, as move_part names them) "
				+ "and its keys: t= seconds, place= degrees turned from where the model was built "
				+ "(studs slid, with slide=true), how= ease (the default), linear or hold. Or "
				+ "driver= a joint turned turns= times over seconds=, from where it stands: what "
				+ "it drives through gears, racks and linkages follows. Or sequence= the model's "
				+ "motions by name, in order (\"Show it all\": [\"Open the dome\", \"Extend the "
				+ "telescope\"]): a motion made of motions, each played from where the one before "
				+ "left the model, backwards in reverse order. suggested=true keeps list_motions' "
				+ "suggestion of that name; remove=true takes a motion out. It is saved with the model (its autosave, "
				+ "a save, an export, a shared link), one undo step, and answers by playing it "
				+ "once and putting the model back: where each joint ended, or stopped and on what."),
			"input_schema": {"type": "object", "additionalProperties": false, "required": ["name"],
				"properties": {
				"name": {"type": "string", "description": "what a builder calls it: Open the doors"},
				"tracks": {"type": "array", "items": {"type": "object", "additionalProperties": false,
					"required": ["joint", "keys"], "properties": {
						"joint": {"type": "string", "description": "a part's number (#80) or a sub-assembly's name"},
						"slide": {"type": "boolean", "description": "slid along its line, places in studs"},
						"keys": {"type": "array", "items": {"type": "object", "additionalProperties": false,
							"required": ["t", "place"], "properties": {
								"t": {"type": "number", "description": "seconds from the start"},
								"place": {"type": "number", "description": "degrees (or studs) from where it was built"},
								"how": {"type": "string", "enum": ["ease", "linear", "hold"]},
							}}},
					}}},
				"driver": {"type": "object", "additionalProperties": false, "required": ["joint", "turns"],
					"properties": {
						"joint": {"type": "string", "description": "a crank, an axle or a gear: #N or a sub-assembly"},
						"turns": {"type": "number", "description": "turns; less than 0 the other way"},
						"seconds": {"type": "number", "description": "how long; 4 when omitted"},
					}},
				"sequence": {"type": "array", "items": {"type": "string"},
					"description": "the model's motions it plays, by name, in order"},
				"suggested": {"type": "boolean", "description": "keep list_motions' suggestion of this name"},
				"remove": {"type": "boolean"},
			}},
		},
		{
			"name": "play_motion",
			"description": ("Play one of the model's motions (list_motions) through its real "
				+ "joints, as a drag moves them: a joint stops where it meets the model, and gears, "
				+ "racks and linkages follow. The model is left where the motion ends, one undo "
				+ "step. reverse=true plays it backwards (closes what it opened; a driver turns "
				+ "back; a sequence plays its motions in reverse order). sequence=true plays the "
				+ "chain an older file's AFTER lines put it in. The answer says where each joint "
				+ "ended or stopped and on what, how the model then stands, and carries a picture "
				+ "of its frames from the view that sees most of what moves (or view=), and says which."),
			"input_schema": {"type": "object", "additionalProperties": false, "required": ["name"],
				"properties": {
				"name": {"type": "string"},
				"reverse": {"type": "boolean"},
				"sequence": {"type": "boolean"},
				"view": {"type": "string", "enum": MOTION_VIEWS},
			}},
		},
		{
			"name": "render_motion",
			"description": ("Render one of the model's motions as an animation, a WebP and an MP4 "
				+ "(where ffmpeg is installed) where Render saves, framed on what it moves, without "
				+ "changing the model. reverse= and sequence= as play_motion; fps= 12 or 24; size= "
				+ "480x300 or 720p; view= where the camera stands, hero (three-quarter from the front "
				+ "left, the default) or back for what moves at the back. Needs the app in a window, "
				+ "and is a job (job gives the result, with a picture of its frames)."),
			"input_schema": {"type": "object", "additionalProperties": false, "required": ["name"],
				"properties": {
				"name": {"type": "string"},
				"reverse": {"type": "boolean"},
				"sequence": {"type": "boolean"},
				"fps": {"type": "integer", "enum": [12, 24]},
				"size": {"type": "string", "enum": ["480x300", "720p"]},
				"view": {"type": "string", "enum": MOTION_VIEWS},
			}},
		},
		{
			"name": "simulate_mechanism",
			"description": ("Turn the model's gear train as Tools, Simulate mechanism does, "
				+ "and what it drives in a loop as a drag moves it (a pinion's rack slides, a "
				+ "crank's rod rocks and its slider strokes), "
				+ "without changing the model: from driver= (a part's number or a "
				+ "sub-assembly's name; else the one named Crank, Motor or Handle, else the one "
				+ "that turns most). It says each turning part's turns per driver turn and, with "
				+ "reference= (the part periods are counted in; Earth when one is named so), "
				+ "every other's period in its turns, against the real one for a planet or "
				+ "targets= ({name: period}). It names a locked train's meshes and the free and "
				+ "floating parts by number, and weighs the balance over the whole cycle: the "
				+ "worst frame, the arm furthest past the base's edge, a picture of it there. "
				+ "record=true also renders turns= turns of the reference (1) in frames= frames "
				+ "(24) as a WebP and an MP4 where Render saves, as a job (job gives the result)."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"driver": {"type": "string", "description": "a part's number from look_at_model, or a sub-assembly's name"},
				"reference": {"type": "string", "description": "the turning part periods are counted in: a number or a name"},
				"targets": {"type": "object", "description": "name -> the period wanted, in the reference's turns",
					"additionalProperties": {"type": "number"}},
				"frames": {"type": "integer", "description": "frames in a recording, 2 to 240; 24 when omitted"},
				"turns": {"type": "number", "description": "turns of the reference (or the driver) a recording covers; 1 when omitted"},
				"record": {"type": "boolean"},
			}},
		},
		{
			"name": "undo",
			"description": ("Take back the last change to the model, as Edit, Undo does — "
				+ "yours or the person's — or steps= of them. redo=true puts back what was "
				+ "undone. The answer names what was undone and what is next."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"steps": {"type": "integer", "description": "how many, 1 to 25; 1 when omitted"},
				"redo": {"type": "boolean"},
			}},
		},
		{
			"name": "open_model",
			"description": ("The person's saved models and the examples that come with the "
				+ "app, with their part counts; name= opens one in place of what is on the "
				+ "baseplate, as File, Open does. Each save is kept as a version, the last 20, "
				+ "as File, Versions… shows: versions=true lists name='s, newest first, and "
				+ "version=N opens the Nth. link= a gallery model's link id (gallery) opens a "
				+ "copy of it saved in the person's models, as Open in Brickworks on its page "
				+ "does. library= an id from gallery library=true (\"omr-10179-1\") opens LDraw's "
				+ "model of that real set, credited to whoever made it, as File, Library… does. "
				+ "Opening cannot be undone, so it is refused while "
				+ "the model has changes not saved, unless discard_changes=true."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"name": {"type": "string", "description": "a model's name from the list"},
				"link": {"type": "string", "description": "a gallery model's link id, or its /m/ address"},
				"library": {"type": "string", "description": "a library id from gallery library=true, like omr-10179-1"},
				"versions": {"type": "boolean", "description": "list name='s saves kept as versions"},
				"version": {"type": "integer", "description": "open this save of name=, 1 the newest"},
				"discard_changes": {"type": "boolean"},
			}},
		},
		{
			"name": "parts_list",
			"description": ("The model's parts, as Build, Parts list shows them: by part and "
				+ "colour, with counts and LEGO® element ids. which=\"need\" measures it "
				+ "against the person's collection (My collection): how much they own and "
				+ "what they are short of; which=\"buildable\" is What can I build?: their "
				+ "saved models, the examples and the official models of real sets, ranked by "
				+ "how much of each they own."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"which": {"type": "string", "enum": ["model", "need", "buildable"]},
				"limit": {"type": "integer", "description": "how many rows; 60 when omitted"},
			}},
		},
		{
			"name": "render_model",
			"description": ("Render the model as File, Render does: a picture, or a turntable "
				+ "(a WebP and, where ffmpeg is installed, an MP4), on a studio sweep with soft "
				+ "shadows. quality quick, good or best (good for a picture, quick for a "
				+ "turntable when omitted); size 720p, 1080p, 4k or square; view hero, "
				+ "front, side, back, low or top. Saved where Render saves. It is a job: the "
				+ "answer is a job number at once, and job gives the result, a picture with "
				+ "it. Needs the app in a window."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"kind": {"type": "string", "enum": ["picture", "turntable"]},
				"quality": {"type": "string", "enum": ["quick", "good", "best"]},
				"size": {"type": "string", "enum": ["720p", "1080p", "4k", "square"]},
				"view": {"type": "string", "enum": ["hero", "front", "side", "back", "low", "top"]},
			}},
		},
		{
			"name": "export_model",
			"description": ("Write the model out as File, Export does, where Export writes "
				+ "(the Downloads folder; a download on the web): format ldraw (.ldr, or .mpd "
				+ "with its sub-models, with its build steps), studio (a BrickLink Studio .io), "
				+ "a 3D file at real size — glb (one file: Blender, three.js, AR; any size of "
				+ "model), gltf (the same as text), obj (with an .mtl of its colours) or stl "
				+ "(one mesh in mm, Z up, to 3D print); obj and stl hold every triangle and are "
				+ "capped — picture (.png), bricklink (a wanted list), rebrickable (a parts "
				+ "list .csv), or instructions (the building instructions as a booklet to "
				+ "print); all_models is every model the person saved, as LDraw in one .zip "
				+ "(File, Export, All my models). studio, picture and instructions are jobs: "
				+ "the answer is a job number at once, and job gives the result."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["format"], "properties": {
				"format": {"type": "string", "enum": ["ldraw", "studio", "glb", "gltf", "obj",
					"stl", "picture", "bricklink", "rebrickable", "instructions", "all_models"]},
			}},
		},
		{
			"name": "brickify",
			"description": ("Lay a 3D model in LEGO® bricks, as Build, Brickify a 3D model… does: an "
				+ "OBJ, STL, glTF/GLB, PLY, 3MF, VOX or FBX laid at the size asked (studs along "
				+ "its longest side) "
				+ "in slopes, curves and tiles, or plain bricks and plates, as one "
				+ "sub-assembly named after the file, beside what is built. file= its path on "
				+ "this computer (the desktop app), or url= an http(s) "
				+ "link to the file, fetched by the app (96 MB at most; an OBJ's .mtl and a "
				+ ".gltf's .bin come from beside it). pick=true opens the window's file "
				+ "dialog for the person to choose one on their computer, and says so; once "
				+ "they have, brickify with neither lays what the panel shows. Laying is a "
				+ "job: the answer is a job number, and job gives the result: whether it is "
				+ "one piece and stands (weighed), on what, any stand it was given, what was "
				+ "joined, and anything left out, where and why; its steps, a course a step "
				+ "with every step's build standing; and how to get its booklet and lists. "
				+ "collection=true lays it from the person's collection: their parts and "
				+ "colours first, then stand-ins, the shortfall said."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"file": {"type": "string", "description": "the path of an .obj, .stl, .gltf, .glb, .ply, .3mf, .vox or .fbx on this computer"},
				"url": {"type": "string", "description": "http(s) link to an .obj, .stl, .gltf, .glb, .ply, .3mf, .vox or .fbx"},
				"pick": {"type": "boolean", "description": "open the file dialog for the person"},
				"studs": {"type": "integer", "description": "studs along its longest side, %d to %d; 24 when omitted"
					% [Brickify.LEAST_STUDS, Brickify.MOST_STUDS]},
				"up": {"type": "string", "enum": Array(Brickify.UPS),
					"description": "which of the file's axes is up; a printer's STL is +Z"},
				"hollow": {"type": "boolean"},
				"stand": {"type": "boolean", "description": "a stand under it where it would tip or stands on legs or wheels much thinner than itself; true when omitted"},
				"smooth": {"type": "boolean", "description": "slopes, curves, tiles and studs sideways; true when omitted"},
				"colours": {"type": "string", "enum": ["model", "one", "limit"],
					"description": "its own, all colour=, or its own cut to the limit= it uses most"},
				"colour": {"type": "integer", "description": "LDraw colour, for colours one"},
				"limit": {"type": "integer", "description": "how many colours, for colours limit"},
				"collection": {"type": "boolean", "description": "lay it from the person's collection (My collection)"},
			}},
		},
		{
			"name": "print_part",
			"description": ("Print a picture on a part of the model, or stick it on as a "
				+ "sticker, as Build, Print on a part… and Put a sticker on… do. brick= the "
				+ "part's number in look_at_model. A print goes on one of the part's "
				+ "printable areas (area=, the first when omitted; a wrong one is answered "
				+ "with its areas), and the printed part takes the part's place in its "
				+ "colour, a part of its own from then on. sticker=true makes a sticker the "
				+ "size of the part's side= face (up, down, +x, -x, +z, -z), running over the "
				+ "faces in the same plane beside it unless span=false, and sticks it on. "
				+ "The picture: svg= drawn by you (a whole <svg> with a viewBox in the face's "
				+ "proportions; flat colours print best), picture_data= a picture's own bytes "
				+ "as base64 or a data: URI (a PNG or JPEG the person gave you in the "
				+ "conversation; at most 2 MB, smaller is quicker), or picture_url= an http(s) "
				+ "link to a PNG, JPEG, WebP or SVG. Or the LEGO Group's own, as Edit, Printed "
				+ "versions… does: version= one of the part's printed or stickered versions from "
				+ "the library (versions=\"words\" lists them) swaps the part for it where it "
				+ "stands; sticker_part= a sticker the library has (search_parts \"sticker\") "
				+ "sticks it on the side= face, lying on it."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["brick"], "properties": {
				"brick": {"type": "integer", "description": "the part's number in look_at_model"},
				"sticker": {"type": "boolean"},
				"area": {"type": "string", "description": "a print's area, by name"},
				"side": {"type": "string", "enum": BrickLattice.FACE_AXIS.keys(),
					"description": "a sticker's face; +z when omitted"},
				"span": {"type": "boolean"},
				"svg": {"type": "string"},
				"picture_data": {"type": "string",
					"description": "the picture's bytes as base64, or a data:image/…;base64, URI"},
				"picture_url": {"type": "string"},
				"name": {"type": "string", "description": "what the print or sticker is called"},
				"versions": {"type": "string",
					"description": "list the part's printed versions with these words in their names; \"\" for all"},
				"version": {"type": "string",
					"description": "a printed or stickered version of the part, by id, to swap it for"},
				"sticker_part": {"type": "string",
					"description": "a sticker from the library, by id, to stick on the side= face"},
				"colour": {"type": "integer",
					"description": "the film's LDraw colour for sticker_part; white (15) when omitted"},
			}},
		},
		{
			"name": "make_unique",
			"description": ("Cut one copy of a sub-assembly loose from the others, as Edit, "
				+ "Make this copy unique does: it becomes a sub-assembly of its own, so "
				+ "changing it changes no other copy. assembly= its path or name "
				+ "(\"Wheel#2\" or \"Wheel (copy 2)\"), or brick= a part in it."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"assembly": {"type": "string"},
				"brick": {"type": "integer", "description": "a part in the copy, by its number"},
			}},
		},
		{
			"name": "colour_hidden_parts",
			"description": ("Colour the parts nobody sees in the finished model, as big sets "
				+ "are coloured inside so a builder can tell where they are, as Tools, Colour "
				+ "the hidden parts… does. Hidden is measured, never guessed: the model drawn "
				+ "from 128 sides, every part its own colour, and only parts seen from none of "
				+ "them change. mode: sections (the booklet's: the assemblies a design named), "
				+ "stages (the build cut into stages= stages, as bags are), left_right or "
				+ "front_back (the halves of a symmetrical build told apart). Each group gets "
				+ "one colour far from every colour seen, and each part only a colour it is "
				+ "made in. Without apply it changes nothing and shows the inside cut open, "
				+ "coloured. Offer it at the end of a big model built in sections, never by "
				+ "default: apply=true with agreed=true only once the person has said yes; a "
				+ "model from a real set also needs set_agreed=true. One step to undo; the "
				+ "booklet shows each colour where its group starts."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"mode": {"type": "string", "enum": HiddenColours.MODES},
				"stages": {"type": "integer", "description": "for stages: how many, 2 to 12; two when omitted, as most real sets use one or two"},
				"from_below": {"type": "boolean", "description": "true when omitted: a part seen from underneath keeps its colour. false for a display model never turned over"},
				"apply": {"type": "boolean"},
				"agreed": {"type": "boolean", "description": "the person said yes to this"},
				"set_agreed": {"type": "boolean", "description": "the person said yes to recolouring a real set's own parts"},
			}},
		},
		{
			"name": "suggest_sections",
			"description": ("How a builder would split the model into sections, as Build, "
				+ "Suggest sections does: the way a set splits into numbered bags and "
				+ "sub-builds. Each is connected and one piece, of a sensible size, joined to "
				+ "the rest by few joints, numbered in the order it is built, with the "
				+ "sections it is built onto and the way it comes off. Read from the booklet "
				+ "planner and the build check's joint graph. Changes nothing in the model; "
				+ "the suggestion is shown in the person's model tree. make_sections makes "
				+ "them sub-assemblies."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {}},
		},
		{
			"name": "make_sections",
			"description": ("Make the suggested sections (suggest_sections) sub-assemblies, "
				+ "as one undo step, as the model tree's Accept all does. With no sections= "
				+ "every suggestion as suggested; with sections= one sub-assembly for each "
				+ "entry: its name and the numbers of the suggestions it is made of (two or "
				+ "more merge them). Parts already in a sub-assembly go inside the new one."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"sections": {"type": "array", "items": {"type": "object",
					"additionalProperties": false, "required": ["from"], "properties": {
						"name": {"type": "string"},
						"from": {"type": "array", "items": {"type": "integer"},
							"description": "suggestion numbers"},
					}}},
			}},
		},
		{
			"name": "break_out_section",
			"description": ("Pull a section (a sub-assembly) away from the model the way "
				+ "it comes off, as Build, Break out the section does: up off the studs it "
				+ "stands on, or out to the side it is joined on, clear of the rest by two "
				+ "studs, by whole studs and bricks. One undo step. Work on it there with "
				+ "edit_model as anywhere. put_back=true puts it exactly where it was (one "
				+ "undo step); all=true puts every section back. Saved and exported files "
				+ "always have every section in place."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"section": {"type": "string",
					"description": "its name or path, as the sub-assemblies are listed"},
				"put_back": {"type": "boolean"},
				"all": {"type": "boolean", "description": "with put_back: every section"},
			}},
		},
		{
			"name": "evaluate_section",
			"description": ("A section on its own, as Build, Evaluate the section does: its "
				+ "parts and count, its parts list, weight, whether it holds together as a "
				+ "separate build (the build check on it alone), whether it stands on its "
				+ "own base (Balance), what joins it to the rest and whether those joints "
				+ "carry its load, and how many steps it takes alone. section= a "
				+ "sub-assembly's name or path, or suggestion= a suggest_sections number. "
				+ "Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"section": {"type": "string"},
				"suggestion": {"type": "integer"},
			}},
		},
		GalleryTool.definition(),
	]


func has(tool: String) -> bool:
	for one: Dictionary in definitions():
		if str(one["name"]) == tool:
			return true
	return false


## A coroutine: several of these wait on the window (a render, a fetch).
## [param work] is the Working job a long call reports to (ToolJobs): the
## bar the person sees, and what the session's job tool reads.
func run(tool: String, input: Dictionary, work: Working.Job = null) -> Variant:
	var refused: String = refusal(tool, input)
	if not refused.is_empty():
		return refused
	match tool:
		"set_floor":
			return _set_floor(input)
		"edit_steps":
			return _edit_steps(input)
		"booklet_layout":
			return await _booklet_layout(input)
		"edit_booklet":
			return await _edit_booklet(input)
		"lay_flex":
			return await _lay_flex(input)
		"pose_model":
			return _pose(input)
		"move_part":
			var grabbing: GrabDrag = app.get("_grab_drag")
			if grabbing == null:
				return "This app cannot move parts on their joints."
			if str(input.get("part", "")).strip_edges().is_empty():
				return _what_moves(grabbing)
			return await grabbing.for_session(input)
		"simulate_mechanism":
			return await _simulate(input, work)
		"animate_model":
			return await _animate(input, work)
		"list_motions":
			return _list_motions(input)
		"define_motion":
			return await _define_motion(input)
		"play_motion":
			return await _play_motion(input)
		"render_motion":
			return await _render_motion(input, work)
		"undo":
			return await _undo(input)
		"open_model":
			return await _open(input)
		"parts_list":
			return await _parts_list(input)
		"render_model":
			return await _render(input, work)
		"export_model":
			return await _export(input, work)
		"brickify":
			return await _brickify(input, work)
		"print_part":
			return await _print_part(input)
		"make_unique":
			return _make_unique(input)
		"suggest_sections":
			return await _suggest_sections()
		"make_sections":
			return _make_sections(input)
		"break_out_section":
			return _break_out_section(input)
		"evaluate_section":
			return await _evaluate_section(input)
		"colour_hidden_parts":
			var panel: HiddenColoursPanel = app.get("_hidden_colours")
			if panel == null:
				return "This app has no Colour the hidden parts."
			return await panel.for_session(input, work)
		"gallery":
			if _gallery == null:
				_gallery = GalleryTool.new()
				_gallery.app = app
			return await _gallery.run(input)
	return "No tool called %s." % tool


## Why [param tool] is not done now, before it begins, or "".
func refusal(tool: String, input: Dictionary) -> String:
	if app == null:
		return "This app cannot do that from outside."
	var shell: Shell = app.get("_shell")
	if shell != null and shell.read_only and not _while_looking(tool, input):
		return ("This tab shows a model shared to look at: it can be listed and its booklet "
			+ "made, not changed or written out. Open in Brickworks copies it into the "
			+ "person's own models.")
	if assistant != null and assistant.is_busy() and tool in CHANGES:
		return "The app's own designer is building right now; wait for it to finish."
	# A run kept to a list of parts: a tool that makes parts of its own is not.
	if not PartsOnly.tool_refusal(tool).is_empty():
		return PartsOnly.tool_refusal(tool)
	# As clear_model: a request about the selected parts changes those alone.
	if assistant != null and assistant.asked_about_selection() and tool in CHANGES:
		return ("Not now — the person asked about the parts they selected, and this would "
			+ "change more than those. Change them with edit_selection.")
	return ""


## The tools that change the model.
const CHANGES: Array[String] = ["set_floor", "edit_steps", "edit_booklet", "lay_flex", "pose_model", "move_part",
	"define_motion", "play_motion",
	"undo", "open_model", "brickify", "print_part", "make_unique", "colour_hidden_parts",
	"make_sections", "break_out_section"]


## What a model shared to look at allows, as Shell.LOOKING does for the
## window: its parts, its steps and its booklet, and asking what it stands on.
static func _while_looking(tool: String, input: Dictionary) -> bool:
	match tool:
		"gallery":
			return true
		"parts_list":
			return str(input.get("which", "model")) == "model"
		"edit_steps":
			return str(input.get("op", "list")) == "list"
		"set_floor", "pose_model":
			return input.is_empty()
		"move_part":
			return not input.has("degrees") and not input.has("along") and not input.has("to") \
				and not input.has("spin")
		"simulate_mechanism":
			return not bool(input.get("record", false))
		"export_model":
			return str(input.get("format", "")) == "instructions"
		"suggest_sections", "evaluate_section", "booklet_layout", "list_motions":
			return true
	return false


# -- the floor ----------------------------------------------------------------


func _set_floor(input: Dictionary) -> String:
	var store: ModelStore = app.get("_store")
	var floor_layer: FloorLayer = app.get("_floor")
	if input.is_empty():
		return "It stands on %s%s." % [store.model_floor.words().to_lower(),
			", part of the model" if floor_layer.has_own_plate() else ""]
	var chosen: ModelFloor = store.model_floor.copy()
	if input.has("kind"):
		var kind: String = str(input["kind"]).to_lower()
		if not kind in ModelFloor.KINDS:
			return "kind is one of %s." % ", ".join(ModelFloor.KINDS)
		chosen.kind = kind
	if input.has("across") or input.has("deep") or input.has("colour"):
		if not input.has("kind"):
			chosen.kind = ModelFloor.BASEPLATE
	if input.has("across") or input.has("deep"):
		var across: int = int(input.get("across", input.get("deep", chosen.across)))
		var deep: int = int(input.get("deep", across))
		for side: int in [across, deep]:
			if side < ModelFloor.LEAST or side > ModelFloor.MOST or side % 8 != 0:
				return ("Baseplates are cut in eights of studs, %d to %d: %d is not one. "
					% [ModelFloor.LEAST, ModelFloor.MOST, side]
					+ "The nearest is %d." % clampi(roundi(side / 8.0) * 8, ModelFloor.LEAST,
						ModelFloor.MOST))
		chosen.across = across
		chosen.deep = deep
	if input.has("colour"):
		var code: int = int(input["colour"])
		var known: bool = false
		for pair: Array in ModelFloor.COLOURS:
			known = known or int(pair[0]) == code
		if not known:
			var colours := PackedStringArray()
			for pair: Array in ModelFloor.COLOURS:
				colours.append("%d %s" % [int(pair[0]), str(pair[1])])
			return "Baseplates are not made in colour %d. They come in %s." % [code,
				", ".join(colours)]
		chosen.colour = code
	var part: bool = bool(input.get("part_of_model", floor_layer.has_own_plate() and chosen.is_plate()))
	if part and not chosen.is_plate():
		return "Only a baseplate can be part of the model; give kind=\"baseplate\"."
	var builder: Builder = app.get("_builder")
	var depth: int = builder.history_depth()
	# Taken out of the model first: a floor changed under the model's own
	# plates would lay fresh ones beside them.
	if floor_layer.has_own_plate() and (not part or not chosen.same_as(store.model_floor)):
		app.call("floor_part_of_model", false)
	app.call("choose_floor", chosen)
	if part and not floor_layer.has_own_plate():
		app.call("floor_part_of_model", true)
	_one_undo_since(depth)
	return "It stands on %s%s." % [store.model_floor.words().to_lower(),
		", part of the model" if floor_layer.has_own_plate() else ""]


## Whatever went into the history since it was [param depth] deep, as one
## undo step: one call, one undo.
func _one_undo_since(depth: int) -> void:
	(app.get("_builder") as Builder).fold_since(depth)


# -- the build steps ------------------------------------------------------------


func _edit_steps(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var shell: Shell = app.get("_shell")
	var op: String = str(input.get("op", "list"))
	var steps: Array[Instructions.Step] = Instructions.plan(world, library, store.scenery, {},
		true)
	if steps.is_empty():
		return "There is nothing built to have steps."
	match op:
		"list":
			return _list_steps(steps, int(input.get("from", 1)))
		"next", "prev", "new":
			var ids: Array = []
			var unknown := PackedStringArray()
			for raw: Variant in input.get("bricks", []):
				var number: int = int(raw)
				if _brick(number) == null:
					unknown.append(str(number))
				else:
					ids.append(number)
			if not unknown.is_empty():
				return "No part numbered %s (look_at_model numbers them)." % ", ".join(unknown)
			if ids.is_empty():
				return "Give bricks= the part numbers to move, from look_at_model or this list."
			return shell.change_steps(op, ids, null)
		"earlier", "later", "merge", "delete":
			if not input.has("step"):
				return "Give step= a step's number from edit_steps's list."
			var at: Instructions.Step = _step_numbered(steps, int(input["step"]))
			if at == null:
				return "There is no step %d: the steps run 1 to %d." % [int(input["step"]),
					steps[steps.size() - 1].number]
			return shell.change_steps(op, [], at)
	return "op is one of list, next, prev, new, earlier, later, merge, delete."


# -- the booklet, by hand --------------------------------------------------------


## The pages as the booklet would lay them out now (BookletMaker.lay_out_only).
func _booklet_layout(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var maker := BookletMaker.new()
	maker.library = library
	app.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(world, store.scenery, "Model")
	maker.queue_free()
	if pages.is_empty():
		return "There is nothing built to make a booklet of."
	return BookletLooks.layout_said(world, pages, int(input.get("from", 2)))


## How a step is printed, set (Shell.change_look): one undo.
func _edit_booklet(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var shell: Shell = app.get("_shell")
	var steps: Array[Instructions.Step] = Instructions.plan(world, library, store.scenery, {},
		true)
	if steps.is_empty():
		return "There is nothing built to have steps."
	var at: Instructions.Step = _step_numbered(steps, int(input.get("step", 0)))
	if at == null:
		return "There is no step %d: the steps run 1 to %d." % [int(input.get("step", 0)),
			steps[steps.size() - 1].number]
	if input.has("place") or input.has("text") or input.has("arrow"):
		return await _edit_page(input, at)
	var fields: Dictionary = {}
	if input.has("highlight"):
		var on: String = shell.change_look("highlight", at, {"highlight": bool(input["highlight"])})
		if input.size() <= 2:
			return on
	if input.has("turn") or input.has("tilt"):
		var raw: Variant = input.get("turn", 0.0)
		if raw is String and str(raw) == "usual":
			fields["turn"] = "usual"
		elif raw is String and not str(raw).is_valid_float():
			return "turn= is degrees round, or \"usual\"."
		else:
			var round: float = fposmod(float(raw) + 180.0, 360.0) - 180.0
			var tilt: float = clampf(float(input.get("tilt", 0.0)), -60.0, 45.0)
			fields["turn"] = [tilt, round, 0.0]
			fields["how"] = "REL"
	if input.has("zoom"):
		fields["zoom"] = clampf(float(input["zoom"]), 0.5, 3.0)
	if input.has("size"):
		fields["size"] = clampf(float(input["size"]), 0.6, 2.0)
	if input.has("page"):
		var page: String = str(input["page"])
		if not page in ["new", "alone", "auto"]:
			return "page= is \"new\", \"alone\" or \"auto\"."
		fields["page"] = null if page == "auto" else page
	if input.has("parts"):
		fields["parts"] = bool(input["parts"])
	if input.has("sign"):
		fields["sign"] = bool(input["sign"])
	if input.has("callout"):
		fields["callout"] = bool(input["callout"])
	if input.has("per_page"):
		if not int(input["per_page"]) in [0, 1, 2, 4]:
			return "per_page= is 1, 2, 4, or 0 for as many as fit."
		fields["per_page"] = int(input["per_page"])
	if fields.is_empty():
		return ("Say what to set: turn=, tilt=, zoom=, size=, page=, parts=, sign=, callout= "
			+ "or per_page=. booklet_layout says how each step is printed now.")
	var said: String = shell.change_look("set", at, fields)
	var now: String = ""
	if at.authored_step >= 0 or AuthorSteps.any(world, store.scenery):
		var again: Instructions.Step = _step_numbered(Instructions.plan(world, library,
			store.scenery, {}, true), at.number)
		if again != null and again.authored_step >= 0:
			now = BookletLooks.said(world, again.authored_in, again.authored_step)
	return said + (("; step %d is now: %s" % [at.number, now]) if not now.is_empty() else "")


## The page by hand (Shell.change_look "place", "note", "text"), as the
## page editor's drags and Add words do: one undo. Each kept with the room
## the step has on its page now, as the page editor keeps it.
func _edit_page(input: Dictionary, at: Instructions.Step) -> String:
	var shell: Shell = app.get("_shell")
	if int(input.has("place")) + int(input.has("text")) + int(input.has("arrow")) > 1:
		return "One at a time: place=, text= or arrow=, each its own undo step."
	var entry: Booklet.Entry = await _laid_entry(at)
	var room: Variant = BookletLooks.said_rect(entry.panel) if entry != null else null
	if input.has("arrow"):
		var arrow: Dictionary = input["arrow"] if input["arrow"] is Dictionary else {}
		var points: Array = []
		for name: String in ["x1", "y1", "x2", "y2"]:
			if arrow.has(name):
				points.append(float(arrow[name]))
		if arrow.has("bx") and arrow.has("by") and points.size() == 4:
			points.append_array([float(arrow["bx"]), float(arrow["by"])])
		if arrow.has("index"):
			var fields: Dictionary = {"index": int(arrow["index"]), "room": room}
			if bool(arrow.get("remove", false)):
				fields["remove"] = true
			if points.size() >= 4:
				fields["at"] = points
			for name: String in ["colour", "width"]:
				if arrow.has(name):
					fields[name] = arrow[name]
			var changed: String = shell.change_look("arrow_edit", at, fields)
			if points.size() >= 4 and not fields.has("remove"):
				changed += _aimed(entry, at.number, points, int(arrow["index"]))
			return changed
		if points.size() < 4:
			return "arrow= {x1, y1, x2, y2} in mm: where it starts and where it points."
		var index: int = entry.drawn_arrows.size() if entry != null else 0
		return shell.change_look("arrow", at, {"at": points, "colour": str(arrow.get("colour", "red")),
			"width": float(arrow.get("width", 0.9)), "room": room}) \
			+ _aimed(entry, at.number, points, index)
	if input.has("text"):
		var given: Variant = input["text"]
		var text: Dictionary = given if given is Dictionary else {"words": str(given)}
		var words: String = str(text.get("words", "")).strip_edges()
		if words.is_empty():
			return "text= {words, x, y, w, h, size}: say the words."
		return shell.change_look("text", at, {"text": words, "size": float(text.get("size", 4.0)),
			"at": [float(text.get("x", 20.0)), float(text.get("y", 150.0)),
				float(text.get("w", 80.0)), float(text.get("h", 12.0))], "room": room})
	var place: Dictionary = input["place"] if input["place"] is Dictionary else {}
	var item: String = str(place.get("item", ""))
	if item == "note":
		var fields: Dictionary = {"index": int(place.get("index", -1)), "room": room}
		if bool(place.get("remove", false)):
			fields["remove"] = true
		else:
			var now: Rect2 = _now_at(entry, "note", int(place.get("index", -1)))
			fields["at"] = [float(place.get("x", now.position.x)), float(place.get("y", now.position.y)),
				float(place.get("w", now.size.x)), float(place.get("h", now.size.y))]
		return shell.change_look("note", at, fields)
	if not BookletLooks.ITEMS.has(item):
		return "place= {item: picture, parts, callout, number or note, x, y, w, h} in mm."
	if bool(place.get("back", false)):
		return shell.change_look("place", at, {"item": item, "at": null, "room": room})
	if not place.has("x") or not place.has("y"):
		return "place= needs x and y, in mm from the page's top left corner."
	var now: Rect2 = _now_at(entry, item)
	return shell.change_look("place", at, {"item": item, "at": [float(place["x"]),
		float(place["y"]), float(place.get("w", now.size.x)), float(place.get("h", now.size.y))],
		"room": room})


## Whether an arrow's tip ([param points] x2, y2) is on what step [param
## number] adds, as its picture draws it ([member Booklet.Entry.adds]), said
## after the arrow is drawn. A session drew its arrow for a steering wheel
## from the zoom alone, onto the seat beside it, and told the person it
## pointed at the wheel.
static func _aimed(entry: Booklet.Entry, number: int, points: Array, index: int) -> String:
	if entry == null or entry.adds.size.x <= 0.0:
		return ""
	var tip := Vector2(float(points[2]), float(points[3]))
	var adds: Rect2 = entry.adds
	if adds.grow(2.0).has_point(tip):
		return ". Its tip is on step %d's new parts, at %s." % [number, BookletLooks.adds_said(adds)]
	var nearest := Vector2(clampf(tip.x, adds.position.x, adds.end.x),
		clampf(tip.y, adds.position.y, adds.end.y))
	return (". Its tip is %d mm from step %d's new parts, which its picture draws at %s: "
		% [roundi(tip.distance_to(nearest)), number, BookletLooks.adds_said(adds)]
		+ "arrow={\"index\": %d, x2, y2} moves the tip onto them." % index)


## Step [param at] as the booklet lays it out now (BookletMaker.lay_out_only),
## or null.
func _laid_entry(at: Instructions.Step) -> Booklet.Entry:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var maker := BookletMaker.new()
	maker.library = app.get("_library")
	app.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(world, store.scenery, "Model")
	maker.queue_free()
	for page: Booklet.Page in pages:
		if page.kind != "steps":
			continue
		for entry: Booklet.Entry in page.entries:
			if entry.number == at.number:
				return entry
	return null


## Where [param item] of [param entry]'s page is laid out, in page mm.
static func _now_at(entry: Booklet.Entry, item: String, index: int = -1) -> Rect2:
	if entry != null:
		match item:
			"picture":
				return entry.rect
			"parts":
				return entry.parts_rect
			"callout":
				return entry.callout.box if entry.callout != null else Rect2()
			"note":
				if index >= 0 and index < entry.notes.size():
					return BookletLooks.rect_of((entry.notes[index] as Dictionary).get("at", []))
	return Rect2(0, 0, 40, 30)


## The step of the model with this number: the one that puts a callout on,
## not a step inside it, which carries the same number.
static func _step_numbered(steps: Array[Instructions.Step], number: int) -> Instructions.Step:
	var found: Instructions.Step = null
	for step: Instructions.Step in steps:
		if step.number == number and (found == null or step.callout_step == 0):
			found = step
	return found


func _list_steps(steps: Array[Instructions.Step], from: int) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var said := PackedStringArray()
	var authored: bool = AuthorSteps.any(world, store.scenery)
	var count: int = steps[steps.size() - 1].number
	said.append("%d step%s, %s." % [count, "" if count == 1 else "s",
		"the model's own" if authored
			else "worked out by the app (the first edit makes them the model's own)"])
	var shown: int = 0
	var characters: int = 0
	for step: Instructions.Step in steps:
		if step.number < from:
			continue
		var ids: PackedInt64Array = step.brick_ids
		var numbers := PackedStringArray()
		for brick_id: int in ids.slice(0, 12):
			numbers.append("#%d" % brick_id)
		if ids.size() > 12:
			numbers.append("and %d more" % (ids.size() - 12))
		var where: String = ""
		if step.callout_step > 0:
			where = " (in the %s, %d of %d)" % [step.assembly, step.callout_step,
				step.callout_steps]
		elif not step.copies.is_empty():
			where = " (puts on the %s%s)" % [step.assembly,
				" x%d" % step.copies.size() if step.copies.size() > 1 else ""]
		var line: String = "  %d%s: %s" % [step.number, where, " ".join(numbers)]
		characters += line.length()
		if characters > 6000:
			said.append("  ... edit_steps {\"from\": %d} for the rest." % step.number)
			break
		said.append(line)
		shown += 1
	if shown == 0:
		said.append("  none from step %d." % from)
	return "\n".join(said)


## A part by its look_at_model number, or null: the baseplate is not one.
func _brick(number: int) -> BrickWorld.Brick:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	if store.scenery.has(number):
		return null
	return world.get_brick(number)


# -- hoses, tubes and chains -------------------------------------------------------


func _lay_flex(input: Dictionary) -> String:
	var flex: FlexTool = app.get("_flex")
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var kind: String = str(input.get("kind", ""))
	if not Flex.KINDS.has(kind):
		return "kind is one of %s." % ", ".join(FlexTool.KIND_ORDER)
	var item: String = str(input.get("item", ""))
	if not item.is_empty():
		var found: String = ""
		for path: String in Flex.items_in(world).keys():
			if path == item or Assemblies.label(path) == item:
				found = path
		if found.is_empty():
			return "No hose or chain called %s. There is: %s." % [item,
				", ".join(PackedStringArray(Flex.items_in(world).keys().map(
					func(path: String) -> String: return Assemblies.label(path))))]
		item = found
	var colour: int = int(input.get("color", 0))
	var chain: bool = str(Flex.KINDS[kind]["family"]) == "links"
	var anchors: Array = []
	var sprockets: Array = []
	if chain:
		for raw: Variant in input.get("sprockets", []):
			var brick: BrickWorld.Brick = _brick(int(raw))
			if brick == null or Flex.sprocket_of(brick, library) == null:
				return "#%d is not a sprocket or a gear a %s goes round." % [int(raw), kind]
			sprockets.append(brick.id)
		if sprockets.size() < 2:
			return "Give sprockets= two or more gears' part numbers, in one plane."
	else:
		var all: Array = Flex.anchors_in(world, library, kind, {})
		var ends: Array = [input.get("from", {}), input.get("to", {})]
		var on: Array = []
		for n: int in 2:
			if not (ends[n] is Dictionary) or not (ends[n] as Dictionary).has("brick"):
				return "Give from= and to=, each {\"brick\": a part number}, the parts it joins."
			var brick: BrickWorld.Brick = _brick(int((ends[n] as Dictionary)["brick"]))
			if brick == null:
				return "No part numbered %d." % int((ends[n] as Dictionary)["brick"])
			var mine: Array = all.filter(func(a: Flex.Anchor) -> bool: return a.brick == brick.id)
			if mine.is_empty():
				return ("#%d (%s) has nothing a %s goes on: it takes %s."
					% [brick.id, brick.part_id, kind.replace("_", " "),
						", ".join(PackedStringArray(Flex.KINDS[kind].get("takes", []))).replace("_", " ")])
			on.append(mine)
		# Each end on the connector asked for, else the two nearest each other.
		for n: int in 2:
			var asked: Dictionary = ends[n]
			if asked.has("x") or asked.has("y") or asked.has("z"):
				var near := Vector3(float(asked.get("x", 0.0)) * Assistant.STUD,
					float(asked.get("y", 0.0)) * Assistant.PLATE,
					float(asked.get("z", 0.0)) * Assistant.STUD)
				on[n] = [_nearest(on[n], near)]
		var best: Array = []
		var gap: float = INF
		for a: Flex.Anchor in on[0]:
			for b: Flex.Anchor in on[1]:
				var apart: float = a.middle().distance_to(b.middle())
				if apart < gap and a != b:
					gap = apart
					best = [a, b]
		if best.is_empty():
			return "Both ends are the same connector; give two."
		anchors = best
	var laid: Flex.Laid = await flex.lay(kind, anchors, sprockets, colour, item)
	if laid == null or laid.pieces.is_empty():
		var why: String = "" if laid == null else "; ".join(laid.warnings)
		return "Nothing laid%s." % (": " + why if not why.is_empty() else
			" — those ends do not make a path it can take")
	var said: String = "Laid %s: %d pieces, %s." % [Assemblies.label(flex.laid_item()),
		laid.pieces.size(), "%.0f LDU along" % laid.length if laid.length > 0.0 else "round the sprockets"]
	if not laid.warnings.is_empty():
		said += " But: %s." % "; ".join(laid.warnings)
	return said


static func _nearest(anchors: Array, near: Vector3) -> Flex.Anchor:
	var best: Flex.Anchor = null
	for anchor: Flex.Anchor in anchors:
		if best == null or anchor.middle().distance_to(near) < best.middle().distance_to(near):
			best = anchor
	return best


# -- posing ------------------------------------------------------------------------


const NO_JOINTS := ("a joint is a sub-assembly on a hinge, a turntable or a clip on a bar. "
	+ "Name the part that turns as an assembly (edit_model's assemblies), standing on its hinge. "
	+ "Parts on pins, axles, studs and steering move without one, as a drag moves them: "
	+ "move_part with no part= lists them, and animate_model takes them by part (#14).")


## The turns a joint pose_model lists is tried at, each way, before it is
## said to have no room to turn.
const STUCK_DEGREES: Array[float] = [10.0, 90.0]


func _pose(input: Dictionary) -> String:
	var panel: PosePanel = app.get("_pose")
	# The assemblies a design named are sub-models only once tagged, as a
	# save tags them; until then nothing in it could turn.
	if assistant != null:
		assistant._tag_assemblies()
	var joints: Array[Poser.Joint] = panel.joints_now()
	if joints.is_empty():
		return "Nothing here turns: " + NO_JOINTS
	if not input.has("joint"):
		var said := PackedStringArray()
		var stuck: int = 0
		for n: int in joints.size():
			var one: Poser.Joint = joints[n]
			# A sub-assembly the file names is not always what moves: real
			# sessions asked to raise 4096-1's boom swung its one joint +45
			# and -45, both stopped at 0, before move_part found the boom.
			# A wheel on its axle has room at a quarter turn and none at 10°
			# (8808-1's rear axle): its turned cover is coarser than its shape.
			var held: bool = true
			for degrees: float in STUCK_DEGREES:
				if panel.poser.has_room_to(one, degrees) or panel.poser.has_room_to(one, -degrees):
					held = false
					break
			if held:
				stuck += 1
			said.append("  %d. %s, on its %s, at %d° (%d parts)%s" % [n + 1,
				Assemblies.label(one.path), one.kind(), roundi(one.angle), one.ids.size(),
				", with no room to turn 10° or 90° either way" if held else ""])
		if stuck > 0:
			said.append("A joint with no room is often not what moves: move_part with no part= "
				+ "lists what a drag moves, and animate_model takes those by part (#14).")
		return "Joints:\n%s\npose_model {\"joint\": \"1\", \"degrees\": 45} swings one." \
			% "\n".join(said)
	var asked: String = str(input["joint"]).strip_edges()
	var joint: Poser.Joint = _joint_named(joints, asked)
	if joint == null:
		return "No joint %s: there are %d, numbered in pose_model's list." % [asked, joints.size()]
	if not input.has("degrees"):
		return "%s is at %d°. Give degrees= to swing it." % [Assemblies.label(joint.path),
			roundi(joint.angle)]
	var wanted: float = clampf(float(input["degrees"]), -180.0, 180.0)
	var reached: float = panel.set_angle(joint.path, wanted)
	if absf(reached - wanted) > 0.5:
		return "%s stops at %d°: any further and it runs into something." % [
			Assemblies.label(joint.path), roundi(reached)]
	return "%s at %d°." % [Assemblies.label(joint.path), roundi(reached)]


## The motion animate_model keeps its keys as.
const ANIMATION := "Animation"


## Bodies listed by move_part with no part=; the rest are counted.
const MOST_MOVING := 16


## move_part with no part=: what moves in the model, as its link's card says
## it (Playable: "Moves: steering, boom") with the part a person takes hold
## of for each, then every body a drag moves on its joint, biggest first, by
## a part that moves it. Changes nothing. Asked "what in this model moves?",
## a session had only part= to try, and tried five parts one at a time to
## find a kart's steering (bench/results/mcpwalk2-2026-10-19, t2).
func _what_moves(grabbing: GrabDrag) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	if world.brick_count() - store.scenery.size() <= 0:
		return "Nothing is built yet."
	grabbing.read_now()
	var bodies: Bodies = grabbing.read_bodies()
	if bodies == null:
		return "Its joints could not be read just now; ask again."
	var named := func(id: int) -> String:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		return "#%d %s" % [id, Inventory._tidy(info.name) if info != null else brick.part_id if brick != null else "?"]
	var found: Dictionary = Playable.read(bodies, world, library, grabbing.read_mechanism())
	var lines := PackedStringArray()
	var takes: Dictionary = {}   ## a part a person takes hold of -> true
	if found.is_empty():
		lines.append("What moves, as its link's card says: nothing it names (steering, a turntable, "
			+ "a boom, doors, gears, pneumatics, an actuator, a rack).")
	else:
		lines.append("%s, as its link's card says. Take hold of:" % Playable.words(Playable.kinds(found)))
		for kind: String in found:
			var ids: Array = found[kind]
			var said := PackedStringArray()
			for id: Variant in ids.slice(0, 3):
				said.append(named.call(int(id)))
				takes[int(id)] = true
			lines.append("  %s: %s%s" % [kind, ", ".join(said),
				" and %d more" % (ids.size() - 3) if ids.size() > 3 else ""])
	var moving: Array = []   ## [parts, body]
	for key: Variant in bodies.parent_link:
		if not bodies.flexible.has(key):
			moving.append([(bodies.members.get(key, PackedInt64Array()) as PackedInt64Array).size(), int(key)])
	if moving.is_empty():
		lines.append("Nothing in it hangs on a joint: every part is held rigidly to what stays (%s)."
			% bodies.summary())
		lines.append("Nothing was changed.")
		return "\n".join(lines)
	moving.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	lines.append("On a joint a drag moves, biggest first; move_part part=N moves that part's body and "
		+ "what is beyond it:")
	for one: Array in moving.slice(0, MOST_MOVING):
		var link: Bodies.Link = bodies.parent_link[one[1]]
		var ids: PackedInt64Array = bodies.members[one[1]]
		var by: int = int(ids[0])
		for id: int in ids:
			if takes.has(id):
				by = id
				break
		lines.append("  %s%s, %s at %s%s" % [named.call(by),
			" and %d more part%s" % [ids.size() - 1, "" if ids.size() == 2 else "s"] if ids.size() > 1 else "",
			link.words(), GrabDrag.at_words(link.point), "" if link.holds else ", turning freely"])
	if moving.size() > MOST_MOVING:
		lines.append("  and %d more." % (moving.size() - MOST_MOVING))
	lines.append("Nothing was changed. move_part part=N says what moving it does; degrees= turns it.")
	return "\n".join(lines)


## The joint a session names: its number in pose_model's list, its path or
## its name. Null when none is.
static func _joint_named(joints: Array[Poser.Joint], asked: String) -> Poser.Joint:
	asked = asked.strip_edges()
	if asked.is_valid_int() and int(asked) >= 1 and int(asked) <= joints.size():
		return joints[int(asked) - 1]
	for one: Poser.Joint in joints:
		if one.path == asked or Assemblies.label(one.path).to_lower() == asked.to_lower():
			return one
	return null


func _animate(input: Dictionary, work: Working.Job = null) -> Variant:
	var panel: PosePanel = app.get("_pose")
	if assistant != null:
		assistant._tag_assemblies()
	var joints: Array[Poser.Joint] = panel.joints_now()
	var turning: bool = bool(input.get("turntable", false))
	var keys: Array = input.get("keys", []) as Array
	if keys.is_empty() and not turning:
		return ("Give keys= (poses at moments: [{\"t\": 0, \"angles\": {\"1\": 0}}, {\"t\": 2, "
			+ "\"angles\": {\"1\": 60}}]) or turntable=true.")
	var made: Array = []
	# A part on its joint as move_part turns it (a kart's steering on its
	# pins): pose_model's joints are sub-assemblies on a hinge, a turntable
	# or a clip, and a session that steered a car with move_part could not
	# animate it (bench/results/mcpwalk2-2026-10-19, t3). The panel turns
	# it by its name, as Play and Render animation run the keys.
	var grabbing: GrabDrag = app.get("_grab_drag")
	for raw: Variant in keys:
		if not (raw is Dictionary) or not (raw as Dictionary).has("t"):
			return "Each key is {\"t\": seconds, \"angles\": {joint: degrees}}."
		var key: Dictionary = raw
		var t: float = float(key["t"])
		if t < 0.0 or t > 60.0:
			return "A key's t is seconds from the start, 0 to 60: %s is not." % str(key["t"])
		var angles: Dictionary = {}
		var given: Dictionary = key.get("angles", {}) as Dictionary
		for name: Variant in given.keys():
			var joint: Poser.Joint = _joint_named(joints, str(name))
			var path: String = joint.path if joint != null else ""
			if joint == null and grabbing != null:
				var turning_part: Variant = grabbing.turning_for_session(str(name))
				if turning_part is String:
					return ("No joint %s: %s. Joints are pose_model's, by number or name, or a part on "
						% [str(name), turning_part] + "its joint as move_part names it (#14).")
				path = "#%s" % str(name).strip_edges().trim_prefix("#")
			elif joint == null:
				return ("No joint %s. %s" % [str(name), "pose_model lists them."
					if not joints.is_empty() else "Nothing here turns: " + NO_JOINTS])
			angles[path] = clampf(float(given[name]), -180.0, 180.0)
		made.append([t, angles])
	panel.animation.keys.clear()
	for one: Array in made:
		panel.animation.add_key(float(one[0]), one[1])
	panel.animation.turntable = turning
	var said: String = "%d key%s over %.1f s%s" % [made.size(), "" if made.size() == 1 else "s",
		panel.animation.length(), ", turning round once" if turning else ""]
	# One path: the keys are a motion, kept in the model as "Animation" (the
	# person plays it in Build, Motions…), and played once through Grab
	# (MotionPlayer) to render; Pose's joints by their sub-assemblies, taken
	# as a drag takes them.
	var player: MotionPlayer = app.get("_motions")
	var motion := Motions.Motion.new()
	motion.name = ANIMATION
	motion.seconds = panel.animation.length()
	for path: String in panel.animation.paths():
		var joint: Variant = player.joint_named(path, false, false)
		if joint is String:
			return "Nothing kept or rendered: %s" % joint
		var track := Motions.Track.new()
		track.joint = joint
		for key: Dictionary in panel.animation.keys:
			if (key["angles"] as Dictionary).has(path):
				track.add_key(float(key["t"]), float(key["angles"][path]), "EASE")
		motion.tracks.append(track)
	var kept: String = ""
	if not motion.tracks.is_empty():
		var motions: Motions = player.motions()
		var replaced: bool = motions.named(ANIMATION) != null
		var had: Motions = motions.copy()
		motions.put(motion)
		var builder: Builder = app.get("_builder")
		builder.record([{"undo": "motions", "motions": had}], "%s the motion %s" % [
			"changed" if replaced else "made", Motions.quoted(ANIMATION)])
		kept = (" Kept as the motion %s: the person plays it in Build, Motions…, and play_motion "
			+ "plays it; one step: undo takes it out.") % Motions.quoted(ANIMATION)
	if not bool(input.get("render", true)):
		return "Set %s.%s" % [said, kept]
	if not StudioRender.possible():
		return ("Set %s. Rendering it needs something to draw with, and this app is running "
			% said + "without a window.%s" % kept)
	var played: MotionPlayer.Played = player.play(motion, false, panel.animation.fps)
	var poses: Array = played.frames.slice(0, panel.animation.frame_count())
	# The model turned round once with nothing on its joints: frames that
	# move nothing, turned.
	while poses.size() < panel.animation.frame_count():
		poses.append(poses.back() if not poses.is_empty() else {})
	var frames: int = await panel.render_poses(poses, panel.animation.fps,
		func(n: int) -> float: return panel.animation.turn_at(panel.animation.time_of(n)),
		panel._sheet_frames(poses.size()), work, "hero", ANIMATION)
	if frames <= 0 or not panel._last.has("kept"):
		return "Nothing rendered: %s" % panel.rendered_words()
	# Its own words, not the panel's line, whose "— 3 s" at the end is how
	# long drawing took: a session read it as an MP4 cut short of its 4 s.
	var lines := PackedStringArray(["%s: %d frames, %d a second, drawn in %d s: %s." % [
		said.left(1).to_upper() + said.substr(1), frames, panel.animation.fps,
		int(panel._last["seconds"]), str(panel._last["kept"])]])
	# A part that met the model stood still in the frames past it, and the
	# answer said only how many frames there were (31070-1's windscreen).
	for item: MotionPlayer.Item in played.items:
		if not item.stop_words.is_empty():
			lines.append("%s; the frames that ask for more show it there." % item.stop_words)
	for line: String in played.refused:
		lines.append("%s, so it stood still." % line)
	var times: Array = []
	var picture: Image = panel.sheet(times)
	if picture == null:
		return "\n".join(lines)
	lines.append("The picture: its frames at %s, left to right and down." % _times_words(times))
	return [{"type": "text", "text": "\n".join(lines)}, _picture_block(picture)]


static func _times_words(times: Array) -> String:
	var at := PackedStringArray()
	for t: float in times:
		at.append("%d s" % roundi(t) if is_equal_approx(snappedf(t, 0.1), roundf(t)) else "%.1f s" % t)
	return ", ".join(at)


static func _picture_block(picture: Image) -> Dictionary:
	return {"type": "image", "source": {"type": "base64", "media_type": "image/png",
		"data": Marshalls.raw_to_base64(picture.save_png_to_buffer())}}


# -- motions ------------------------------------------------------------------------


## list_motions: the model's motions and what each was last found to do,
## then the ones suggested from what moves. Changes nothing.
func _list_motions(input: Dictionary) -> String:
	var player: MotionPlayer = app.get("_motions")
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	if player == null:
		return "This app has no motions."
	if world.brick_count() - store.scenery.size() <= 0:
		return "Nothing is built yet."
	var motions: Motions = player.motions()
	var lines := PackedStringArray()
	if motions.is_empty():
		lines.append("The model has no motions of its own yet.")
	else:
		lines.append("The model's motions, kept in its file (places from where it was built):")
		for motion: Motions.Motion in motions.list:
			lines.append_array(_motion_words(player, motion, true))
	if bool(input.get("suggest", true)):
		var offered: Array = player.suggest().filter(func(one: Motions.Motion) -> bool:
			return motions.named(one.name) == null)
		if not offered.is_empty():
			lines.append(("Suggested from what moves, each tried for room (define_motion {\"name\": "
				+ "\"%s\", \"suggested\": true} keeps one):") % (offered[0] as Motions.Motion).name)
			for motion: Motions.Motion in offered:
				lines.append_array(_motion_words(player, motion, false))
		elif motions.is_empty():
			lines.append("Nothing in it moves as a link's card names things (doors, steering, a boom, "
				+ "a turntable, gears, a rack): move_part with no part= lists every joint, and "
				+ "define_motion makes a motion of any of them.")
	lines.append("play_motion {\"name\": …} plays one (reverse=true backwards); render_motion renders "
		+ "it. Nothing was changed.")
	return "\n".join(lines)


## A motion in lines: its name and length, each joint's keys and where it
## stands now, its driver, and with [param kept] what it last did.
func _motion_words(player: MotionPlayer, motion: Motions.Motion, kept: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if motion.is_sequence():
		var motions: Motions = player.motions()
		out.append("  \"%s\", %s s, a sequence: %s, each from where the one before left the model." % [
			motion.name, Motions.num(motions.seconds_of(motion), 2), ", then ".join(Array(motion.sequence).map(
			func(one: String) -> String: return Motions.quoted(one)))])
		var missing: Array = []
		motions.played_by(motion, false, missing)
		for words: String in missing:
			out.append("    %s: it is passed over until there is one." % words)
		if kept:
			var last: String = str(player.results.get(motion.name.to_lower(), ""))
			out.append("    Last played: %s." % last if not last.is_empty()
				else "    Not played since the model was opened.")
		return out
	out.append("  \"%s\", %s s%s:" % [motion.name, Motions.num(motion.length(), 2),
		(", after \"%s\"" % motion.after) if not motion.after.is_empty() else ""])
	for track: Motions.Track in motion.tracks:
		if player.parts_of(track.joint).is_empty():
			out.append("    %s: %s." % [motion.name, player.gone_words(track.joint)])
			continue
		var keys := PackedStringArray()
		for key: Array in track.keys:
			keys.append("%s s %s%s" % [Motions.num(float(key[0]), 2), _place(float(key[1]), track.joint),
				"" if str(key[2]) == "EASE" else " " + str(key[2]).to_lower()])
		out.append("    %s %s: %s; it stands at %s now." % [player.joint_words(track.joint),
			"slid" if track.joint.mode == "slide" else "turned", ", ".join(keys),
			_place(player.at_now(track.joint), track.joint)])
	if motion.driver != null:
		if player.parts_of(motion.driver).is_empty():
			out.append("    %s: %s." % [motion.name, player.gone_words(motion.driver)])
		else:
			out.append("    %s turned %s time%s in %s s, from where it stands, with what it drives."
				% [player.joint_words(motion.driver), Motions.num(motion.turns, 2),
				"" if is_equal_approx(absf(motion.turns), 1.0) else "s", Motions.num(motion.driver_seconds, 2)])
	if kept:
		var last: String = str(player.results.get(motion.name.to_lower(), ""))
		out.append("    Last played: %s." % last if not last.is_empty()
			else "    Not played since the model was opened.")
	return out


static func _place(value: float, joint: Motions.Joint) -> String:
	return "%s studs" % Balance.studs(value) if joint.mode == "slide" else "%d°" % roundi(value)


## define_motion: a motion kept in the model, one undo step, played once to
## check with the model put back.
func _define_motion(input: Dictionary) -> String:
	var player: MotionPlayer = app.get("_motions")
	var builder: Builder = app.get("_builder")
	if player == null:
		return "This app has no motions."
	var name: String = str(input.get("name", "")).strip_edges().replace('"', "'")
	if name.is_empty():
		return "Give name= what a builder would call it: \"Open the doors\"."
	var motions: Motions = player.motions()
	if bool(input.get("remove", false)):
		if motions.named(name) == null:
			return "No motion %s to take out: %s." % [Motions.quoted(name), _motion_names(motions)]
		var had: Motions = motions.copy()
		motions.remove(name)
		builder.record([{"undo": "motions", "motions": had}], "took the motion %s out" % Motions.quoted(name))
		return "Took %s out of the model. One step: undo puts it back." % Motions.quoted(name)
	var motion: Motions.Motion = null
	if bool(input.get("suggested", false)):
		var offered: Array = player.suggest()
		for one: Motions.Motion in offered:
			if one.name.to_lower() == name.to_lower():
				motion = one
		if motion == null:
			var names := PackedStringArray()
			for one: Motions.Motion in offered:
				names.append(Motions.quoted(one.name))
			return "No suggestion called %s: %s." % [Motions.quoted(name), "list_motions suggests "
				+ ", ".join(names) if not names.is_empty() else "nothing here is suggested"]
	elif input.get("sequence") is Array:
		if input.has("tracks") or input.has("driver"):
			return ("A motion is its own tracks or driver, or a sequence of the model's motions: not both. "
				+ "Nothing was kept.")
		var made: Variant = _sequence_from(motions, name, input["sequence"])
		if made is String:
			return "%s Nothing was kept." % made
		return await _define_sequence(player, made)
	else:
		var made: Variant = _motion_from(player, name, input)
		if made is String:
			return "%s Nothing was kept." % made
		motion = made
	# AFTER is a file's (a sequence names an order now): kept as given.
	motion.after = str(input.get("after", motion.after)).strip_edges().replace('"', "'")
	if motion.after.to_lower() == name.to_lower():
		return "A motion cannot follow itself. Nothing was kept."
	if not motion.after.is_empty() and motions.named(motion.after) == null:
		return "No motion %s for it to follow: %s. Nothing was kept." % [Motions.quoted(motion.after),
			_motion_names(motions)]
	var replaced: bool = motions.named(name) != null
	var had: Motions = motions.copy()
	motions.put(motion)
	builder.record([{"undo": "motions", "motions": had}], "%s the motion %s" % [
		"changed" if replaced else "made", Motions.quoted(name)])
	# Checked where it begins in its sequence: after the motions it follows,
	# each kept, then all of it undone. Played alone, the observatory's
	# "Extend the telescope" stopped on the shut dome that "Open the dome
	# panel", which it follows, opens first.
	var verbs: EditVerbs = app.get("_verbs")
	var depth: int = builder.history_depth()
	var first := PackedStringArray()
	for one: Motions.Motion in motions.sequence(name):
		if one.name.to_lower() == name.to_lower():
			break
		player.play(one, false, MotionPlayer.PLAY_FPS, true)
		first.append(Motions.quoted(one.name))
	var played: MotionPlayer.Played = player.play(motion)
	while builder.history_depth() > depth:
		await verbs.press("undo")
	var joints: int = motion.joints().size()
	return ("%s %s in the model (%s s, %d joint%s): it is saved with it. Played once to check%s, and the "
		+ "model put back: %s. play_motion plays it%s; one step: undo takes it out.") % [
		"Changed" if replaced else "Kept", Motions.quoted(name), Motions.num(motion.length(), 2), joints,
		"" if joints == 1 else "s", (" after %s, which it follows" % ", then ".join(first))
		if not first.is_empty() else "", player.said(played), (" alone, from where the model stands, and "
		+ "with sequence=true after %s" % ", then ".join(first)) if not first.is_empty() else ""]


## A sequence called [param name] of the model's motions named in [param
## names], in order, or why not: each must be one of the model's, and none
## may play it inside itself.
func _sequence_from(motions: Motions, name: String, names: Array) -> Variant:
	var motion := Motions.Motion.new()
	motion.name = name
	for raw: Variant in names:
		if str(raw).strip_edges().to_lower() == name.to_lower():
			return "A sequence cannot play itself."
		var one: Motions.Motion = motions.named(str(raw))
		if one == null:
			return "No motion %s to play in it: %s." % [Motions.quoted(str(raw)), _motion_names(motions)]
		motion.sequence.append(one.name)
	if motion.sequence.is_empty():
		return "Give sequence= the model's motions it plays, in order: %s." % _motion_names(motions)
	var tried: Motions = motions.copy()
	tried.put(motion)
	var missing: Array = []
	tried.played_by(tried.named(name), false, missing)
	if not missing.is_empty():
		return "%s." % "; ".join(missing)
	return motion


## define_motion's sequence kept, one step, and played once to check, each
## motion from where the one before left the model, then put back.
func _define_sequence(player: MotionPlayer, motion: Motions.Motion) -> String:
	var builder: Builder = app.get("_builder")
	var motions: Motions = player.motions()
	var replaced: bool = motions.named(motion.name) != null
	var had: Motions = motions.copy()
	motions.put(motion)
	builder.record([{"undo": "motions", "motions": had}], "%s the sequence %s" % [
		"changed" if replaced else "made", Motions.quoted(motion.name)])
	var drawn: MotionRender = MotionRender.frames_of(player, [motion], false, MotionPlayer.PLAY_FPS)
	player.results[motion.name.to_lower()] = " ".join(drawn.lines)
	return ("%s %s in the model, a sequence of %d (%s s): %s, each from where the one before left the "
		+ "model. It is saved with it. Played once to check, and the model put back: %s play_motion plays "
		+ "it (reverse=true backwards, in reverse order), render_motion renders it whole; one step: undo "
		+ "takes it out.") % ["Changed" if replaced else "Kept", Motions.quoted(motion.name),
		motion.sequence.size(), Motions.num(motions.seconds_of(motion), 2), ", then ".join(Array(motion.sequence).map(
		func(one: String) -> String: return Motions.quoted(one))), " ".join(drawn.lines)]


## A motion from define_motion's tracks= and driver=, or why not.
func _motion_from(player: MotionPlayer, name: String, input: Dictionary) -> Variant:
	var motion := Motions.Motion.new()
	motion.name = name
	var seen: Array = []
	for raw: Variant in input.get("tracks", []):
		if not (raw is Dictionary) or not (raw as Dictionary).has("joint"):
			return "Each track is {\"joint\": \"#80\", \"keys\": [{\"t\": 0, \"place\": 0}, ...]}."
		var given: Dictionary = raw
		var joint: Variant = player.joint_named(str(given["joint"]), bool(given.get("slide", false)))
		if joint is String:
			return "%s" % joint
		if seen.has(joint):
			return "%s is in two tracks: give one its keys." % str(given["joint"])
		seen.append(joint)
		var track := Motions.Track.new()
		track.joint = joint
		for key: Variant in given.get("keys", []):
			if not (key is Dictionary) or not (key as Dictionary).has("t") or not (key as Dictionary).has("place"):
				return "Each key is {\"t\": seconds, \"place\": degrees from where it was built, \"how\": \"ease\"}."
			var t: float = float(key["t"])
			if t < 0.0 or t > Motions.MOST_SECONDS:
				return "A key's t is seconds from the start, 0 to %d: %s is not." % [int(Motions.MOST_SECONDS),
					str(key["t"])]
			var how: String = str((key as Dictionary).get("how", "ease")).to_upper()
			if not how in Motions.HOWS:
				return "how= is ease, linear or hold: %s is not." % str(key["how"])
			track.add_key(t, float(key["place"]), how)
		if track.keys.is_empty():
			return "%s has no keys: give keys= [{\"t\": 0, \"place\": 0}, {\"t\": 2, \"place\": 90}]." \
				% str(given["joint"])
		motion.tracks.append(track)
	if input.get("driver") is Dictionary:
		var driver: Dictionary = input["driver"]
		var joint: Variant = player.joint_named(str(driver.get("joint", "")))
		if joint is String:
			return "%s" % joint
		if is_zero_approx(float(driver.get("turns", 0.0))):
			return "driver= turns= how many times to turn it, not 0."
		motion.driver = joint
		motion.turns = clampf(float(driver["turns"]), -100.0, 100.0)
		motion.driver_seconds = clampf(float(driver.get("seconds", 4.0)), 0.1, Motions.MOST_SECONDS)
	if motion.tracks.is_empty() and motion.driver == null:
		return ("Give tracks= (each a joint and its keys) or driver= (a joint and how many times to "
			+ "turn it); list_motions suggests some.")
	return motion


static func _motion_names(motions: Motions) -> String:
	if motions.is_empty():
		return "the model has none yet (list_motions suggests some)"
	var names := PackedStringArray()
	for motion: Motions.Motion in motions.list:
		names.append(Motions.quoted(motion.name))
	return "the model has " + ", ".join(names)


## What play_motion and render_motion name: one motion, a sequence's
## motions, or with sequence=true the chain a file's AFTER lines put it in,
## in order (reversed, backwards). {"order": each motion of its own, in
## play order, "title": what it is called, "missing": a sequence's motions
## that are not the model's, said}; or a String saying why not.
func _motions_asked(input: Dictionary) -> Variant:
	var player: MotionPlayer = app.get("_motions")
	if player == null:
		return "This app has no motions."
	var motions: Motions = player.motions()
	var name: String = str(input.get("name", "")).strip_edges()
	if motions.named(name) == null:
		return "No motion %s: %s." % [Motions.quoted(name), _motion_names(motions)]
	var reverse: bool = bool(input.get("reverse", false))
	var chain: Array = motions.sequence(name) if bool(input.get("sequence", false)) else [motions.named(name)]
	if reverse:
		chain.reverse()
	var missing: Array = []
	var order: Array = motions.flat(chain, reverse, missing)
	if order.is_empty():
		return "%s plays nothing: %s." % [Motions.quoted(motions.named(name).name), "; ".join(missing)]
	return {"order": order, "missing": missing, "sequence": (chain[0] as Motions.Motion)
		if chain.size() == 1 and (chain[0] as Motions.Motion).is_sequence() else null,
		"title": ", ".join(chain.map(func(one: Motions.Motion) -> String: return one.name))}


## play_motion: played and kept where it ends, one undo step, said with a
## picture of its frames from the view that sees most of what it moves.
func _play_motion(input: Dictionary) -> Variant:
	var asked: Variant = _motions_asked(input)
	if asked is String:
		return asked
	var player: MotionPlayer = app.get("_motions")
	var builder: Builder = app.get("_builder")
	var panel: PosePanel = app.get("_pose")
	var reverse: bool = bool(input.get("reverse", false))
	var order: Array = asked["order"]
	var depth: int = builder.history_depth()
	var lines := PackedStringArray()
	var sequence: Motions.Motion = asked["sequence"]
	if sequence != null:
		lines.append("%s plays %d motion%s%s, each from where the one before left the model:" % [
			Motions.quoted(sequence.name), order.size(), "" if order.size() == 1 else "s",
			", in reverse order and each backwards" if reverse else ""])
	for words: String in asked["missing"]:
		lines.append("%s: passed over." % words)
	var run: MotionPlayer.Run = player.play_in_order(order, reverse, "played %s%s" % [
		Motions.quoted(str(asked["title"])), " backwards" if reverse else ""])
	var picks: Array = []   ## [which motion, its frame, at what time]
	var elapsed: float = 0.0
	for k: int in run.played.size():
		var motion: Motions.Motion = order[k]
		var played: MotionPlayer.Played = run.played[k]
		lines.append("Played %s%s (%s s): %s." % [Motions.quoted(motion.name), " backwards" if reverse
			else "", Motions.num(played.seconds, 2), player.said(played)])
		if not played.frames.is_empty():
			var sheet: Array = _sheet_of(played, order.size())
			# Where a sequence begins, then each motion's end: a motion's
			# first frame is the one before's last.
			if picks.is_empty() and not sheet.has(0):
				sheet.push_front(0)
			for n: int in sheet:
				if n > 0 or picks.is_empty():
					picks.append([k, n, elapsed + float(n) / float(played.fps)])
		elapsed += played.seconds
	if sequence != null:
		player.results[sequence.name.to_lower()] = " ".join(lines.slice(1))
	var whole: Array = MotionRender.whole_frames(run.each)
	var stills: Array = picks.map(func(pick: Array) -> Dictionary: return whole[pick[0]][pick[1]])
	var times: Array = picks.map(func(pick: Array) -> float: return pick[2])
	if builder.history_depth() == depth:
		lines.append("It ends where it began: the model stands as it was." if run.went() else "Nothing moved.")
	else:
		if not run.standing().is_empty():
			lines.append("Now: %s." % run.standing())
		lines.append("One step: undo takes it back%s." % ("" if reverse else
			"; play_motion reverse=true plays it back"))
	var text: String = "\n".join(lines)
	if stills.is_empty() or panel == null or not StudioRender.possible():
		return text
	var view: String = str(input.get("view", ""))
	var why: String = ""
	if not view in MOTION_VIEWS:
		var seen: Dictionary = MotionRender.seen_from(app.get("_world"), app.get("_library"),
			builder.lattice, run.frames)
		view = MotionRender.best_view(seen)
		why = _seen_words(view, seen)
	var images: Array = await panel.draw_stills(stills, Vector2i(480, 300), view)
	if images.is_empty():
		return text
	text += "\nThe picture: its frames at %s, left to right and down, from %s%s." % [_times_words(times),
		_view_words(view), why]
	return [{"type": "text", "text": text}, _picture_block(PosePanel.sheet_of(images))]


## Where a picture's camera stood, as play_motion says it: "the back
## corner (view=\"back\")".
const VIEW_WORDS: Dictionary = {"hero": "the front corner", "front": "the front", "side": "the side",
	"back": "the back corner", "low": "low down at the front corner", "top": "above"}


static func _view_words(view: String) -> String:
	return "%s (view=\"%s\")" % [VIEW_WORDS.get(view, view), view]


## Why [param view] was chosen, from what each view sees (seen_from):
## ", which sees 82% of what it moves (the front corner 31%)".
static func _seen_words(view: String, seen: Dictionary) -> String:
	if seen.is_empty() or float(seen.get(view, 0.0)) <= 0.0:
		return ""
	var words: String = ", which sees %d%% of what it moves" % roundi(float(seen[view]) * 100.0)
	if view != "hero":
		words += " (the front corner %d%%)" % roundi(float(seen.get("hero", 0.0)) * 100.0)
	return words


## Which of [param played]'s frames a picture shows: at its keys when it has
## two to four, else four spread out; with [param of] motions, its start and
## end.
static func _sheet_of(played: MotionPlayer.Played, of: int = 1) -> Array:
	var last: int = played.frames.size() - 1
	if of > 1:
		return [0, last] if of <= 2 else [last]
	var out: Array = []
	if played.key_times.size() >= 2 and played.key_times.size() <= PosePanel.SHEET_MOST:
		for t: float in played.key_times:
			var n: int = clampi(roundi(t * played.fps), 0, last)
			if not out.has(n):
				out.append(n)
	else:
		for k: int in PosePanel.SHEET_MOST:
			var n: int = roundi(float(k) * float(last) / float(PosePanel.SHEET_MOST - 1))
			if not out.has(n):
				out.append(n)
	return out


## render_motion: the motion's frames drawn and kept as an animation,
## framed on what it moves, as File, Render's Animation draws it
## (MotionRender); the model as it was after.
func _render_motion(input: Dictionary, work: Working.Job = null) -> Variant:
	var asked: Variant = _motions_asked(input)
	if asked is String:
		return asked
	var order: Array = asked["order"]
	if not StudioRender.possible():
		return ("Rendering needs something to draw with, and this app is running without a window: "
			+ "play_motion plays it.")
	var player: MotionPlayer = app.get("_motions")
	var panel: PosePanel = app.get("_pose")
	var reverse: bool = bool(input.get("reverse", false))
	var fps: int = 24 if int(input.get("fps", 12)) == 24 else 12
	var drawn: MotionRender = MotionRender.frames_of(player, order, reverse, fps)
	var poses: Array = drawn.poses
	var lines: PackedStringArray = drawn.lines
	for words: String in asked["missing"]:
		lines.append("%s: passed over." % words)
	if poses.is_empty():
		return "Nothing to draw: %s" % "; ".join(lines)
	var settings: RenderSettings = panel.settings
	var size_was: Vector2i = settings.size
	settings.size = Vector2i(1280, 720) if str(input.get("size", "")) == "720p" else Vector2i(480, 300)
	var sheet_at: Array = []
	for k: int in PosePanel.SHEET_MOST:
		sheet_at.append(roundi(float(k) * float(poses.size() - 1) / float(PosePanel.SHEET_MOST - 1)))
	var title: String = str(asked["title"]) + (" backwards" if reverse else "")
	var view: String = str(input.get("view", "hero"))
	if not view in MOTION_VIEWS:
		view = "hero"
	var frames: int = await panel.render_poses(poses, fps, func(_n: int) -> float: return 0.0,
		sheet_at, work, view, title, true)
	settings.size = size_was
	if frames <= 0 or not panel._last.has("kept"):
		return "Nothing rendered: %s" % panel.rendered_words()
	lines.insert(0, "Rendered %d frames, %d a second (%s s), drawn in %d s: %s." % [frames, fps,
		Motions.num(float(frames - 1) / float(fps), 2), int(panel._last["seconds"]), str(panel._last["kept"])])
	var hidden: String = _hidden_from(view, order,
		drawn.played.map(func(one: MotionPlayer.Played) -> Array: return one.frames))
	if not hidden.is_empty():
		lines.append(hidden)
	var times: Array = []
	var picture: Image = panel.sheet(times)
	if picture == null:
		return "\n".join(lines)
	lines.append("The picture: its frames at %s, left to right and down." % _times_words(times))
	return [{"type": "text", "text": "\n".join(lines)}, _picture_block(picture)]


## Where render_motion's camera may stand (StudioRender.VIEWS).
const MOTION_VIEWS: Array = ["hero", "front", "side", "back", "low", "top"]


## Which of the motions [param asked] move parts on the far side of the
## model from [param view], said with the view that faces them; empty when
## none does. Rendered from the front corner, a session's observatory hid
## the back wall's panels it opened behind the dome.
func _hidden_from(view: String, asked: Variant, each: Array) -> String:
	var world: BrickWorld = app.get("_world")
	var toward: Vector3 = Vector3(StudioRender.VIEWS[view][1])
	toward.y = 0.0
	if world == null or toward.length() < 0.1:
		return ""
	var centre := Vector3.ZERO
	var count: int = 0
	var top: float = -INF
	var bottom: float = INF
	for brick: BrickWorld.Brick in world.bricks():
		centre += brick.transform.origin
		count += 1
		top = maxf(top, brick.transform.origin.y)
		bottom = minf(bottom, brick.transform.origin.y)
	if count == 0:
		return ""
	centre /= float(count)
	var far := PackedStringArray()
	var faces: String = ""
	for k: int in (asked as Array).size():
		var frames: Array = each[k]
		if frames.is_empty() or (frames[0] as Dictionary).is_empty():
			continue
		var at := Vector3.ZERO
		for key: Variant in frames[0]:
			at += (frames[0][key] as Transform3D).origin
		at = at / float((frames[0] as Dictionary).size()) - centre
		# Behind the model and low down: a dome's panel high at the back
		# swings up in sight, the back wall's doors under it do not.
		var low: bool = at.y + centre.y < lerpf(bottom, top, 0.6)
		at.y = 0.0
		if at.length() < BrickLattice.STUD * 2.0 or not low or at.normalized().dot(toward.normalized()) > -0.3:
			continue
		far.append(Motions.quoted((asked[k] as Motions.Motion).name))
		var best: float = -INF
		for other: String in MOTION_VIEWS:
			var way: Vector3 = Vector3(StudioRender.VIEWS[other][1])
			way.y = 0.0
			if way.length() > 0.1 and way.normalized().dot(at.normalized()) > best:
				best = way.normalized().dot(at.normalized())
				faces = other
	if far.is_empty():
		return ""
	return ("%s move%s parts on the far side of the model from this view, hardly seen: "
		+ "render_motion view=\"%s\" faces them.") % [", ".join(far), "s" if far.size() == 1 else "",
		faces]


# -- simulating -------------------------------------------------------------------


## Tools, Simulate mechanism's own reading, driving and weighing
## (SimulatePanel.for_session), said for a session.
## [param work] is the job a recording reports to (ToolJobs.long_call).
func _simulate(input: Dictionary, work: Working.Job = null) -> Variant:
	var panel: SimulatePanel = app.get("_simulate")
	if panel == null:
		return "This app has no Simulate mechanism."
	return await panel.for_session(input, work)


# -- undo -------------------------------------------------------------------------


func _undo(input: Dictionary) -> String:
	var builder: Builder = app.get("_builder")
	var verbs: EditVerbs = app.get("_verbs")
	var again: bool = bool(input.get("redo", false))
	var count: int = clampi(int(input.get("steps", 1)), 1, 25)
	var done := PackedStringArray()
	var others: String = ""
	for _n: int in count:
		var words: String = builder.redo_words() if again else (
			builder.history_words(1)[0] if builder.history_depth() > 0 else "")
		if words.is_empty():
			break
		# Another Claude chat's change, in a tab two chats work in: not this
		# chat's to take back (CommandSocket.CHAT_KEY).
		var by: String = str(builder.last_step().get("by", "")) if not again else ""
		if not chat.is_empty() and not by.is_empty() and by != chat:
			others = words
			break
		await verbs.press("redo" if again else "undo")
		done.append(words)
	if not others.is_empty():
		# A resumed chat is a new one to the relay (api/mcp.js, "Two chats, two
		# tabs"): nothing Claude Code sends says it is the same chat.
		return ("%sThe next change back, %s, was made by another Claude chat working in this "
			+ "tab, so it was left. Ask the person before changing that chat's work. If it was "
			+ "this chat's own, from before the chat was resumed, Brickworks counts it as another "
			+ "chat's: the person can take it back with Undo in the tab.") % [
				"Undid %s. " % "; ".join(done) if not done.is_empty() else "Nothing was undone. ", others]
	if done.is_empty():
		return "Nothing to %s." % ("redo" if again else "undo")
	var left: String = ("Next to undo: %s." % builder.history_words(1)[0]) \
		if builder.history_depth() > 0 else "Nothing more to undo."
	if builder._redo.size() > 0:
		left += " undo {\"redo\": true} puts back %s." % builder.redo_words()
	return "%s %s. %s" % ["Redid" if again else "Undid", "; ".join(done), left]


# -- opening -----------------------------------------------------------------------


func _open(input: Dictionary) -> String:
	var store: ModelStore = app.get("_store")
	var bar: ModelBar = app.get("_bar")
	var saved: Array[ModelStore.Entry] = store.list_saved()
	var examples: Array[ModelStore.Entry] = store.list_examples()
	var name: String = str(input.get("name", "")).strip_edges().trim_suffix(".ldr")
	if not str(input.get("link", "")).strip_edges().is_empty():
		return await _open_link(str(input["link"]).strip_edges(), bool(input.get("discard_changes", false)))
	if not str(input.get("library", "")).strip_edges().is_empty():
		return await _open_library(str(input["library"]).strip_edges(),
			bool(input.get("discard_changes", false)))
	if name.is_empty():
		var said := PackedStringArray()
		said.append("Open now: %s." % store.title)
		for list: Array in [["Saved", saved], ["Examples", examples]]:
			var rows := PackedStringArray()
			for entry: ModelStore.Entry in list[1]:
				var saves: int = 0 if entry.example else ModelVersions.of(
					entry.path.get_file().get_basename()).size()
				rows.append("%s (%d parts%s)" % [entry.name, entry.bricks,
					", %d versions" % saves if saves > 1 else ""])
			said.append("%s: %s." % [list[0], ", ".join(rows) if not rows.is_empty() else "none"])
		# Where the browser may clear them, the person should hear it.
		if StorageKeep.at_risk():
			said.append(StorageKeep.words())
		return "\n".join(said)
	var chosen: ModelStore.Entry = null
	for entry: ModelStore.Entry in saved + examples:
		# An example also by its file's name, as tools and probes ask for it.
		if chosen == null and (entry.name.to_lower() == name.to_lower()
				or entry.example and entry.path.get_file().get_basename() == name.to_lower()):
			chosen = entry
	if chosen == null:
		return "No model called %s. open_model with no name lists them." % name
	var kept: Array[ModelVersions.Version] = [] as Array[ModelVersions.Version] \
		if chosen.example else ModelVersions.of(chosen.path.get_file().get_basename())
	if bool(input.get("versions", false)):
		if kept.is_empty():
			return "No saves of %s are kept as versions yet: each save from now on is." % chosen.name
		var rows := PackedStringArray(["%s's saves, newest first (version=N opens one):"
			% chosen.name])
		for n: int in kept.size():
			rows.append("%d. %s" % [n + 1, kept[n].describe()])
		return "\n".join(rows)
	var version: int = int(input.get("version", 0))
	if input.has("version") and (version < 1 or version > kept.size()):
		return ("%s has %d versions: version is 1 (the newest) to %d. versions=true lists them."
			% [chosen.name, kept.size(), kept.size()]) if not kept.is_empty() \
			else "No saves of %s are kept as versions yet." % chosen.name
	if store.has_unsaved_work() and not bool(input.get("discard_changes", false)):
		return ("The model on the baseplate, %s, has changes that are not saved, and opening "
			% store.title + "cannot be undone. save_model first, or give discard_changes=true.")
	if assistant != null:
		assistant.forget_built()
	if version >= 1:
		var landed: int = await bar.open_version(kept[version - 1], chosen.name)
		if landed <= 0 and store.awaited.is_empty():
			return "Could not read that version of %s." % chosen.name
		return ("Opened %s as saved %s: %d parts. look_at_model to see it. The person's Save "
			+ "makes it the newest save.") % [chosen.name, kept[version - 1].when(), landed] + _opened_motions()
	var placed: int = await bar.open_with_progress(chosen.path)
	bar.opened.emit(placed)
	return "Opened %s: %d parts. look_at_model to see it." % [chosen.name, placed] + _opened_motions()


## What a model just opened can play, by name, for play_motion: its own
## motions as its file has them (GalleryTool.motions_words); "" for none.
func _opened_motions() -> String:
	var world: BrickWorld = app.get("_world")
	var said: String = GalleryTool.motions_words(world.motions if world != null else null)
	return "" if said.is_empty() else (" %s play_motion name= plays one; list_motions says what "
		+ "each moves.") % said


## open_model link=: a gallery model copied into the person's own models and
## opened, as Open in Brickworks on its page does (/app?copy=<id>, main's
## _maybe_copy): saved under a name of its own, never over one of theirs,
## knowing which link it came from, so a share of it says it was remixed.
## Asked to open the most built small model, a session could only read it
## (gallery open=) and send the person to its page (mcpwalk2, t1).
func _open_link(link: String, discard: bool) -> String:
	var id: String = link
	if link.contains("/m/"):
		id = link.get_slice("/m/", 1).get_slice("/", 0).get_slice("?", 0).get_slice(".", 0)
	if not SharedModels.is_id(id):
		return ("link is a gallery model's link id, ten letters and digits (gallery lists them), "
			+ "or its address, https://brickworks.diy/m/<id>.")
	var store: ModelStore = app.get("_store")
	var bar: ModelBar = app.get("_bar")
	var shared: SharedModels = app.get("_shared")
	if shared == null:
		return "This app cannot reach the gallery."
	if store.has_unsaved_work() and not discard:
		return ("The model on the baseplate, %s, has changes that are not saved, and opening "
			% store.title + "cannot be undone. save_model first, or give discard_changes=true.")
	var answer: Dictionary = await shared.fetch(id)
	if int(answer["code"]) != 200 or not answer["body"] is Dictionary:
		return "Could not open %s: %s." % [id, SharedModels.trouble(answer, "the gallery did not answer")]
	var body: Dictionary = answer["body"]
	var name: String = str(body.get("name", "Shared model"))
	if assistant != null:
		assistant.forget_built()
	var result: Dictionary = await store.open_text_fetched(str(body.get("model", "")), name)
	if not str(result["error"]).is_empty():
		return "Could not open %s: %s." % [name, result["error"]]
	store.share_id = ""
	store.remixed_from = id
	store.remixed_from_version = maxi(int(body.get("version", 0)), 0)
	store.credit = SharedModels.credit_of(body, id)
	bar.opened.emit(int(result["placed"]))
	var since: int = Time.get_ticks_msec()
	while not store.awaited.is_empty() and Time.get_ticks_msec() - since < 120000:
		await app.get_tree().create_timer(0.3).timeout
	if not store.awaited.is_empty():
		return ("%s is open, but %d of its parts did not arrive, so it is not saved yet: "
			+ "save_model once they have.") % [name, store.awaited.size()]
	var kept: String = store.unused_name(name)
	store.save_as(kept)
	var author: String = str(body["author"]) if body.get("author") is String else ""
	var licence: Variant = body.get("licence")
	var url: String = str(body.get("url", SharedModels.link_for(id)))
	var terms: String = ("%s: %s" % [GalleryTool.LICENCES[licence][0], GalleryTool.LICENCES[licence][1]
		% [author if not author.is_empty() else "its builder", url]]) \
		if licence is String and GalleryTool.LICENCES.has(licence) \
		else "none chosen: the person may build it; do not share what is made from it as theirs"
	return ("Opened a copy of %s (%s)%s: %d parts, saved in the person's models as %s, theirs to "
		+ "change; the shared one stays as it was, and sharing this one says it was remixed from "
		+ "it. Licence %s. look_at_model to see it.") % [name, url,
		", by %s" % author if not author.is_empty() else "",
		(app.get("_world") as BrickWorld).brick_count() - store.scenery.size(), kept, terms] + _opened_motions()


## open_model library=: LDraw's model of a real set, from the library File,
## Library… shows (ModelLibrary), opened in place of what is on the baseplate
## as open_model name= opens one, credited to whoever made it
## (ModelStore.credit). Not saved: it is the person's to save, as a set
## opened from the window is.
func _open_library(id: String, discard: bool) -> String:
	var store: ModelStore = app.get("_store")
	var bar: ModelBar = app.get("_bar")
	var books: ModelLibrary = app.get("_model_library")
	if books == null:
		return "This app has no library."
	if not ModelLibrary.is_id(id):
		return "library is an id from gallery library=true, like omr-10179-1."
	if store.has_unsaved_work() and not discard:
		return ("The model on the baseplate, %s, has changes that are not saved, and opening "
			% store.title + "cannot be undone. save_model first, or give discard_changes=true.")
	var entry: Dictionary = await books.find(id)
	if entry.is_empty():
		return books.trouble + " gallery library=true q= finds a set."
	var title: String = ModelLibrary.title_of(entry)
	var got: Dictionary = await books.model_text(entry)
	if not str(got["error"]).is_empty():
		return "Could not open %s: %s" % [title, got["error"]]
	if assistant != null:
		assistant.forget_built()
	var result: Dictionary = await bar.open_text_with_progress(str(got["text"]), title)
	var placed: int = int(result["placed"])
	if placed <= 0 and store.awaited.is_empty():
		return "Could not read %s." % title
	store.credit = ModelLibrary.credit_of(entry)
	store.touch()
	bar.opened.emit(placed)
	var since: int = Time.get_ticks_msec()
	while not store.awaited.is_empty() and Time.get_ticks_msec() - since < 120000:
		await app.get_tree().create_timer(0.3).timeout
	return ("Opened %s: %d parts%s, %s (%s). It is LDraw's model of the real set: credit %s and keep "
		+ "to its licence in anything made from it. Not saved: save_model keeps it in the person's "
		+ "models. look_at_model to see it.") % [title,
		(app.get("_world") as BrickWorld).brick_count() - store.scenery.size(),
		ModelBar.left_out_words(result, false), ModelBar.credit_words(store.credit), entry["page"],
		str(entry["author"]) if not str(entry["author"]).is_empty() else "its maker"] + _opened_motions()


# -- the parts list and the collection ------------------------------------------------


func _parts_list(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var which: String = str(input.get("which", "model"))
	var limit: int = clampi(int(input.get("limit", 60)), 1, 500)
	var stock: Inventory = Inventory.of(world, library, store.scenery)
	if which == "model":
		if stock.lots.is_empty():
			return "Nothing is built yet."
		var said := PackedStringArray()
		said.append("%d pieces in %d lots, %s." % [stock.pieces, stock.lots.size(), stock.weight()])
		for lot: Inventory.Lot in stock.lots.slice(0, limit):
			said.append("  %3d x %s %s, %s%s" % [lot.count, lot.part_id, lot.name, lot.color_name,
				" (element %s)" % lot.element if not lot.element.is_empty() else ""])
		if stock.lots.size() > limit:
			said.append("  and %d more lots: limit= for more." % (stock.lots.size() - limit))
		return "\n".join(said)
	if not which in ["need", "buildable"]:
		return "which is model, need or buildable."
	var shell: Shell = app.get("_shell")
	var mine: CollectionStore = shell.collection.store if shell.collection != null else null
	if mine == null:
		return "This app has no collection."
	if mine.on_hand.is_empty() and not mine.collection.is_empty():
		await mine.refresh_pool()
	if mine.on_hand.is_empty():
		return ("The person's collection is empty: they add their sets and parts in Build, "
			+ "My collection.")
	if which == "need":
		if stock.lots.is_empty():
			return "Nothing is built yet."
		var needs: Dictionary = Collection.needs_of(stock, library)
		var cover: Dictionary = Collection.coverage(needs, mine.on_hand)
		var rows: Array = Collection.plan(needs, mine.on_hand, library)
		var said := PackedStringArray()
		var pieces: int = int(cover["pieces"])
		var owned: int = int(cover["owned"])
		var shaped: int = roundi(float(cover["any_colour"]) * pieces)
		said.append("Of %d pieces, they own %d in the right colour%s." % [pieces, owned,
			" and %d more in another colour" % (shaped - owned) if shaped > owned else ""])
		var short: int = 0
		for row: Dictionary in rows:
			if int(row["short"]) <= 0:
				continue
			short += 1
			if short <= limit:
				said.append("  short %d of %d x %s in colour %d" % [int(row["short"]), int(row["need"]),
					str(row["part"]), int(row["colour"])])
		said.append("Short of %d lots." % short if short > 0 else "They own every piece.")
		return "\n".join(said)
	# What can I build? as the window ranks it (CollectionDialog._fill_build):
	# the person's saved models, the examples and the official LDraw models
	# of real sets, most of it owned first. Measured against the saved ones
	# alone, a session told a person with two sets that nothing they had
	# could be built (bench/results/mcpwalk2-2026-10-19, t4).
	var found: Array = []   ## [name, what it is, coverage]
	for entry: ModelStore.Entry in store.list_saved() + store.list_examples():
		found.append([entry.name, "an example" if entry.example else "saved",
			Collection.needs_of_ldraw(FileAccess.get_file_as_string(entry.path), library)])
	for model: Dictionary in await mine.inventories.official_models():
		found.append([str(model["name"]), "the official model of set %s%s" % [model["set"],
			", " + CollectionDialog.OMR_PAGE + str(model["page"]) if not str(model["page"]).is_empty() else ""],
			model["needs"]])
	var ranked: Array = []
	for one: Array in found:
		if not (one[2] as Dictionary).is_empty():
			ranked.append([one[0], one[1], Collection.coverage(one[2], mine.on_hand)])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		var x: Dictionary = a[2]
		var y: Dictionary = b[2]
		if not is_equal_approx(float(x["exact"]), float(y["exact"])):
			return float(x["exact"]) > float(y["exact"])
		if not is_equal_approx(float(x["any_colour"]), float(y["any_colour"])):
			return float(x["any_colour"]) > float(y["any_colour"])
		return int(x["pieces"]) < int(y["pieces"]))
	if ranked.is_empty():
		return "No models to measure."
	var said := PackedStringArray(["%d models against the collection, as My collection's What can I "
		% ranked.size() + "build? ranks them, most of it owned first:"])
	for one: Array in ranked.slice(0, mini(limit, 25) if not input.has("limit") else limit):
		var cover: Dictionary = one[2]
		said.append("  %d%% %s (%s): owns %d of its %d pieces in their colours, %d missing; %d%% in any colour"
			% [roundi(100.0 * float(cover["exact"])), one[0], one[1], int(cover["owned"]), int(cover["pieces"]),
			int(cover["missing"]), roundi(100.0 * float(cover["any_colour"]))])
	said.append("open_model name= opens a saved model or an example; an official model opens from My "
		+ "collection, What can I build? in the window. limit= lists more.")
	return "\n".join(said)


# -- rendering and exporting ---------------------------------------------------------


func _render(input: Dictionary, work: Working.Job = null) -> Variant:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing on the baseplate to render yet."
	if not StudioRender.possible():
		return ("Rendering needs something to draw with, and this app is running without a "
			+ "window. Start it in one (godot --path . -- --mcp).")
	var dialog: RenderDialog = app.get("_render")
	var chosen: RenderSettings = dialog.settings.copy()
	var kind: String = str(input.get("kind", "picture"))
	# A turntable is thirty-six pictures: quick and small unless asked. A job
	# all the same (ToolJobs): on a big model even that outlasts the three
	# minutes a session waits for an answer.
	var turning: bool = kind == "turntable"
	var quality: Dictionary = {"quick": RenderSettings.Quality.QUICK,
		"good": RenderSettings.Quality.GOOD, "best": RenderSettings.Quality.BEST}
	chosen.quality = quality.get(str(input.get("quality", "quick" if turning else "good")),
		RenderSettings.Quality.GOOD)
	var sizes: Dictionary = {"720p": Vector2i(1280, 720), "1080p": Vector2i(1920, 1080),
		"4k": Vector2i(3840, 2160), "square": Vector2i(1080, 1080)}
	chosen.size = sizes.get(str(input.get("size", "720p" if turning else "1080p")),
		Vector2i(1920, 1080))
	chosen.view = str(input.get("view", "hero"))
	var said: String = await dialog.render_for(kind, chosen, work)
	if kind != "picture" or dialog.last_picture() == null:
		return said
	var small: Image = dialog.last_picture().duplicate() as Image
	small.resize(800, maxi(roundi(800.0 * small.get_height() / small.get_width()), 1),
		Image.INTERPOLATE_BILINEAR)
	return [{"type": "text", "text": said}, {"type": "image", "source": {"type": "base64",
		"media_type": "image/png", "data": Marshalls.raw_to_base64(small.save_png_to_buffer())}}]


func _export(input: Dictionary, work: Working.Job = null) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var exports: Exports = app.get("_exports")
	var bar: ModelBar = app.get("_bar")
	# Every saved model, whatever is on the baseplate.
	if str(input.get("format", "")) == "all_models":
		var all: String = exports.all_models()
		return all.left(1).to_upper() + all.substr(1) + "." if not all.is_empty() \
			else "The person has no saved models yet."
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing on the baseplate to export yet."
	var said: String = ""
	match str(input.get("format", "")):
		"ldraw":
			said = await bar.export_now(exports.folder)
		"studio":
			said = await exports.studio_io()
		"glb", "gltf", "obj", "stl":
			said = await exports.model_3d(str(input["format"]))
		"picture":
			if DisplayServer.get_name() == "headless":
				return "A picture needs something to draw with, and this app is running without a window."
			said = await exports.take_picture()
		"bricklink":
			said = exports.shop_list("bricklink")
		"rebrickable":
			said = exports.shop_list("rebrickable")
		"instructions":
			if DisplayServer.get_name() == "headless":
				return "The booklet's pictures need something to draw with, and this app is running without a window."
			if BookletMaker.busy:
				return "The booklet is being drawn already."
			var to: String = exports.folder if not exports.folder.is_empty() \
				else OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
			said = await app.call("_export_booklet", "" if OS.has_feature("web") else
				to.path_join(bar.model_name().to_snake_case() + "_instructions.html"), work)
		_:
			return ("format is ldraw, studio, glb, gltf, obj, stl, picture, bricklink, rebrickable, "
				+ "instructions or all_models.")
	return said.left(1).to_upper() + said.substr(1) + "." if not said.is_empty() else "Nothing written."


# -- brickify -----------------------------------------------------------------------


func _brickify(input: Dictionary, work: Working.Job = null) -> String:
	var dialog: BrickifyDialog = app.get("_brickify")
	if dialog == null:
		return "This app has no Brickify."
	if dialog.is_busy():
		return "A model is being brickified already; job says when it is done."
	var url: String = str(input.get("url", "")).strip_edges()
	var file: String = str(input.get("file", "")).strip_edges()
	# A path given as a link is a path: a session given a model's path passed
	# it as url=.
	if file.is_empty() and (url.begins_with("/") or url.begins_with("~")
			or url.to_lower().begins_with("file://")):
		file = url
		url = ""
	if not file.is_empty():
		var opened: String = await _brickify_file(dialog, file)
		if not opened.is_empty():
			return opened
	elif bool(input.get("pick", false)):
		if OS.has_feature("web"):
			return ("In a browser the file chooser opens only from the person's own click: ask "
				+ "them to choose Build, Brickify a 3D model…, then call brickify with neither "
				+ "url nor pick to lay what they chose.")
		if DisplayServer.get_name() == "headless":
			return "This app is running without a window, so there is no file dialog to open."
		dialog.ask()
		return ("Opened the window's file dialog for the person to choose an %s on their "
			+ "computer. Once they have, the Brickify panel shows it, and they press "
			+ "Brickify — or call brickify again with neither url nor pick (and studs= for the "
			+ "size) to lay it.") % MeshFile.NAMED
	if not url.is_empty():
		if not url.to_lower().begins_with("https://") and not url.to_lower().begins_with("http://"):
			return ("Only an http or https link can be fetched, and %s is not one; a file on this "
				+ "computer goes in file=, by its path.") % url.left(100)
		var name: String = url.get_slice("?", 0).get_slice("#", 0).get_file().uri_decode()
		if not name.get_extension().to_lower() in MeshFile.KINDS:
			return ("%s does not name an %s file; give a link that ends in .%s."
				% [url.left(100), MeshFile.NAMED, ", .".join(MeshFile.KINDS)])
		var fetched: Dictionary = await _fetch(url, MeshFile.MAX_BYTES)
		if fetched.has("error"):
			# Not "serve it on localhost": that is refused too.
			return str(fetched["error"]) + (" A file on this computer goes in file=, by its path."
				if str(fetched["error"]).contains("this computer") else "")
		var bytes: PackedByteArray = fetched["bytes"]
		# An OBJ's .mtl and its pictures, a .gltf's .bin: beside it, as the
		# desktop's picker reads them (MeshFilePicker.open_path).
		var extras: Dictionary = {}
		var folder: String = url.get_slice("?", 0).get_slice("#", 0).get_base_dir()
		for _round: int in 2:
			for wanted: String in MeshFile.companions(bytes, name, extras):
				if extras.has(wanted) or wanted.contains("..") or wanted.contains("://") \
						or wanted.begins_with("/"):
					continue
				var beside: Dictionary = await _fetch(folder + "/" + wanted.uri_encode()
					.replace("%2F", "/"), MeshFile.MAX_BYTES)
				if beside.has("bytes"):
					extras[wanted] = beside["bytes"]
		var why: String = await dialog.take(bytes, name, extras)
		if not why.is_empty():
			return why.left(1).to_upper() + why.substr(1) + "."
	elif file.is_empty() and (dialog.model() == null or not dialog.visible):
		return ("Give file= the path of an %s on this computer, url= an http(s) link to one, "
			+ "or pick=true for the person to choose one.") % MeshFile.NAMED
	var refused: String = dialog.choose(input)
	if not refused.is_empty():
		return refused.left(1).to_upper() + refused.substr(1) + "."
	await dialog.brickify(work)
	var said: String = dialog.outcome()
	said = said.left(1).to_upper() + said.substr(1) + "."
	if dialog.landed():
		var world: BrickWorld = app.get("_world")
		var store: ModelStore = app.get("_store")
		var others: bool = false
		for brick: BrickWorld.Brick in world.bricks():
			if not store.scenery.has(brick.id) and not Assemblies.within(
					Assemblies.path_of(brick), dialog.last_path):
				others = true
				break
		said += ("\nIts booklet follows its own steps, a course a step with the side panels "
			+ "built on their own: export_model format=instructions. Its parts: export_model "
			+ "format=bricklink (a BrickLink wanted list) or format=rebrickable (a Rebrickable "
			+ "list).")
		if others:
			said += " Those are of everything on the baseplate, and more is built there than this."
		said += (" The person has the same on the Brickify panel, which stays up once it is "
			+ "down: Booklet, BrickLink and Rebrickable, of this build alone.")
		if not dialog.last_stock.is_empty():
			said += (" parts_list which=need says what their collection is short of, with "
				+ "what could stand in.")
		said += (" No price: BrickLink's price guide needs a seller's API keys, which this "
			+ "app does not have.")
	return said


## A 3D model on this computer at [param path], read as the window's file
## dialog reads one (MeshFilePicker.read_path: the .mtl, pictures and .bin it
## names from beside it) and put in the Brickify panel; "" once it is, or why
## not. A session given a path had been refused ("Only an http or https link
## can be fetched"), opened the file dialog for a person who was not there,
## and told them to serve the folder on localhost, which is refused too.
## Only a 3D model's own kinds are read, so nothing else on the computer can
## be: a session drives the app, not the person's files.
func _brickify_file(dialog: BrickifyDialog, path: String) -> String:
	if OS.has_feature("web"):
		return ("In a browser the app cannot read a file on the person's computer: ask them to "
			+ "choose Build, Brickify a 3D model…, then call brickify with neither file nor url "
			+ "to lay what they chose.")
	var at: String = path.uri_decode().trim_prefix("file://") if path.to_lower().begins_with(
		"file://") else path
	if at.begins_with("~"):
		at = OS.get_environment("HOME") + at.substr(1)
	at = at.simplify_path()
	if not at.get_extension().to_lower() in MeshFile.KINDS:
		return "%s is not an %s file; file= takes one of those." % [at.left(160),
			MeshFile.NAMED]
	if not at.is_absolute_path() or not FileAccess.file_exists(at):
		return "There is no file %s on this computer." % at.left(160)
	var size: int = 0
	var handle := FileAccess.open(at, FileAccess.READ)
	if handle != null:
		size = handle.get_length()
		handle.close()
	if size > MeshFile.MAX_BYTES:
		return "%s is larger than %s, more than can be brought in." % [at.get_file(),
			String.humanize_size(MeshFile.MAX_BYTES)]
	var read: Dictionary = MeshFilePicker.read_path(at)
	var why: String = await dialog.take(read["bytes"], at.get_file(), read["extras"])
	if not why.is_empty():
		return why.left(1).to_upper() + why.substr(1) + "."
	return ""


## The bytes at [param url], fetched as the app fetches pictures of a
## subject (ReferenceFinder), no more than [param most] of them: {"bytes"},
## or {"error"} saying why not. Only http and https, and not this computer
## or the network it is on: a session drives the app, not the person's
## other machines.
func _fetch(url: String, most: int) -> Dictionary:
	var lower: String = url.to_lower()
	if not (lower.begins_with("https://") or lower.begins_with("http://")):
		return {"error": "Only an http or https link can be fetched, and %s is not one."
			% url.left(100)}
	# The host, past any user@ and before any :port.
	var host: String = lower.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0)
	host = host.get_slice("@", host.get_slice_count("@") - 1)
	host = host.get_slice("]", 0).trim_prefix("[") if host.begins_with("[") \
		else host.get_slice(":", 0)
	if _near(host) and not fetch_near:
		return {"error": "%s is this computer or its network, which a session may not fetch from."
			% host}
	var request := HTTPRequest.new()
	request.body_size_limit = most
	request.timeout = 90.0
	app.add_child(request)
	if request.request(url, ["User-Agent: " + ReferenceFinder.AGENT]) != OK:
		request.queue_free()
		return {"error": "Could not ask %s for it." % host}
	var got: Array = await request.request_completed
	request.queue_free()
	var result: int = int(got[0])
	var code: int = int(got[1])
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return {"error": "%s is larger than %s, more than can be brought in."
			% [url.get_file().left(80), String.humanize_size(most)]}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Could not fetch %s (%s)." % [url.left(100), {
			HTTPRequest.RESULT_CANT_RESOLVE: "no such host",
			HTTPRequest.RESULT_CANT_CONNECT: "it would not connect",
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "its certificate was refused",
			HTTPRequest.RESULT_TIMEOUT: "it took too long",
			HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "it redirected too many times",
		}.get(result, "error %d" % result)]}
	if code != 200:
		return {"error": "%s answered %d, not the file." % [host, code]}
	return {"bytes": got[3] as PackedByteArray}


## Whether [param host] names this computer or a private network.
static func _near(host: String) -> bool:
	if host in ["localhost", "0.0.0.0", "::1", "::"] or host.ends_with(".local") \
			or host.ends_with(".localhost"):
		return true
	var parts: PackedStringArray = host.split(".")
	if parts.size() != 4 or not Array(parts).all(func(p: String) -> bool: return p.is_valid_int()):
		return host.contains(":") and (host.begins_with("fc") or host.begins_with("fd")
			or host.begins_with("fe80"))
	var a: int = parts[0].to_int()
	var b: int = parts[1].to_int()
	return a == 127 or a == 10 or a == 0 or (a == 192 and b == 168) or (a == 169 and b == 254) \
		or (a == 172 and b >= 16 and b <= 31) or (a == 100 and b >= 64 and b <= 127)


# -- prints and stickers --------------------------------------------------------------


func _print_part(input: Dictionary) -> String:
	var studio: PrintStudio = app.get("_studio")
	if studio == null:
		return "This app has no print designer."
	if not input.has("brick"):
		return "Give brick= the part's number (look_at_model numbers them)."
	var brick: BrickWorld.Brick = _brick(int(input["brick"]))
	if brick == null:
		return "No part numbered %d (look_at_model numbers them)." % int(input["brick"])
	var builder: Builder = app.get("_builder")
	var depth: int = builder.history_depth()
	studio.last_placed = 0
	# The LEGO Group's own: a printed version of the part, or a sticker of
	# the library's, as Edit, Printed versions… and a sticker in hand do.
	if input.has("versions"):
		return _versions_of(studio, brick, str(input["versions"]))
	if input.has("version") or input.has("sticker_part"):
		var done: String
		if input.has("version"):
			done = await studio.swap_to(PackedInt64Array([brick.id]),
				str(input["version"]).strip_edges().to_lower())
		else:
			done = await studio.stick_part_on(brick.id, str(input.get("side", "+z")),
				str(input["sticker_part"]).strip_edges().to_lower(),
				int(input.get("colour", Stickers.FILM)))
		_one_undo_since(depth)
		var put: BrickWorld.Brick = (app.get("_world") as BrickWorld).get_brick(studio.last_placed)
		return done if put == null or not (done.begins_with("Swapped") or done.begins_with("Stuck")) \
			else "%s It is #%d, %s." % [done, put.id, put.part_id]
	var picture: Image = null
	if input.has("svg"):
		picture = PictureFile.decode(str(input["svg"]).to_utf8_buffer(), "svg")
		if picture == null:
			return "That svg could not be drawn: give a whole <svg> with a viewBox."
	elif input.has("picture_data"):
		# A picture the person gave in the conversation, handed over as its
		# own bytes: what neither a link nor an svg can carry.
		var read: Dictionary = PictureFile.from_data(str(input["picture_data"]))
		if read.has("error"):
			return _sentence(str(read["error"]))
		picture = read["image"]
	elif input.has("picture_url"):
		var fetched: Dictionary = await _fetch(str(input["picture_url"]).strip_edges(),
			PictureFile.MOST_BYTES)
		if fetched.has("error"):
			return str(fetched["error"])
		picture = PictureFile.decode(fetched["bytes"])
		if picture == null:
			return _sentence(PictureFile.not_read(fetched["bytes"], "That link"))
	else:
		var printed: int = studio.versions_of(brick.part_id).size()
		return ("Give the picture: svg= drawn by you, picture_data= a picture's own bytes as "
			+ "base64 (one the person gave you), or picture_url= an http(s) link to one.%s" % (
				(" Or version= one of the %d printed versions the LEGO Group made of %s: "
					% [printed, studio.plain_of(brick.part_id)]
					+ "versions=\"\" lists them, versions=\"words\" those with the words on them.")
					if printed > 0 else ""))
	var sticker: bool = bool(input.get("sticker", false))
	var title: String = str(input.get("name", "My Sticker" if sticker else "My Print")) \
		.strip_edges().left(60)
	var said: String
	if sticker:
		said = await studio.sticker_on(brick.id, str(input.get("side", "+z")),
			bool(input.get("span", true)), picture, title)
	else:
		said = await studio.print_on(brick.id, picture, str(input.get("area", "")), title)
	_one_undo_since(depth)
	var placed: BrickWorld.Brick = (app.get("_world") as BrickWorld).get_brick(studio.last_placed)
	if placed == null:
		return said
	return "%s It is #%d, %s." % [said, placed.id, placed.part_id]


## The printed and stickered versions of [param brick]'s part, those with
## [param words] in their names, for a session to choose one by version=.
func _versions_of(studio: PrintStudio, brick: BrickWorld.Brick, words: String) -> String:
	var plain: String = studio.plain_of(brick.part_id)
	var all: Array[PartLibrary.PartInfo] = studio.versions_of(brick.part_id)
	if all.is_empty():
		return ("%s has no printed or stickered versions in the library: print one of your own "
			% plain + "with svg=, picture_data= or picture_url=.")
	var found: Array[PartLibrary.PartInfo] = studio.versions_of(brick.part_id, words)
	if found.is_empty():
		return "None of the %d versions of %s has \"%s\" in its name; versions=\"\" lists them all." \
			% [all.size(), plain, words.strip_edges()]
	var said := PackedStringArray()
	said.append("#%d is %s. %d of the %d versions of %s%s, the most used first:" % [brick.id,
		brick.part_id, found.size(), all.size(), plain,
		" with \"%s\"" % words.strip_edges() if not words.strip_edges().is_empty() else ""])
	for info: PartLibrary.PartInfo in found.slice(0, 30):
		var on_it: String = info.printed()
		if on_it.length() > 70:
			on_it = on_it.left(70) + "…"
		said.append("  %s: %s%s%s" % [info.id, on_it,
			" (stickered)" if info.decor() & PartLibrary.PartInfo.PRINTED == 0 else "",
			", in %d sets" % info.in_sets if info.in_sets > 0 else ""])
	if found.size() > 30:
		said.append("  and %d more: versions=\"words\" narrows them." % (found.size() - 30))
	said.append("print_part {\"brick\": %d, \"version\": \"%s\"} swaps it for one, in its colour "
		% [brick.id, found[0].id] + "where it stands; \"version\": \"%s\" makes it plain again." % plain)
	return "\n".join(said)


## Words said as a sentence: a capital first and a full stop last.
static func _sentence(words: String) -> String:
	var said: String = words.strip_edges()
	if said.is_empty():
		return said
	said = said.left(1).to_upper() + said.substr(1)
	return said if said.ends_with(".") or said.ends_with("?") else said + "."


# -- sections -------------------------------------------------------------------------


func _sections_ui() -> SectionsUi:
	var shell: Shell = app.get("_shell")
	return shell.sections if shell != null else null


func _suggest_sections() -> String:
	var ui: SectionsUi = _sections_ui()
	if ui == null:
		return "This app has no sections."
	await ui.suggest()
	var made: Array = ui.sections.suggested
	if made.is_empty():
		return "No sections suggested: %s." % ui.sections.why_none
	var lines := PackedStringArray()
	var level: String = ui.sections.level
	lines.append("%d sections%s, in the order they are built (shown in the person's model "
		% [made.size(), "" if level.is_empty() else " of %s" % Assemblies.label(level)]
		+ "tree). Parts, joints to the rest, what each is built onto, the way it comes off:")
	var total: int = 0
	for one: Sections.Suggestion in made:
		lines.append(" " + one.said())
		total += one.ids.size()
	lines.append("%d parts in all. make_sections makes them sub-assemblies (sections= to "
		% total + "rename or merge); evaluate_section suggestion=N weighs one alone.")
	return "\n".join(lines)


func _make_sections(input: Dictionary) -> String:
	var ui: SectionsUi = _sections_ui()
	if ui == null:
		return "This app has no sections."
	var made: Array = ui.sections.suggested
	if made.is_empty():
		return "Nothing suggested: call suggest_sections first."
	if input.has("sections"):
		var asked: Array = input["sections"]
		var by_number: Dictionary = {}
		for one: Sections.Suggestion in made:
			by_number[one.number] = one
		var used: Dictionary = {}
		var groups: Array = []
		for entry: Variant in asked:
			if not entry is Dictionary:
				return "Each of sections= is {name, from: [numbers]}."
			var from: Array = (entry as Dictionary).get("from", [])
			var picked: Array = []
			for n: Variant in from:
				if not by_number.has(int(n)):
					return "No suggestion %d: they are 1 to %d." % [int(n), made.size()]
				if used.has(int(n)):
					return "Suggestion %d is in two sections." % int(n)
				used[int(n)] = true
				picked.append(by_number[int(n)])
			if picked.is_empty():
				return "Each section needs from= the suggestions it is made of."
			groups.append([str((entry as Dictionary).get("name", "")), picked])
		# Merged and named as asked, then made, in one undo step.
		var keep: Array = []
		for group: Array in groups:
			var picked: Array = group[1]
			var first: Sections.Suggestion = picked[0]
			for other: Sections.Suggestion in picked.slice(1):
				first.ids.append_array(other.ids)
				ui.sections.suggested.erase(other)
			if not str(group[0]).strip_edges().is_empty():
				first.name = str(group[0]).strip_edges().replace("/", "-").replace("#", "")
			keep.append(first)
		ui.sections._renumber()
		var numbers: Array = []
		for one: Sections.Suggestion in keep:
			numbers.append(one.number)
		var said_some: String = ui.accept(numbers)
		return said_some.left(1).to_upper() + said_some.substr(1) + ". One step to undo."
	var said: String = ui.accept()
	return said.left(1).to_upper() + said.substr(1) + ". One step to undo."


func _break_out_section(input: Dictionary) -> String:
	var ui: SectionsUi = _sections_ui()
	if ui == null:
		return "This app has no sections."
	var world: BrickWorld = app.get("_world")
	if bool(input.get("all", false)):
		if world.broken_out.is_empty():
			return "No section is broken out."
		var back: String = ui.put_back_all()
		return back.left(1).to_upper() + back.substr(1) + "."
	var asked: String = str(input.get("section", ""))
	var path: String = ui.sections.find_section(asked)
	if path.is_empty():
		var have := PackedStringArray()
		for one: Dictionary in ui.sections.sections():
			have.append(Assemblies.label(str(one["path"])))
		return ("Give section= a sub-assembly by name. %s" % ("There are: %s." % ", ".join(have)
			if not have.is_empty() else "There are none: suggest_sections, then make_sections."))
	var out: bool = not ui.sections.out_record(path).is_empty()
	var put_back: bool = bool(input.get("put_back", false))
	if put_back != out:
		return "%s is %s." % [Assemblies.label(path), "not broken out" if put_back
			else "broken out already: put_back=true puts it back"]
	var said: String = ui.break_out_or_back(path)
	if not put_back and not ui.sections.out_record(path).is_empty():
		var offset: Vector3 = (ui.sections.out_record(path)[1] as Dictionary)["offset"]
		said += (" (moved x %s, y %s plates, z %s studs; put_back=true puts it exactly back)"
			% [Balance.studs(offset.x / BrickLattice.STUD), Balance.studs(offset.y
			/ BrickLattice.PLATE), Balance.studs(offset.z / BrickLattice.STUD)])
	return said.left(1).to_upper() + said.substr(1) + "."


func _evaluate_section(input: Dictionary) -> String:
	var ui: SectionsUi = _sections_ui()
	if ui == null:
		return "This app has no sections."
	var made: Dictionary
	if input.has("suggestion"):
		made = await ui.evaluate("", int(input["suggestion"]))
		if made.is_empty():
			return "No suggestion %d: call suggest_sections first." % int(input["suggestion"])
	else:
		var path: String = ui.sections.find_section(str(input.get("section", "")))
		if path.is_empty():
			return "Give section= a sub-assembly by name, or suggestion= a suggest_sections number."
		made = await ui.evaluate(path)
	var lines := PackedStringArray([Sections.evaluation_words(made)])
	var lots: Array = made.get("lots_list", [])
	if not lots.is_empty():
		var listed := PackedStringArray()
		for lot: Dictionary in lots.slice(0, 40):
			listed.append("%d x %s %s (%s)" % [int(lot["count"]), str(lot["part"]),
				str(lot["name"]), str(lot["colour"])])
		lines.append("Its parts: " + "; ".join(listed) + (" …and %d more lots." % (lots.size() - 40)
			if lots.size() > 40 else "."))
	return "\n".join(lines)


# -- making a copy unique ---------------------------------------------------------------


func _make_unique(input: Dictionary) -> String:
	var assemblies: Assemblies = (app.get("_shell") as Shell).assemblies
	var verbs: EditVerbs = app.get("_verbs")
	var path: String = ""
	var asked: String = str(input.get("assembly", "")).strip_edges()
	if not asked.is_empty():
		for one: String in assemblies.paths():
			if one == asked or Assemblies.label(one).to_lower() == asked.to_lower():
				path = one
		if path.is_empty():
			return "No sub-assembly %s. There is: %s." % [asked,
				", ".join(assemblies.paths())]
	elif input.has("brick"):
		var brick: BrickWorld.Brick = _brick(int(input["brick"]))
		if brick == null:
			return "No part numbered %d." % int(input["brick"])
		# The innermost assembly round it that has other copies.
		var under: String = Assemblies.path_of(brick)
		while not under.is_empty() and assemblies.copies_of(under).is_empty():
			under = Assemblies.parent_of(under)
		if under.is_empty():
			return "#%d is in no sub-assembly with other copies." % brick.id
		path = under
	else:
		return "Give assembly= a sub-assembly's path or name, or brick= a part in it."
	var copies: PackedStringArray = assemblies.copies_of(path)
	if copies.is_empty():
		return "%s has no other copies: it is a sub-assembly of its own already." \
			% Assemblies.label(path)
	var fresh: String = verbs.make_unique(path)
	return ("%s is a sub-assembly of its own now, %s: changing it changes no other. The %d "
		% [Assemblies.label(path), fresh, copies.size()]
		+ "other cop%s of %s stay as %s." % ["y" if copies.size() == 1 else "ies",
			Assemblies.definition(Assemblies.leaf(path)), "it was" if copies.size() == 1
				else "they were"])
