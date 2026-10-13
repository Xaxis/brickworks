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


## The window's commands (Shell) a session does with a tool: command id, or
## a prefix ending in "*", -> the tool.
const COMMANDS: Dictionary = {
	"new": "clear_model", "clear": "clear_model", "open": "open_model",
	"save": "save_model", "save_as": "save_model",
	"export_ldraw": "export_model", "export_io": "export_model", "export_3d": "export_model",
	"export_picture": "export_model", "export_bricklink": "export_model",
	"export_rebrickable": "export_model", "instructions": "export_model",
	"render": "render_model",
	"undo": "undo", "redo": "undo",
	"cut_parts": "edit_model", "copy": "edit_model", "paste": "edit_model",
	"duplicate": "edit_model", "delete": "edit_model", "paint": "edit_model",
	"replace": "edit_model", "make_submodel": "edit_model",
	"step_*": "edit_steps", "timeline": "edit_steps",
	"floor_*": "set_floor",
	"flex": "lay_flex", "reshape_flex": "lay_flex",
	"pose": "pose_model", "mode_hinge": "pose_model",
	"parts_list": "parts_list", "collection": "parts_list", "collection_need": "parts_list",
	"collection_build": "parts_list",
	"minifig": "add_minifig", "mosaic": "make_art", "part_maker": "make_part",
	"stability": "review_model", "ask_claude": "selection",
	"brickify": "brickify", "import_mesh": "brickify", "print_part": "print_part",
	"sticker": "print_part",
	"make_unique": "make_unique",
	"simulate": "simulate_mechanism",
}

## The window's commands no tool does, each with why. A command that is
## in neither this nor COMMANDS fails the sync probe.
const WINDOW_ONLY: Dictionary = {
	"import_*": "reads a file from the person's disk, picked in a dialog; open_model opens the app's own models",
	"share": "publishes the model on the web as the person, for anyone with the link and, ticked, in the public gallery: theirs to decide",
	"account": "signing in is the person's",
	"quit": "closes the app the session is driving",
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
 - lay_flex: a hose, a pneumatic tube, a flexible axle, a string or a \
chain, laid between two connectors (pin holes, axles, studs) of two parts \
by number, or round two sprockets; item= lays an existing one again.
 - pose_model: lists the joints (a sub-assembly on a hinge, a turntable \
or a clip) and swings one to an angle, as far as it has room. \
animate_model: poses at moments, played smoothly between and rendered as \
an animation.
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
opens one. It cannot be undone: save_model first.
 - parts_list: the model's parts by part and colour with element ids; \
which="need" what the person's collection is short of; "buildable" which \
saved models it can build.
 - render_model: a picture or a turntable worth keeping, Quick, Good or \
Best, up to 4K, saved where Render saves.
 - export_model: the model as LDraw, a BrickLink Studio .io, a 3D file \
(GLB, glTF, OBJ, STL), a picture, a BrickLink wanted list, a Rebrickable \
parts list, or the building instructions as a booklet, written where \
Export writes.
 - brickify: a 3D model (OBJ, STL, glTF) laid in LEGO® bricks at the size asked, \
as one sub-assembly: url= a link the app fetches, or pick=true opens the \
window's file dialog for the person, after which brickify with neither \
lays what they chose.
 - print_part: a picture (svg= you draw, or picture_url=) printed on a \
part where it stands, or with sticker=true stuck on one of its faces.
 - make_unique: one copy of a sub-assembly cut loose from the others, so \
changing it changes no other.
 - job: what takes long on a big model (render_model, animate_model's \
rendering, export_model's studio, picture and instructions, make_art, \
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
			"name": "animate_model",
			"description": ("Animate the model as Build, Pose's keys do: poses at moments, "
				+ "played smoothly between (an arm raised over two seconds and lowered "
				+ "again, doors opening), the model turned round once as well if asked, and "
				+ "rendered as an animation (a WebP, and an MP4 where ffmpeg is installed) "
				+ "where Render saves. keys: [{\"t\": seconds, \"angles\": {joint: degrees}}], "
				+ "joints by number or name from pose_model's list. Rendering needs the app "
				+ "in a window and is a job (job gives the result); render=false only sets "
				+ "the keys, for the person to play."),
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
			"name": "simulate_mechanism",
			"description": ("Turn the model's gear train as Tools, Simulate mechanism does, "
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
				+ "baseplate, as File, Open does. Opening cannot be undone, so it is refused "
				+ "while the model has changes not saved, unless discard_changes=true."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"name": {"type": "string", "description": "a model's name from the list"},
				"discard_changes": {"type": "boolean"},
			}},
		},
		{
			"name": "parts_list",
			"description": ("The model's parts, as Build, Parts list shows them: by part and "
				+ "colour, with counts and LEGO® element ids. which=\"need\" measures it "
				+ "against the person's collection (My collection): how much they own and "
				+ "what they are short of; which=\"buildable\" says which of their saved "
				+ "models their collection builds."),
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
				+ "print). studio, picture and instructions are jobs: the answer is a job "
				+ "number at once, and job gives the result."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["format"], "properties": {
				"format": {"type": "string", "enum": ["ldraw", "studio", "glb", "gltf", "obj",
					"stl", "picture", "bricklink", "rebrickable", "instructions"]},
			}},
		},
		{
			"name": "brickify",
			"description": ("Lay a 3D model in LEGO® bricks, as Build, Brickify a 3D model… does: an "
				+ "OBJ, STL or glTF/GLB laid at the size asked (studs along its longest side) "
				+ "in slopes, curves and tiles, or plain bricks and plates, as one "
				+ "sub-assembly named after the file, beside what is built. url= an http(s) "
				+ "link to the file, fetched by the app (96 MB at most; an OBJ's .mtl and a "
				+ ".gltf's .bin come from beside it). pick=true opens the window's file "
				+ "dialog for the person to choose one on their computer, and says so; once "
				+ "they have, brickify with neither lays what the panel shows. Laying is a "
				+ "job: the answer is a job number, and job gives the result."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"url": {"type": "string", "description": "http(s) link to an .obj, .stl, .gltf or .glb"},
				"pick": {"type": "boolean", "description": "open the file dialog for the person"},
				"studs": {"type": "integer", "description": "studs along its longest side, %d to %d; 24 when omitted"
					% [Brickify.LEAST_STUDS, Brickify.MOST_STUDS]},
				"up": {"type": "string", "enum": Array(Brickify.UPS),
					"description": "which of the file's axes is up; a printer's STL is +Z"},
				"hollow": {"type": "boolean"},
				"smooth": {"type": "boolean", "description": "slopes, curves, tiles and studs sideways; true when omitted"},
				"colours": {"type": "string", "enum": ["model", "one", "limit"],
					"description": "its own, all colour=, or its own cut to the limit= it uses most"},
				"colour": {"type": "integer", "description": "LDraw colour, for colours one"},
				"limit": {"type": "integer", "description": "how many colours, for colours limit"},
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
				+ "proportions; flat colours print best), or picture_url= an http(s) link to "
				+ "a PNG, JPEG, WebP or SVG."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["brick"], "properties": {
				"brick": {"type": "integer", "description": "the part's number in look_at_model"},
				"sticker": {"type": "boolean"},
				"area": {"type": "string", "description": "a print's area, by name"},
				"side": {"type": "string", "enum": BrickLattice.FACE_AXIS.keys(),
					"description": "a sticker's face; +z when omitted"},
				"span": {"type": "boolean"},
				"svg": {"type": "string"},
				"picture_url": {"type": "string"},
				"name": {"type": "string", "description": "what the print or sticker is called"},
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
		"lay_flex":
			return await _lay_flex(input)
		"pose_model":
			return _pose(input)
		"simulate_mechanism":
			return await _simulate(input, work)
		"animate_model":
			return await _animate(input, work)
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
	# As clear_model: a request about the selected parts changes those alone.
	if assistant != null and assistant.asked_about_selection() and tool in CHANGES:
		return ("Not now — the person asked about the parts they selected, and this would "
			+ "change more than those. Change them with edit_selection.")
	return ""


## The tools that change the model.
const CHANGES: Array[String] = ["set_floor", "edit_steps", "lay_flex", "pose_model", "undo",
	"open_model", "brickify", "print_part", "make_unique"]


## What a model shared to look at allows, as Shell.LOOKING does for the
## window: its parts, its steps and its booklet, and asking what it stands on.
static func _while_looking(tool: String, input: Dictionary) -> bool:
	match tool:
		"parts_list":
			return str(input.get("which", "model")) == "model"
		"edit_steps":
			return str(input.get("op", "list")) == "list"
		"set_floor", "pose_model":
			return input.is_empty()
		"simulate_mechanism":
			return not bool(input.get("record", false))
		"export_model":
			return str(input.get("format", "")) == "instructions"
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
	+ "Name the part that turns as an assembly (edit_model's assemblies), standing on its hinge.")


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
		for n: int in joints.size():
			var one: Poser.Joint = joints[n]
			said.append("  %d. %s, on its %s, at %d° (%d parts)" % [n + 1,
				Assemblies.label(one.path), one.kind(), roundi(one.angle), one.ids.size()])
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


func _animate(input: Dictionary, work: Working.Job = null) -> String:
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
			if joint == null:
				return ("No joint %s. %s" % [str(name), "pose_model lists them."
					if not joints.is_empty() else "Nothing here turns: " + NO_JOINTS])
			angles[joint.path] = clampf(float(given[name]), -180.0, 180.0)
		made.append([t, angles])
	panel.animation.keys.clear()
	for one: Array in made:
		panel.animation.add_key(float(one[0]), one[1])
	panel.animation.turntable = turning
	var said: String = "%d key%s over %.1f s%s" % [made.size(), "" if made.size() == 1 else "s",
		panel.animation.length(), ", turning round once" if turning else ""]
	if not bool(input.get("render", true)):
		return "Set %s: Build, Pose and animate plays it." % said
	if not StudioRender.possible():
		return ("Set %s. Rendering it needs something to draw with, and this app is running "
			% said + "without a window; the person can play it from Build, Pose and animate.")
	var frames: int = await panel.render_animation(work)
	if frames <= 0:
		return "Nothing rendered: %s" % panel.rendered_words()
	return "%s: %s" % [said.left(1).to_upper() + said.substr(1), panel.rendered_words()]


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
	for _n: int in count:
		var words: String = builder.redo_words() if again else (
			builder.history_words(1)[0] if builder.history_depth() > 0 else "")
		if words.is_empty():
			break
		await verbs.press("redo" if again else "undo")
		done.append(words)
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
	if name.is_empty():
		var said := PackedStringArray()
		said.append("Open now: %s." % store.title)
		for list: Array in [["Saved", saved], ["Examples", examples]]:
			var rows := PackedStringArray()
			for entry: ModelStore.Entry in list[1]:
				rows.append("%s (%d parts)" % [entry.name, entry.bricks])
			said.append("%s: %s." % [list[0], ", ".join(rows) if not rows.is_empty() else "none"])
		return "\n".join(said)
	var chosen: ModelStore.Entry = null
	for entry: ModelStore.Entry in saved + examples:
		if chosen == null and entry.name.to_lower() == name.to_lower():
			chosen = entry
	if chosen == null:
		return "No model called %s. open_model with no name lists them." % name
	if store.has_unsaved_work() and not bool(input.get("discard_changes", false)):
		return ("The model on the baseplate, %s, has changes that are not saved, and opening "
			% store.title + "cannot be undone. save_model first, or give discard_changes=true.")
	if assistant != null:
		assistant.forget_built()
	var placed: int = await bar.open_with_progress(chosen.path)
	bar.opened.emit(placed)
	return "Opened %s: %d parts. look_at_model to see it." % [chosen.name, placed]


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
	var said := PackedStringArray()
	var found: Array = []
	for entry: ModelStore.Entry in store.list_saved():
		var needs: Dictionary = Collection.needs_of_ldraw(FileAccess.get_file_as_string(entry.path),
			library)
		var cover: Dictionary = Collection.coverage(needs, mine.on_hand)
		var pieces: int = int(cover["pieces"])
		if pieces > 0:
			found.append([entry.name, int(cover["owned"]),
				roundi(float(cover["any_colour"]) * pieces), pieces])
	# The ones nearest to built first, as What can I build? lists them.
	found.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[1]) / float(a[3]) > float(b[1]) / float(b[3]))
	for one: Array in found.slice(0, limit):
		said.append("  %s: owns %d of its %d pieces in their colours%s" % [one[0], one[1], one[3],
			", %d in any colour" % one[2] if int(one[2]) > int(one[1]) else ""])
	return "Saved models against the collection:\n" + "\n".join(said) if not said.is_empty() \
		else "No saved models to measure."


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
			return "format is ldraw, studio, glb, gltf, obj, stl, picture, bricklink, rebrickable or instructions."
	return said.left(1).to_upper() + said.substr(1) + "." if not said.is_empty() else "Nothing written."


# -- brickify -----------------------------------------------------------------------


func _brickify(input: Dictionary, work: Working.Job = null) -> String:
	var dialog: BrickifyDialog = app.get("_brickify")
	if dialog == null:
		return "This app has no Brickify."
	if dialog.is_busy():
		return "A model is being brickified already; job says when it is done."
	var url: String = str(input.get("url", "")).strip_edges()
	if bool(input.get("pick", false)):
		if OS.has_feature("web"):
			return ("In a browser the file chooser opens only from the person's own click: ask "
				+ "them to choose Build, Brickify a 3D model…, then call brickify with neither "
				+ "url nor pick to lay what they chose.")
		if DisplayServer.get_name() == "headless":
			return "This app is running without a window, so there is no file dialog to open."
		dialog.ask()
		return ("Opened the window's file dialog for the person to choose an OBJ, STL or glTF "
			+ "on their computer. Once they have, the Brickify panel shows it, and they press "
			+ "Brickify — or call brickify again with neither url nor pick (and studs= for the "
			+ "size) to lay it.")
	if not url.is_empty():
		if not url.to_lower().begins_with("https://") and not url.to_lower().begins_with("http://"):
			return "Only an http or https link can be fetched, and %s is not one." % url.left(100)
		var name: String = url.get_slice("?", 0).get_slice("#", 0).get_file().uri_decode()
		if not name.get_extension().to_lower() in MeshFile.KINDS:
			return ("%s does not name an OBJ, STL, glTF or GLB file; give a link that ends in "
				% url.left(100) + ".obj, .stl, .gltf or .glb.")
		var fetched: Dictionary = await _fetch(url, MeshFile.MAX_BYTES)
		if fetched.has("error"):
			return str(fetched["error"])
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
	elif dialog.model() == null or not dialog.visible:
		return ("Give url= an http(s) link to an OBJ, STL or glTF, or pick=true for the person "
			+ "to choose one on their computer.")
	var refused: String = dialog.choose(input)
	if not refused.is_empty():
		return refused.left(1).to_upper() + refused.substr(1) + "."
	await dialog.brickify(work)
	var said: String = dialog.outcome()
	return said.left(1).to_upper() + said.substr(1) + "."


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
	var picture: Image = null
	if input.has("svg"):
		picture = PictureFile.decode(str(input["svg"]).to_utf8_buffer(), "svg")
		if picture == null:
			return "That svg could not be drawn: give a whole <svg> with a viewBox."
	elif input.has("picture_url"):
		var fetched: Dictionary = await _fetch(str(input["picture_url"]).strip_edges(),
			PictureFile.MOST_BYTES)
		if fetched.has("error"):
			return str(fetched["error"])
		picture = PictureFile.decode(fetched["bytes"])
		if picture == null:
			return "That link is not to a picture this can read: a PNG, JPEG, WebP, BMP or SVG."
	else:
		return "Give the picture: svg= drawn by you, or picture_url= an http(s) link to one."
	var sticker: bool = bool(input.get("sticker", false))
	var title: String = str(input.get("name", "My Sticker" if sticker else "My Print")) \
		.strip_edges().left(60)
	var builder: Builder = app.get("_builder")
	var depth: int = builder.history_depth()
	studio.last_placed = 0
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
