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
## The session a call came on when it names no chat (the desktop's MCP
## port, by its session; the line protocol, by its connection), or "": set
## by CommandSocket beside [member chat]. A collection's lots are marked by
## it, so two such sessions' lots stay apart (mbreview finding 8).
var connection: String = ""
## The gallery, read for a session (GalleryTool, 2026-10-13).
var _gallery: GalleryTool
## The window's hand tools, for a session (HandTools, APP_UX3).
var _hands: HandTools
## What a session sees as a person does: boards of views, parts picked out,
## a booklet page (SeeTools, APP_UX4).
var _see: SeeTools
## Edit, Pattern…'s grid for a session (PatternTool, APP_UX4 grid).
var _pattern: PatternTool
## The person's palettes for a session (PaletteTool, APP_UX7 mcppalettes).
var _palette: PaletteTool


## The window's commands (Shell) a session does with a tool: command id, or
## a prefix ending in "*", -> the tool.
const COMMANDS: Dictionary = {
	"new": "clear_model", "clear": "clear_model", "open": "open_model", "library": "open_model",
	"save": "save_model", "save_as": "save_model", "versions": "open_model",
	# open_model versions=true version=N reads what changed since that save.
	"compare": "open_model",
	"export_all": "export_model",
	"export_ldraw": "export_model", "export_io": "export_model", "export_3d": "export_model",
	"export_picture": "export_model", "export_bricklink": "export_model",
	"export_rebrickable": "export_model", "instructions": "export_model",
	"render": "render_model",
	"render_queue": "render_queue",
	"undo": "undo", "redo": "undo",
	"cut_parts": "edit_model", "copy": "edit_model", "paste": "edit_model",
	"duplicate": "edit_model", "delete": "edit_model", "paint": "edit_model",
	# Edit, Pattern…'s grid (and a row, a grid of one row) on parts by number
	# (PatternTool); a named section repeats stepped or round a centre with
	# edit_model's repeat_section, a design with submit_design's repeat.
	"pattern": "pattern_parts",
	"replace": "edit_model", "make_submodel": "edit_model",
	"step_*": "edit_steps", "timeline": "edit_steps", "booklet_*": "edit_booklet",
	"floor_*": "set_floor",
	"flex": "lay_flex", "reshape_flex": "lay_flex",
	"pose": "pose_model", "mode_hinge": "pose_model", "swing": "pose_model",
	"parts_list": "parts_list", "collection_need": "parts_list",
	"collection_build": "parts_list",
	# mybricks: My collection's What I own, loose lots added and read back.
	"collection": "edit_collection",
	"minifig": "add_minifig", "mosaic": "make_art", "part_maker": "make_part",
	"stability": "review_model", "ask_claude": "selection", "brace": "selection",
	"stress": "weakest_joints",
	"brickify": "brickify", "import_mesh": "brickify", "print_part": "print_part",
	"sticker": "print_part", "printed_versions": "print_part",
	"make_unique": "make_unique",
	"suggest_sections": "suggest_sections", "evaluate_section": "evaluate_section",
	"break_out": "break_out_section", "put_back": "break_out_section",
	"simulate": "simulate_mechanism",
	"hidden_colours": "colour_hidden_parts",
	# The window's hand tools on the parts a session names (HandTools).
	"mirror": "mirror_parts", "split_parts": "split_parts", "merge_parts": "merge_parts",
	"measure": "measure",
	# A model put into this one whole (open_model into=true, intomodel).
	"import_into": "open_model",
	# picklist: LEGO's Pick a Brick list (export_model format=pickabrick).
	"export_pickabrick": "export_model",
	# pagesetup: Build, Booklet page, Page setup… (BookletSheet).
	"booklet_page_setup": "page_setup",
	# seeing2: View, Stud directions is view_board's studs=true.
	"stud_map": "view_board",
	# jointmarks: View, Connection points is view_model's marks=true.
	"joint_marks": "view_model",
	# savedviews: View › Viewpoint › Render each saved view is render_queue's
	# add view=NAME, a view at a time.
	"render_views": "render_queue",
	# comparesets (APP_UX6 #7): File, Compare, Compare two sets or models… is
	# parts_list which="compare".
	"compare_sets": "parts_list",
	# mcpsee3: View › Viewpoint › Save this view… (SavedViews.save_now).
	"save_view": "save_view",
	# subexport (APP_UX7 #19): File › Export › Each sub-model is
	# export_model's submodels=true.
	"export_submodels": "export_model",
	# pointat (APP_UX8 #17): a part pointed out to everyone in a Build
	# together session (Alt-W, or a part's right-click menu).
	"together_point": "point_at",
	# swapfind (APP_UX8 #9): Edit › Find and replace…, into every sub-model.
	"find_replace": "replace_parts",
	# finishpass (APP_UX10 #9): Edit › Finish the surfaces… is review_model's
	# surface pass (surface=true), settled with settle_surface.
	"finish_surfaces": "review_model",
	# setcheck (APP_UX10 #4): File › Compare with the set….
	"compare_set": "compare_with_set",
}

## The window's commands no tool does, each with why. A command that is
## in neither this nor COMMANDS fails the sync probe.
const WINDOW_ONLY: Dictionary = {
	"import_*": "reads a file from the person's disk, picked in a dialog; open_model opens the app's own models",
	"share": "publishes the model on the web as the person, for anyone with the link and, ticked, in the public gallery: theirs to decide",
	"account": "signing in is the person's",
	"together": "lets another account build in the person's model, by a link they send: theirs to decide",
	"comments": "a comment pinned to a part is a person's own words to the people who build the model with them; a session says what it has to say in its own replies",
	"quit": "closes the app the session is driving",
	"new_window": "opens another tab or window for the person, on a model of its own; a session works in the tab it is connected to, and clear_model begins a new model there",
	"connector": "connects Claude to this tab; a session is already connected",
	"select_*": "picks parts for the person's next command; a session names parts by number (look_at_model) and reads the person's pick with selection",
	"hide": "what the person sees; view_model where= looks at one box of the model",
	"isolate": "what the person sees; view_model where= looks at one box of the model",
	"show_all": "what the person sees; view_model where= looks at one box of the model",
	"lock": "keeps the person's own mouse off parts; a session changes only the parts it names",
	"unlock": "keeps the person's own mouse off parts; a session changes only the parts it names",
	"leave_submodel": "which sub-assembly the person's mouse edits inside; a session names an assembly by its box (edit_model)",
	"enter_assembly": "which sub-assembly the person's mouse edits inside; a session names an assembly by its box (edit_model)",
	"leave_assembly": "which sub-assembly the person's mouse edits inside; a session names an assembly by its box (edit_model)",
	"rename_assembly": "a session names an assembly when it makes one (edit_model's assemblies)",
	"view_*": "the person's camera; view_model from= looks from any side",
	"mode_*": "what the person's mouse does; a session's changes are edit_model's",
	"mode_connect": "a point on the part in the person's hand, then the point it goes on, by their pointer; a session gives the place and turn (edit_model's add, at= and rot=)",
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
	"reset_panels": "the window's panels, laid out as the person left them",
	"show_properties": "the window's panels",
	"full_screen": "the window's panels",
	"split_view": "the window's panels: a second view of the person's; view_model from= looks from any side",
	"rotate_held": "the part in the person's hand; a session gives rot= and face=",
	"tip_held": "the part in the person's hand; a session gives rot= and face=",
	"find_colour": "a field the person types a colour's name into, for their next part; a session gives the LDraw colour code (edit_model's color and recolor)",
	"reseat": "squares up parts a file left between studs; a session's parts are on the lattice already",
	"settings": "the person's preferences, whether the assistant is in the window among them: theirs to choose, and with it off the connector is off, so no session is there to ask",
	"palette": "finds one of the person's commands by its words; a session calls the tool itself",
	"keys": "help for the person",
	"tour": "help for the person",
	# whatsthis: a click of the person's on a control, answered in words.
	"whats_this": "help for the person: what a control does, said where the person's next click lands",
	"website": "help for the person",
	"docs": "help for the person",
	"about": "help for the person",
	"back_to_site": "leaves the web app for the website in the person's tab, ending the session's connection",
	"feedback": "a report from the person to the people who make Brickworks, in their own words",
	# bugreport: the same, a bug's, with a picture of the window the person marks.
	"report_bug": "a report from the person to the people who make Brickworks, in their own words, with a picture of their window",
	"beta_hub": "help for the person",
	"check_updates": "the person's own copy of the app: a new version is theirs to take, and taking it restarts the app the session is driving",
	"reinstall": "puts a fresh copy of the app in place and restarts it, ending the session's connection",
	"restart": "closes and reopens the app the session is driving, ending the session's connection",
	"reference": "a picture from the person's disk, picked in a dialog, for their own eyes to build over; in_view shows a session the one laid, and a session is given its own pictures in the conversation",
	# savedviews: the views kept with the model (SavedViews); save_view is
	# save_view's (mcpsee3).
	"saved_view_*": "the person's camera; view_model view= looks from a saved view by its name, and render_model view= renders it",
	# edges (APP_UX6 #19): View › Edges and studs, how the person's own view
	# draws the plastic.
	"edges": "how the person's own view draws the parts; the pictures a session is shown (view_model) draw the plastic as it is moulded, seams and all",
	"studs": "how the person's own view draws the parts; the pictures a session is shown (view_model) draw every stud, which a session counts and places by",
}

# -- mcpreach (APP_UX8 #11): what only the person does, named where a session reads --


## The window's commands only the person runs (WINDOW_ONLY's together,
## share, import_* and comments), each named with where it is, in the words a
## session reads before it answers: read_guide("app")'s first lines and
## export_model's description, which every session is given. Asked to set up
## building with a friend, a session said "I can't set up a live session",
## because no tool's words named Build together (APP_UX8's MCP walk, n7).
## Nothing here opens one: each is the person's to decide. mcpreach_probe
## holds each "File › …" to the window's own menus.
const PERSONS_OWN := ("Only the person does these, from the window's menus, each theirs to decide, "
	+ "so no tool does them; a session sends the person to them by name and where, and never says "
	+ "they cannot be done. Build together (File › Build together…): someone else builds this "
	+ "model with the person at the same time, live, from their own computer or browser, by a "
	+ "link the person starts there and sends them; each sees the other's changes, pointer and "
	+ "chat, with an undo of their own. Share (File › Share…): a link anyone can open to see the "
	+ "model, its steps and its parts list, and in the public gallery if the person ticks it. "
	+ "Import (File › Import): a model file from their computer, LDraw, a Studio .io or an LDD "
	+ ".lxf, or a 3D model to brickify. Comments (File › Comments…, or a part's right-click menu, "
	+ "Comment on it…): a note pinned to a part for the people who build the model with them.")


## What a session reads about these, served by read_guide("app") — every
## tool here is named in it, which the sync probe checks.
const GUIDE := """THE REST OF THE APP
Besides designing, a session can do what the person does from the menus. \
Each change is one undo step.
 - """ + PERSONS_OWN + """
 - clear_model takes everything off for a new model, as New does; \
save_model writes it with the person's models, and a new design's first \
save hands back its pictures for a fresh look, answered with fresh_eyes \
before any other call, and the first save after the creative pass one \
last look, answered with fresh_eyes_final; make_part makes a part the \
LEGO Group has not made, when search_parts finds no real one that will do.
 - set_floor: what the model stands on — a baseplate 8 to 192 studs in \
eights, in a colour baseplates come in, a grid floor, or nothing (a car \
or a ship stands on a table). part_of_model=true counts the baseplate as \
a part and makes it step 1 of the booklet.
 - edit_steps: the build steps the booklet and the timeline follow. With \
no op it lists them, with find= only those that place a part ("red 3001"); \
"to" puts parts in any step by its number, "next"/"prev" \
move them a step, "new" makes a step of them, "earlier"/"later"/"merge"/\
"delete" act on a step by its number, "name" names one ("Build the cockpit").
 - booklet_layout reads the booklet's pages and how each step is printed, \
changing nothing; edit_booklet sets one step's view (turn=, tilt=, \
"usual"), zoom=, size=, page= ("new", "alone"), parts=, callout= and the \
booklet's per_page=, as the timeline's Booklet row does; place=, text=, \
arrow= and guide= lay a page out by hand; callout_step= poses a callout's step.
 - page_setup: the booklet's paper (size= "A4", "letter", "A5" or its own \
269 x 199), orientation=, margin=, colour= or picture_data= behind every \
page, number= the step numbers' height and parts= the parts boxes' scale, as \
Build, Booklet page, Page setup… does; save_as= keeps it as a style by a \
name, style= gives a kept one to this model, remove_style= takes one away.
 - page_setup's title=, subtitle=, cover_line= and cover_picture_data= make \
the cover the designer's own; header= and footer= go on every page; \
box_frame=, box_fill=, box_corners=, number_colour= and outline_colour= are \
the booklet's colours. A style keeps them all but the model's own title= \
and subtitle=.
 - lay_flex: a hose, a pneumatic tube, a flexible axle, a string or a \
chain, laid between two connectors (pin holes, axles, studs) of two parts \
by number, or round two sprockets; item= lays an existing one again.
 - pose_model: lists the joints (a sub-assembly on a hinge, a turntable \
or a clip, and a part on a click hinge a drag finds, no assembly named) and \
swings one to an angle, as far as it has room. \
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
opens one. Over changes not saved it is refused unless save_first= a file \
name saves them first or discard_changes=true, and undo brings back what it replaced. Each save is kept, the \
last 20: name= with versions=true lists a model's, version=N opens one; \
versions=true with version=N opens nothing and says what changed since that \
save, part by part, as File, Compare, Compare with… draws it. \
link= opens a copy of a gallery model, as Open in Brickworks does; \
library= opens LDraw's model of a real set (gallery library=true finds them).
 - parts_list: the model's parts by part and colour with element ids; \
which="need" what the person's collection is short of; "buildable" What \
can I build?: saved models, examples and every real set, by how much is owned.
which="compare" a= b=: any two of a set, a saved model or the open model, \
the parts in both and in one only, and what to buy to build b from a.
 - compare_with_set: what differs from a real set and where, in one call: \
each part taken away, added, swapped, recoloured, moved or in another \
sub-model, by the set's own steps, with its sub-model, line, #N and the \
edit_model call that puts it back. Read-only.
 - edit_collection: the person's own loose bricks, as My collection's What \
I own keeps them. add= lots seen in a photo of their pile (part, colour, \
count), all in one call, each marked as the session's for the person to \
keep or take back; remove= takes the session's own lots off; with neither \
it reads the collection back; missing= marks a set's missing parts, each \
change said as was N, now M. Nothing else of theirs is changed.
 - render_model: a picture or a turntable worth keeping, Quick, Good or \
Best, up to 4K, as the window draws it or as a product shot, or kind="build" \
the model built up step by step as a video, saved where Render saves; a \
turntable or a build answers with six of its frames in one picture. view= \
a view the person saved with the model, by its name, draws it from exactly \
there (view_model view= looks from it first).
 - render_queue: pictures lined up with Render's settings and drawn one \
after another while the person goes on working, as File, Render queue… \
does; list says how far each has got and where it was saved.
 - light_model: the lights kept with the model, as Render's Lights in the \
model keeps them: a spot, a bulb, a sun or a panel of light, hung over \
parts by number or placed in the file's coordinates. render_model and \
render_queue draw them; light="dark" puts the studio out, and they and the \
plastics that glow (Glow In Dark, the neons) are all that lights the model.
 - save_view keeps where the person's window looks from now with the \
model, by a name, as View › Viewpoint › Save this view… does, with a key of \
its own; remove=true takes one out. in_view lists those kept, and \
view_model, render_model and render_queue draw from one by its name (view=).
 - export_model: the model as LDraw, a BrickLink Studio .io, a 3D file \
(GLB, glTF, OBJ, STL, 3MF), a picture, a BrickLink wanted list, a Rebrickable \
parts list, a LEGO® Pick a Brick list, or the building instructions as a \
booklet (instructions) or as the PDF the Instructions window prints (pdf), \
written where Export writes; all_models is every saved model in one .zip. An \
STL's or a 3MF's answer says whether each object is a closed solid, as a \
slicer needs it, and names any part that is not. Nothing is written over: a \
file of the name already there is kept, the new one takes the next free \
name (pods_render_2.png), and the answer gives it.
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
 - The window's hand tools on parts by number, each one undo step: \
mirror_parts as Mirror, in place or copy=true beside them, \
across= a plane (copy=true across=0 makes a left half the right half), \
handed parts swapped for their other hand; split_parts as Split and \
merge_parts as Merge, by Studio's rules, on the same studs. \
measure, read-only: the distance and the angle between two connectors \
("#12.hole[1]") or points, as Measure says them, and two halves of one \
joint with the turn between them as attach's yaw. in_view, read-only: what \
the person sees and a session is not told — the step the timeline is at, \
the part in their hand, and the reference picture they build over, with a \
picture of it; the model's size in studs and centimetres and its weight \
in grams, as the status bar says them; and the views saved with the model.
 - view_board, read-only: up to six of view_model's views in one labelled \
picture; highlight= parts edged in magenta with the rest see-through, xray= \
parts see-through so what they hide shows (each by number, part number \
3024 as text, colour red or step:3), step=N the model as built to step N with \
its new parts edged, studs=true each part coloured by where its studs point. booklet_page, read-only: a page of the booklet as \
Instructions draws it and its PDF prints it, to see what edit_booklet did. \
mirror_parts, split_parts and merge_parts answer with the change pictured, as \
edit_model does (picture=true the whole model, false words alone).
 - pattern_parts: Edit, Pattern…'s grid on parts by number, in one call: \
columns along x, rows along z and levels up (a row is one row and one level), \
column_studs= and row_studs= apart in studs, level_plates= in plates, each the \
parts' own size when not given, so copies touch. Every copy checked for room, \
all or nothing, one undo step; a copy with no room is said by its column, row \
and level and the part in its way. Answered with the copies pictured.
 - weakest_joints: what gives first in the whole model as it stands, \
read-only, as View, Stress weighs it: each joint that alone holds what is \
past it, weakest first, with its margin against its studs' working load, \
and for each past or near it the fewest parts that fix it as an edit_model \
call to make as given. Ask it what breaks first, rather than rebuilding the \
model in check_design.
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
 - palettes, read-only: the person's own palettes, as the parts bin's \
Palettes keeps them for every model: parts in their colours and \
sub-assemblies. edit_palette makes one (make), keeps more in it (add: \
bricks= parts of the model, parts= by number and colour, from= the model or \
the selection, assembly= a sub-assembly whole), take_out, rename and delete \
as the bin's rows do, and place puts a kept sub-assembly down in the model \
whole, at= where its low corner goes, one undo step.
 - job: what takes long on a big model (render_model, animate_model's \
rendering, render_motion, export_model's studio, picture and instructions, make_art, \
brickify) \
answers at once with a job number while it works in the app. job {"id": N} \
waits up to 45 s for it to end, then says how far it has got, or gives its \
answer the moment it is done; call it again until then. cancel=true stops \
it. Nothing else can be done in the app while a job runs.
 - point_at: in a Build together session (the person and others building one model live, each in their own window), points parts out to everyone in it, as the person's Alt-W does: outlined in the person's colour on every screen for 5 seconds, named as the person's Claude. part= a number from look_at_model, or parts= several. Changes nothing. Out of a session it says so: the person starts or joins one from File › Build together….
 - replace_parts: Find and Replace, as Edit › Find and replace… does, in one call and one \
undo step: find= a part, a colour or both, replace= another part, colour or both, where= \
"all" (every sub-model and every copy of one), "submodel" or "selection". It lists where \
they are and in which colours, and says where a new part will not sit the same. rare=true \
lists the lots hard to buy (3 sets or fewer) and swaps those whose common swap keeps the look, \
as the parts list's rare row; lots= swaps any named."""


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
				+ "them with the part numbers in each; \"to\" puts bricks= in step=, however "
				+ "far, as the person drags them onto a step (a step= past the last makes a new "
				+ "last step of them); \"next\" or \"prev\" moves bricks= a step later or earlier, "
				+ "and on from the last step makes a new one; \"new\" makes a new step of bricks=; "
				+ "\"earlier\", "
				+ "\"later\", \"merge\" (with the next) and \"delete\" act on step=, a number "
				+ "from the list. A model with no steps of its own is given the worked-out "
				+ "ones first, in the same undo step."
				# stepnames: a step named, in a block of its own.
				+ " \"name\" gives step= a name= (\"Build the cockpit\"), said beside its "
				+ "number on the timeline, in Build it and in the booklet; name= \"\" takes it "
				+ "off. callout_step= with step= names a step inside the callout step= puts on. "
				+ "A sub-model placed more than once has one set of steps: a name given to one "
				+ "of its steps is every copy's."
				# stepsearch: the steps that place a part, as the timeline's find.
				+ " find= lists only the steps that place a part, by its number, name or "
				+ "colour or both (\"red 3001\", \"2x4 brick\"), as the timeline's find does; "
				+ "a part in a sub-model is found in the sub-model's own step that puts it on."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"op": {"type": "string", "enum": ["list", "to", "next", "prev", "new", "earlier",
					"later", "merge", "delete", "name"]},
				"name": {"type": "string", "description": "for name: what the step is called, up to 80 characters; \"\" takes it off"},
				"callout_step": {"type": "integer", "description": "for name: a step inside the callout step= puts on, from 1, as edit_booklet takes it"},
				"bricks": {"type": "array", "items": {"type": "integer"},
					"description": "part numbers from look_at_model, for to, next, prev and new"},
				"step": {"type": "integer", "description": "a step's number, for to, earlier, later, merge, delete and name"},
				"from": {"type": "integer", "description": "list from this step; 1 when omitted"},
				"find": {"type": "string", "description": "for list: only the steps that place this part: a number (3001), a name (brick 2 x 4), a colour (red) or both (red 3001)"},
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
				+ "unoutlined in the whole booklet. callout_step= with step= is a step inside the "
				+ "callout that step puts on, from 1: turn= and tilt= pose it apart, from the "
				+ "way the callout faces. The page by hand, one undo step each and "
				+ "alone in a call: place= moves an item of the step's page to x, y (and w, h) "
				+ "in mm on the page (269 x 199 unless page_setup set it up), as dragging it on Lay out the page does "
				+ "(item picture, parts, callout or number; note with index= for words or a "
				+ "picture added, turn= degrees clockwise and opacity= percent turning and fading it; "
				+ "remove=true takes a note off, back=true puts an item back "
				+ "where the booklet lays it); text= puts words on the step's page; arrow= draws "
				+ "an arrow on it, from x1, y1 to x2, y2, bent through bends= [[x, y], ...] if given, "
				+ "red (where a part goes in) or black, 0.45, 0.9 or 1.4 mm wide, or with index= "
				+ "changes, bends or removes one; guide= {axis x (upright) or y (across), at mm} "
				+ "lays a guide on every page, which what is dragged snaps to, never printed "
				+ "(was= moves one, remove=true takes it off). What is placed goes with its step when the pages change. "
				+ "booklet_layout says where each is, and what was moved off what it overlapped. "
				+ "follow=true lays out every later page with as many steps as the page step= "
				+ "is on, as that page is laid out (Apply to later pages), one undo step. "
				+ "Studio's extras: pull= studs (2 when true, 0 or false to put back) draws "
				+ "the step's parts, or {studs, parts: [part ids]} those, pulled out along the "
				+ "way each goes in with a red arrow in; colours= true lists the step's colours "
				+ "under its number (colours_all= true every step's); actual_size= false leaves "
				+ "off the 1:1 guide the booklet gives the first Technic axle or straight beam "
				+ "of each length, true gives every axle and beam of the step one, [part ids] "
				+ "those parts, \"auto\" as the booklet does it; preview= false leaves the "
				+ "finished sub-assembly off the first of its own pages. "
				+ "A model with no steps of its own is given the "
				+ "worked-out ones first, in the same undo step."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["step"], "properties": {
				"step": {"type": "integer"},
				"callout_step": {"type": "integer", "description": "a step inside the callout step= puts on, from 1"},
				"highlight": {"type": "boolean"},
				"place": {"type": "object", "description": "{item, x, y, w, h, index, turn, opacity, remove}: w and h kept when omitted",
					"properties": {
						"item": {"type": "string", "enum": ["picture", "parts", "callout", "number", "note"]},
						"x": {"type": "number"}, "y": {"type": "number"},
						"w": {"type": "number"}, "h": {"type": "number"},
						"index": {"type": "integer", "description": "which note, from 0, for item note"},
						"turn": {"type": "number", "description": "item note: degrees clockwise about its middle, -180 to 180"},
						"opacity": {"type": "number", "description": "item note: percent, 5 to 100"},
						"remove": {"type": "boolean"},
						"back": {"type": "boolean", "description": "true: where the booklet lays it out again"}}},
				"text": {"type": "object", "description": "{words, x, y, w, h, size}: mm, size the letters' height (4 when omitted)",
					"properties": {
						"words": {"type": "string"},
						"x": {"type": "number"}, "y": {"type": "number"},
						"w": {"type": "number"}, "h": {"type": "number"},
						"size": {"type": "number"}}},
				"arrow": {"type": "object", "description": "{x1, y1, x2, y2, bends, colour, width, index, remove}: mm; colour red or black, width 0.45, 0.9 or 1.4; index= an arrow of the step's page to change (bends= alone keeps its ends), remove=true to take it off",
					"properties": {
						"x1": {"type": "number"}, "y1": {"type": "number"},
						"x2": {"type": "number"}, "y2": {"type": "number"},
						"bends": {"type": "array", "items": {"type": "array", "items": {"type": "number"}},
							"description": "[[x, y], ...]: the points it bends through, in order, up to 12; [] straightens it"},
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
				"follow": {"type": "boolean", "description": "true: the later pages laid out as step's page is"},
				"pull": {"description": "studs to pull the step's parts out (true: 2; 0 or false: put back), or {studs, parts: [the step's brick numbers or part ids]}"},
				"colours": {"type": "boolean", "description": "true: the step's colours listed under its number"},
				"colours_all": {"type": "boolean", "description": "true: every step's colours listed"},
				"actual_size": {"description": "the step's 1:1 guides: false none, true every axle and beam, [part ids] those parts, \"auto\" as the booklet does it"},
				"preview": {"type": "boolean", "description": "false: no finished sub-assembly before its own pages"},
				"guide": {"type": "object", "description": "{axis, at, was, remove}: mm from the page's left (x) or top (y)",
					"properties": {
						"axis": {"type": "string", "enum": ["x", "y"]},
						"at": {"type": "number"},
						"was": {"type": "number", "description": "where the guide to move or take off is"},
						"remove": {"type": "boolean"}}},
			}},
		},
		# pagesetup: the booklet's page, the person's way (BookletSheet).
		{
			"name": "page_setup",
			"description": ("The booklet's page, as Build, Booklet page, Page setup… sets it, "
				+ "for the whole booklet and its PDF: size= \"booklet\" (its own 269 x 199 mm), "
				+ "\"A4\", \"letter\" or \"A5\"; orientation= \"portrait\" or \"landscape\"; "
				+ "margin= mm; colour= the page's colour (\"#ffffff\", \"usual\" its light blue); "
				+ "picture_url= or picture_data= (base64) a picture behind every page, picture= "
				+ "\"none\" takes it off; number= the step numbers' height in mm (8 usual); parts= "
				+ "the parts boxes' pictures' size (1 usual, 0.5 to 2); usual=true the booklet's own "
				+ "page again. save_as= keeps the page as a style by that name, style= gives "
				+ "this model a kept style, and remove_style= takes a kept style away. One "
				+ "undo step, saved with the model. With nothing, says how the page is set up, "
				+ "its picture's size in the file, and the styles kept. "
				# booklook: the booklet the designer's way.
				+ "The cover: title= (the model's name when none), subtitle= under it, "
				+ "cover_line= a line of their words on it, cover_picture_url= or "
				+ "cover_picture_data= a picture of their own (cover_picture= \"model\" the "
				+ "model drawn again). header= and footer= words on every page (\"\" none). "
				+ "box_frame=, box_fill= and box_corners= (mm) the parts box, number_colour= "
				+ "the step numbers, outline_colour= the band round the new parts; a colour "
				+ "\"usual\" is the booklet's own. A style keeps all of these but title= and "
				+ "subtitle=, which stay each model's own: style= never changes them."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"size": {"type": "string", "enum": ["booklet", "A4", "letter", "A5"]},
				"orientation": {"type": "string", "enum": ["portrait", "landscape"]},
				"margin": {"type": "number", "description": "mm, 5 to 30 (9 usual)"},
				"colour": {"type": "string", "description": "\"#rrggbb\", or \"usual\""},
				"picture_url": {"type": "string", "description": "an http(s) link to a picture"},
				"picture_data": {"type": "string", "description": "a picture's own bytes, base64"},
				"picture": {"type": "string", "enum": ["none"]},
				"number": {"type": "number", "description": "mm, 4 to 20"},
				"parts": {"type": "number", "description": "0.5 to 2"},
				"usual": {"type": "boolean"},
				"style": {"type": "string", "description": "a style kept by save_as=, given whole but the model's own title and subtitle"},
				"save_as": {"type": "string", "description": "keep the page as a style by this name"},
				"remove_style": {"type": "string", "description": "a style kept by save_as=, taken away"},
				# booklook: the cover, the words on every page, the booklet's colours.
				"title": {"type": "string", "description": "the cover's title, \"\" the model's name"},
				"subtitle": {"type": "string", "description": "a line under the title"},
				"cover_line": {"type": "string", "description": "a line of words on the cover"},
				"cover_picture_url": {"type": "string", "description": "an http(s) link to a picture for the cover"},
				"cover_picture_data": {"type": "string", "description": "the cover's picture's own bytes, base64"},
				"cover_picture": {"type": "string", "enum": ["model"]},
				"header": {"type": "string", "description": "words at the head of every page"},
				"footer": {"type": "string", "description": "words at the foot of every page"},
				"box_frame": {"type": "string", "description": "\"#rrggbb\", or \"usual\""},
				"box_fill": {"type": "string", "description": "\"#rrggbb\", or \"usual\""},
				"box_corners": {"type": "number", "description": "mm, 0 to 8 (2.2 usual)"},
				"number_colour": {"type": "string", "description": "\"#rrggbb\", or \"usual\""},
				"outline_colour": {"type": "string", "description": "\"#rrggbb\", or \"usual\""},
			}},
		},
		{
			"name": "lay_flex",
			"description": ("Lay a hose, tube, string or chain, as Make, Hose, tube or chain "
				+ "does: kind ribbed_hose, pneumatic_tube, flex_hose or flex_axle between two "
				+ "parts' pin holes, axles or pins; string between two studs; chain or tread "
				+ "round sprockets= (two or more gears in one plane). The real length that "
				+ "fits is chosen, and it bends no tighter than the real one can. It goes in "
				+ "as one sub-assembly, named in the answer; item= that name lays it again "
				+ "between new ends. band: a rubber belt round sprockets= (pulleys, wheels, "
				+ "bushes or axles, in order round the loop); spring: between from= and to=, "
				+ "its turns kept when a part it is on moves. part= picks the band, the "
				+ "spring or the shock absorber by number."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["kind"], "properties": {
				"kind": {"type": "string", "enum": FlexTool.KIND_ORDER},
				"from": end, "to": end,
				"sprockets": {"type": "array", "items": {"type": "integer"},
					"description": "part numbers of the gears a chain or tread goes round"},
				"color": {"type": "integer", "description": "LDraw colour; black when omitted"},
				"item": {"type": "string", "description": "a hose already laid, by its name in an earlier answer"},
				"part": {"type": "string", "description": "a band, spring or shock absorber's number (85546, 73129)"},
			}},
		},
		{
			"name": "pose_model",
			"description": ("Swing a part about its joint, as Build, Pose does: a sub-assembly "
				+ "on a hinge, a turntable or a clip on a bar, or on a ball (three joints: its "
				+ "turns about x, y and z through the ball); and a part on a click hinge, a hinge "
				+ "or a turntable as a drag finds it, with no assembly named on it. With no joint "
				+ "it lists them, numbered, with the angle each is at. joint= (number or name) and degrees= "
				+ "(from where it was built, -180 to 180) swings it as far as it has room; the "
				+ "answer says where it stopped if something is in the way, and whether the pose "
				+ "holds its own weight: each friction joint (a Technic ball, a friction pin) "
				+ "that droops under what hangs on it, with the share it holds, and the joints "
				+ "whose hold nobody has measured. lock=true locks the joint (after degrees=, if "
				+ "given): it keeps its angle and its slide, and a drag of either part, R, a handle, "
				+ "Simulate's driver, move_part and pose_model are refused until lock=false unlocks "
				+ "it; saved with the model, and the answer says what a turn of it now does (it tries "
				+ "one). A model with one joint needs no joint= and no list first: {\"lock\": true} "
				+ "locks it, {\"degrees\": 45, \"lock\": true} sets it and locks it there. A drag's "
				+ "joint may be named by a part of it (#12)."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"joint": {"type": "string", "description": "its number or name in the list"},
				"degrees": {"type": "number"},
				"lock": {"type": "boolean", "description": "true locks the joint where it stands "
					+ "(after degrees=); false unlocks it (before degrees=)"},
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
				"picture": {"type": "boolean", "description": "true: the whole model pictured after the move (a ball's turn seen along its axis), what moved edged; left out, words alone"},
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
				+ "left the model, backwards in reverse order. Or path= the whole model driven along "
				+ "the ground (legs: straight studs, left or right degrees), its wheels turning as they "
				+ "roll and its steering into the corners. suggested=true keeps list_motions' "
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
				# unit drive: the whole model driven along a path, its wheels turning.
				"path": {"type": "object", "additionalProperties": false, "description": ("the whole model "
					+ "driven along the ground from where it stands, its wheels turning as they roll and its "
					+ "steering into the corners; with tracks= too, those joints move as it goes"), "properties": {
						"legs": {"type": "array", "description": ("in order; a 32-stud straight and a quarter "
							+ "turn left when omitted"), "items": {"type": "object", "additionalProperties": false,
							"properties": {
								"straight": {"type": "number", "description": "studs ahead; less than 0 backwards"},
								"left": {"type": "number", "description": "degrees turned to the left"},
								"right": {"type": "number", "description": "degrees turned to the right"},
								"radius": {"type": "number", "description": ("a turn's radius, studs, at the "
									+ "middle of the back axle; the tightest its steering takes well when omitted")},
							}}},
						"seconds": {"type": "number", "description": "how long; at 10 studs a second when omitted"},
						"eased": {"type": "boolean", "description": "gathers speed and slows to a stop; true when omitted"},
					}},
				# end unit drive
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
				+ "and is a job (job gives the result, with six of its frames in one picture, the "
				+ "first and the last among them)."),
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
				+ "(24) as a WebP and an MP4 where Render saves, as a job (job gives the result). "
				+ "program= sets the program for the model's motors (kept in its file; undo takes "
				+ "it back; \"\" takes it out) and runs it in the same call, as Simulate's Run "
				+ "does: each motor at its rated speed, each move stopped where a part meets "
				+ "another or the motor stalls under its load, said move by move with a picture "
				+ "where it ended. A line each: to 90° at 50% (to an angle from where it was "
				+ "built), turn -45° at 30%, run 40% for 2 s, wait 1 s, repeat 3 (the lines "
				+ "indented under it); with two hub motors or more, each line begins with its "
				+ "port, A to F."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"driver": {"type": "string", "description": "a part's number from look_at_model, or a sub-assembly's name"},
				"reference": {"type": "string", "description": "the turning part periods are counted in: a number or a name"},
				"targets": {"type": "object", "description": "name -> the period wanted, in the reference's turns",
					"additionalProperties": {"type": "number"}},
				"frames": {"type": "integer", "description": "frames in a recording, 2 to 240; 24 when omitted"},
				"turns": {"type": "number", "description": "turns of the reference (or the driver) a recording covers; 1 when omitted"},
				"record": {"type": "boolean"},
				"program": {"type": "string", "description": "the program for the model's motors, its lines joined by \\n, set and run at once; \"\" takes it out"},
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
				+ "version=N opens the Nth; versions=true with version=N opens nothing and says "
				+ "what changed in the model open now since that save, as Compare draws it: "
				+ "each part added, removed, moved or turned, and recoloured, by number. "
				+ "link= a gallery model's link id (gallery) opens a "
				+ "copy of it saved in the person's models, as Open in Brickworks on its page "
				+ "does. library= an id from gallery library=true (\"omr-10179-1\") opens LDraw's "
				+ "model of that real set, credited to whoever made it, as File, Library… does. "
				+ "The person's work is never lost: while the model on the baseplate has "
				+ "changes not saved, opening is refused unless save_first= a file name saves "
				+ "it first, as the window's Save on Save changes? does, or discard_changes=true, "
				+ "and an open is undone like any change (undo brings back the model it replaced). "
				+ "into=true puts name= (or library=, link=) into the model open now as one "
				+ "sub-assembly with its author's steps, beside the model or at x= z=, as File, "
				+ "Import, Into this model… does: nothing is replaced, every part and name of "
				+ "both kept, and one undo takes it out. "
				# movedparts (APP_UX8 #15).
				+ "The answer names each part the file gives by a number LDraw has moved or "
				+ "keeps as an alias, with the part it points to, and each it has no file for, "
				+ "with counts; replace_moved=true writes the moved and alias ones as those "
				+ "parts in every sub-model, as one step to undo, as the person's Update all "
				+ "does: with name=, link= or library= as it opens, alone in the model open now."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"name": {"type": "string", "description": "a model's name from the list"},
				"replace_moved": {"type": "boolean", "description": "write each part the file names by a moved or alias number as the part it points to, in every sub-model, as one step to undo; with name=, link= or library= as it opens, alone in the model open now"},
				"link": {"type": "string", "description": "a gallery model's link id, or its /m/ address"},
				"library": {"type": "string", "description": "a library id from gallery library=true, like omr-10179-1, or a set's number or name"},
				"versions": {"type": "boolean", "description": "list name='s saves kept as versions"},
				"version": {"type": "integer", "description": "open this save of name=, 1 the newest; with versions=true, compare the model open now with it"},
				"discard_changes": {"type": "boolean"},
				"save_first": {"type": "string", "description": "a file name, such as car.ldr: the model on the baseplate is saved in the person's models under it first, as save_model saves, and then opened over"},
				"into": {"type": "boolean", "description": "put name= (or library=, link=) into the model open now as one sub-assembly with its own steps, as File, Import, Into this model… does, in place of opening it; nothing is replaced"},
				"x": {"type": "number", "description": "with into: studs across to its low corner, on the ground; beside the model when omitted"},
				"z": {"type": "number", "description": "with into: studs deep to its low corner"},
				"turn": {"type": "integer", "description": "with into: quarter turns about the vertical, 0 to 3"},
			}},
		},
		{
			"name": "parts_list",
			"description": ("The model's parts, as Build, Parts list shows them: by part and "
				+ "colour, with counts and LEGO® element ids. which=\"need\" measures it "
				+ "against the person's collection (My collection): how much they own and "
				+ "what they are short of; which=\"buildable\" is What can I build?: their "
				+ "saved models, the examples and the official models of real sets, and in a "
				+ "block of its own every real set Rebrickable lists, each ranked by how much of "
				+ "it they own. "
				# comparesets (APP_UX6 #7): Rebrickable's set compare.
				+ "which=\"compare\" is File, Compare, Compare two sets or models…: a= and b= each a "
				+ "set number (\"7140\"), a saved model's or an example's name, or \"open\" for "
				+ "the model open now; it says the parts in both and in only one, by part and "
				+ "colour, each side's pieces counted once, and what to buy to build b from a. "
				+ "shop= bricklink, rebrickable or pickabrick also writes that list to buy for "
				+ "the shop, as export_model writes the model's."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"which": {"type": "string", "enum": ["model", "need", "buildable", "compare"]},
				"limit": {"type": "integer", "description": "how many rows; 60 when omitted (compare: 30 a list)"},
				"a": {"type": "string", "description": "compare: what is had, a set number, a saved model's or example's name, or \"open\"; \"set 1234\" or \"model 1234\" where a name is a number"},
				"b": {"type": "string", "description": "compare: what is to be built, as a="},
				"shop": {"type": "string", "enum": ["bricklink", "rebrickable", "pickabrick"],
					"description": "compare: write the list to buy to build b from a for this shop, where export_model writes"},
			}},
		},
		# mybricks (APP_UX5 #2): the person's loose bricks, from a photo of
		# their pile, in one call.
		{
			"name": "edit_collection",
			"description": ("The person's own bricks, as Build, My collection's What I own "
				+ "keeps them with their account: sets, and loose parts by part, colour and "
				+ "count. add=[{part, color, count}] adds loose lots, all in one call: given a "
				+ "photo of their pile, look at it closely, name each part (its LDraw number, "
				+ "as search_parts gives it; a BrickLink number is read too) and its LDraw "
				+ "colour code, count each, and add them together. Every lot added is marked "
				+ "as this chat's and listed for the person apart from their own, to keep or "
				+ "take back with one button. remove=[{part, color, count}] takes pieces off "
				+ "lots this chat added (count omitted: the whole lot). With neither, it reads "
				+ "the collection back, this chat's lots apart. Their sets and their own lots "
				+ "are theirs: add= and remove= never change them; missing= changes only the marks it "
				+ "names, each said as was N, now M. parts_list which=\"need\" then measures "
				+ "the model against it, and which=\"buildable\" ranks what they can build. "
				# localbricks (APP_UX6 #8): a set's marks.
				+ "missing={set, lots: [{part, color, count}]} puts how many of each named part a set they "
				+ "own is missing to count, all its copies together (0 unmarks it), as its Missing parts… "
				+ "page does; the reply says each change as was N, now M, to put back. none=true says a set "
				+ "has nothing missing: refused while anything is marked, naming it; then name those lots, "
				+ "count 0, or send none=true with marked= the number of lots it said, to unmark them all. "
				+ "Send missing= alone, not with add= or remove=. What do I need?, the pool and a bin built "
				+ "from the set then count only what is there. "
				# keptbuilt (APP_UX9 #6): a set kept built on a shelf.
				+ "built=[\"7140-1\"] marks each set they own as kept built on a shelf, every copy of it, as "
				+ "its Built mark in My collection does: its parts are then left out of What can I build?, "
				+ "My bricks, parts_list need and submit_design mine=true (its spares still count). "
				+ "{set, copies} marks that many of its copies; copies 0 takes it apart. The reply says "
				+ "each as was N, now M, to put back. Send built= alone, or with sets=. "
				# mcpreach3 (APP_UX10's r5): a set added by its number.
				+ "sets=[\"31058-1\"] adds a copy of each set to their collection, as Add a set in My "
				+ "collection does, its parts from the set's inventory; with built= naming it too, it is "
				+ "added and marked kept built in one call. The reply says each set's copies, was and now, "
				+ "their loose parts and the pieces on hand to build with. "
				# partplaces (APP_UX9 #14): where each part is kept.
				+ "place=[{part, color, place}] says where they keep each part and colour (a drawer, a box, a "
				+ "tray, as they name it: \"drawer 3\"), all in one call, for parts their collection holds (a "
				+ "loose lot, or in a set of theirs); place \"\" takes one off. The parts list then sorts by "
				+ "it and the booklet's parts boxes say \"from drawer 3\". The reply says each as was, now, to "
				+ "put back. Send place= alone."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"add": {"type": "array", "description": "loose lots to add", "items": {
					"type": "object", "additionalProperties": false, "required": ["part", "color", "count"],
					"properties": {
						"part": {"type": "string", "description": "the part's LDraw number, like 3001"},
						"color": {"type": "integer", "description": "LDraw colour code, like 4 for Red"},
						"count": {"type": "integer", "description": "how many, 1 or more"},
					}}},
				"remove": {"type": "array", "description": "pieces to take off lots this chat added", "items": {
					"type": "object", "additionalProperties": false, "required": ["part", "color"],
					"properties": {
						"part": {"type": "string"},
						"color": {"type": "integer"},
						"count": {"type": "integer", "description": "how many to take off; the whole lot when omitted"},
					}}},
				"limit": {"type": "integer", "description": "how many lots the read back lists; 60 when omitted"},
				# localbricks (APP_UX6 #8): a set's missing lots marked and unmarked.
				"missing": {"type": "object", "additionalProperties": false, "required": ["set"],
					"description": "a set they own, and how many of each of its parts are missing", "properties": {
						"set": {"type": "string", "description": "the set's number, like 7140-1"},
						"lots": {"type": "array", "items": {"type": "object", "additionalProperties": false,
							"required": ["part", "color", "count"], "properties": {
								"part": {"type": "string", "description": "the part's LDraw number, as the set's inventory lists it"},
								"color": {"type": "integer", "description": "LDraw colour code"},
								"count": {"type": "integer",
									"description": "how many of it are missing, all the set's copies together; 0 unmarks it"},
							}}},
						"none": {"type": "boolean",
							"description": "the set has nothing missing; refused while any lot is marked (name those, count 0, or send marked=)"},
						"marked": {"type": "integer",
							"description": "with none=true: how many lots its refusal said were marked; all of them unmarked while that is still so"},
					}},
				# keptbuilt (APP_UX9 #6): sets kept built on a shelf, or taken apart.
				"built": {"type": "array", "description": "sets they keep built on a shelf: a set number marks every copy built; {set, copies} that many (0 takes it apart)",
					"items": {"anyOf": [{"type": "string", "description": "a set's number, like 7140-1: every copy of it kept built"},
						{"type": "object", "additionalProperties": false, "required": ["set", "copies"], "properties": {
							"set": {"type": "string", "description": "the set's number, like 7140-1"},
							"copies": {"type": "integer", "description": "how many of its copies are kept built; 0 takes it apart"},
						}}]}},
				# mcpreach3: sets added by number, as My collection's Add a set.
				"sets": {"type": "array", "description": "sets to add, a copy each, by number, like [\"31058-1\"], as Add a set in My collection; with built= naming them, added and marked built at once",
					"items": {"type": "string", "description": "a set's number, like 31058-1"}},
				# partplaces (APP_UX9 #14): where each part and colour is kept.
				"place": {"type": "array", "description": "where they keep parts: each part and colour in a place they name",
					"items": {"type": "object", "additionalProperties": false, "required": ["part", "color", "place"],
						"properties": {
							"part": {"type": "string", "description": "the part's LDraw number, like 3001 (a BrickLink number is read too)"},
							"color": {"type": "integer", "description": "LDraw colour code, like 4 for Red"},
							"place": {"type": "string", "description": "where it is kept, at most 40 characters, like \"drawer 3\"; \"\" takes it off"},
						}}},
			}},
		},
		{
			"name": "render_model",
			"description": ("Render the model as File, Render does: a picture, a turntable "
				+ "(a WebP and, where ffmpeg is installed, an MP4), or build: the model built up "
				+ "as a video, the timeline's steps one after another, each step's parts coming "
				+ "down into place and the camera turning slowly round, over seconds (10 to 60, "
				+ "20 when omitted), as Render's Building does; on a studio sweep with soft "
				+ "shadows. quality quick, good or best (good for a picture, quick for a "
				+ "turntable or a build when omitted); size 720p, 1080p, 4k or square (720p for "
				+ "a turntable or a build); view hero, "
				+ "front, side, back, low or top, or the name of a view the person saved with "
				+ "the model (View › Viewpoint), drawn from exactly there; a name it does not "
				+ "keep is answered with those it does. look product is a product shot's: glossy "
				+ "plastic with rounded edges, clear parts that bend the light, a key, fill "
				+ "and rim over a softbox studio (window, the default, is the window's own). "
				# lineart (APP_UX7 #22).
				+ "look lineart is the model inked: black lines round it, where each part meets "
				+ "the next and where a part turns a corner, on white, the shade in halftone dots; "
				+ "comic the same lines and dots over each part's own flat colour; with backdrop "
				+ "none on nothing. "
				+ "backdrop white, gradient, grey, dark or none (as Render last had it when "
				+ "omitted). depth_of_field blurs what is nearer and farther than the "
				+ "model's middle, as a lens at f/4 does, and is drawn at best. light studio "
				+ "(the window's three lights, the default), softbox, window or daylight "
				+ "(photographed places), or dark: the studio put out, the model's own lights "
				+ "(light_model) and the plastics that glow all that lights it. Saved where "
				+ "Render saves, never over a file: one of the name already there is kept and "
				+ "the new one takes the next free name (pods_render_2.png), which the answer "
				+ "gives. It is a job: the answer is a job number at once, and job "
				+ "gives the result: a picture with it, or a turntable's or a build's six frames "
				+ "in one picture, the last its end. Needs the app in a window."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"kind": {"type": "string", "enum": ["picture", "turntable", "build"]},
				"seconds": {"type": "integer", "description": "a build's length, 10 to 60; 20 when omitted"},
				"quality": {"type": "string", "enum": ["quick", "good", "best"]},
				"size": {"type": "string", "enum": ["720p", "1080p", "4k", "square"]},
				"view": {"type": "string", "description": "hero, front, side, back, low or top, or a view saved with the model, by its name"},
				"look": {"type": "string", "enum": RenderSettings.LOOKS.keys()},
				"backdrop": {"type": "string", "enum": ["white", "gradient", "grey", "dark",
					"none"]},
				"depth_of_field": {"type": "boolean"},
				# lights (APP_UX5 #7).
				"light": {"type": "string", "enum": ["studio", "softbox", "window", "daylight",
					"dark"]},
				# video2 (APP_UX6 #11).
				"format": {"type": "string", "enum": ["webp", "gif"], "description": "a turntable's or a build's file: webp, or gif for where a WebP is not taken (chats, forums, mail): 256 colours, at most 640 pixels across, made to fit 8 MB. As Render's Kept as has it when omitted"},
			}},
		},
		{
			"name": "render_queue",
			"description": ("Pictures lined up and drawn one after another while the person "
				+ "goes on working, as File, Render queue… does. action add queues the "
				+ "model and the view as they are now (view current, the window's, unless "
				+ "another is given: view= may name a view saved with the model, drawn from "
				+ "exactly there), with Render's settings changed by quality, size, "
				+ "samples (Best's, 1 to 4096), view, look, backdrop, depth_of_field and light as "
				+ "render_model takes them; drawing begins at once unless paused, and each is "
				+ "saved where Render saves under a name of its own. list (the default) says "
				+ "what is waiting, being drawn and done, with where each was saved, and "
				+ "changes nothing; number=N with it shows that finished picture. pause holds "
				+ "the rest after the one being drawn, go_on carries on, finish_now keeps the "
				+ "one being drawn as clean as it is (a path-traced picture), cancel number=N "
				+ "takes one out or stops it, clear forgets the finished. Best is path traced "
				+ "where the graphics card traces rays, and frames averaged where it does "
				+ "not, and the answer says which. Needs the app in a window."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"action": {"type": "string", "enum": ["add", "list", "pause", "go_on",
					"finish_now", "cancel", "clear"]},
				"number": {"type": "integer", "description": "which render, as list numbers them"},
				"quality": {"type": "string", "enum": ["quick", "good", "best"]},
				"size": {"type": "string", "enum": ["720p", "1080p", "4k", "square"]},
				"samples": {"type": "integer", "description": "Best's samples, 1 to 4096"},
				"view": {"type": "string", "description": "current, hero, front, side, back, low or top, or a view saved with the model, by its name"},
				"look": {"type": "string", "enum": RenderSettings.LOOKS.keys()},
				"backdrop": {"type": "string", "enum": ["white", "gradient", "grey", "dark",
					"none"]},
				"depth_of_field": {"type": "boolean"},
				# lights (APP_UX5 #7).
				"light": {"type": "string", "enum": ["studio", "softbox", "window", "daylight",
					"dark"]},
			}},
		},
		# lights (APP_UX5 #7): the lights kept with the model (SceneLights).
		{
			"name": "light_model",
			"description": ("The lights kept with the model, as Render's Lights in the model "
				+ "keeps them: a spot over a cockpit, a bulb in a lamp post, a low sun, a panel "
				+ "of light over a room. render_model and render_queue draw them over the "
				+ "studio in every quality, and with light=dark they and the plastics that "
				+ "glow are all that lights the model. With no op it lists them, numbered, and "
				+ "changes nothing. op add puts one in: kind spot (the default), point (a "
				+ "bulb), directional (a sun) or area (a square panel of light), set over the "
				+ "parts numbered in over= (look_at_model numbers them; the whole model when "
				+ "omitted) as a photographer first sets one, or placed by at= and aim=. op "
				+ "change changes light number= (any of over, at, aim, colour, strength, cone, "
				+ "size, shadows); op remove takes light number= out. at and aim are in LDU in "
				+ "the file's coordinates, LDraw's: y down, so a light above the model has a "
				+ "smaller y than its top, and aim [0, 1, 0] shines straight down. strength 1 "
				+ "lights a face 100 LDU from a lamp, or any face turned to a sun, as the "
				+ "window's key light does, and a lamp lights four times as brightly at half "
				+ "the distance. cone is a spot's whole angle in degrees, 2 to 160; size a "
				+ "bulb's radius or a panel's side in LDU. At most 8, 4 of them suns (the "
				+ "studio's three lights, its sky and four suns are the eight a renderer draws). "
				+ "Kept in the model's file, saved with it, not an undo step."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"op": {"type": "string", "enum": ["list", "add", "change", "remove"]},
				"number": {"type": "integer", "description": "which light, from 1, as list numbers them"},
				"kind": {"type": "string", "enum": ["spot", "point", "directional", "area"]},
				"over": {"type": "array", "items": {"type": "integer"},
					"description": "the parts' numbers to hang the light over, shining down on them"},
				"at": {"type": "array", "items": {"type": "number"}, "minItems": 3, "maxItems": 3,
					"description": "where it is, [x, y, z] in LDU, the file's coordinates (y down)"},
				"aim": {"type": "array", "items": {"type": "number"}, "minItems": 3, "maxItems": 3,
					"description": "the way it shines, [x, y, z], the file's coordinates (y down)"},
				"colour": {"type": "string", "description": "#rrggbb; a warm white, #fff1d6, when omitted"},
				"strength": {"type": "number", "description": "above 0 to 50; 1 is the window's key"},
				"cone": {"type": "number", "description": "a spot's whole angle in degrees, 2 to 160"},
				"size": {"type": "number", "description": "a bulb's radius or a panel's side, in LDU"},
				"shadows": {"type": "boolean", "description": "whether what it lights casts shadows; true when omitted"},
			}},
		},
		# mcpsee3: View › Viewpoint › Save this view… (SavedViews).
		{
			"name": "save_view",
			"description": ("Keep where the person's window looks from now with the model, "
				+ "by a name, as View › Viewpoint › Save this view… does: the camera's turn, "
				+ "tilt and distance, the point it looks at, and whether it is square on. Each "
				+ "of the first nine gets a key of its own and a row in View › Viewpoint, "
				+ "Render's Camera lists them all, and view_model, render_model and render_queue "
				+ "draw from one by its name as view=; in_view lists them. A view of the same "
				+ "name is replaced where it is. Kept in the model's file at its next save "
				+ "(save_model). remove=true takes the view of that name out instead. Answered "
				+ "with the model drawn from the view, as view_model view= draws it "
				+ "(picture=false: words alone)."),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["name"], "properties": {
					"name": {"type": "string", "description": ("what to call it, as View › "
						+ "Viewpoint will list it (Three quarter, say); at most 60 letters")},
					"remove": {"type": "boolean", "description": "take the view of this name out of the model"},
					"picture": {"type": "boolean", "description": "false: words alone"},
				}},
		},
		{
			"name": "export_model",
			"description": ("Write the model out as File, Export does, where Export writes "
				+ "(the Downloads folder; a download on the web): format ldraw (.ldr, or .mpd "
				+ "with its sub-models, with its build steps), studio (a BrickLink Studio .io), "
				+ "a 3D file at real size — glb (one file: Blender, three.js, AR; any size of "
				+ "model), gltf (the same as text), obj (with an .mtl of its colours) or stl "
				+ "(one mesh in mm, Z up, to 3D print) or 3mf (to 3D print in colour: an object a "
				+ "colour, in mm on the bed); obj, stl and 3mf hold every triangle and are "
				+ "capped — picture (.png), bricklink (a wanted list), rebrickable (a parts "
				+ "list .csv), pickabrick (LEGO® Pick a Brick's list: element numbers and "
				+ "quantities, 400 lines a file; the answer names the parts with no element "
				+ "number known), or instructions (the building instructions as a booklet to "
				+ "print), or pdf (the same booklet as the PDF the Instructions window prints: "
				+ "its own fonts carried, every letter as typed; the answer names any its "
				+ "type cannot print, and shows its cover as the PDF prints it); all_models is every model the person saved, as LDraw in one .zip "
				+ "(File, Export, All my models). studio, picture, instructions and pdf are jobs: "
				+ "the answer is a job number at once, and job gives the result. A bricklink "
				+ "wanted list takes condition, wanted_list and notify, as BrickLink's upload "
				+ "reads them; what is not given is what the person chose last on the parts "
				+ "list's BrickLink button. Nothing is uploaded: the person uploads the file."
				+ " With format ldraw, submodels=true writes each sub-model as an LDraw file of its own, "
				+ "with its own sub-models and steps, all in one .zip (File, Export, Each sub-model), "
				+ "and submodel= just the one of that name in the model tree, as its row's menu does."
				# mcpreach (APP_UX8 #11).
				+ " stl and 3mf answer whether each object is a closed solid, as a slicer "
				+ "needs it, from the check each object's mesh is given, and name any part that "
				+ "is not. Nothing is written over: a file of that name already there is kept, "
				+ "and the new one takes the next free name (pods_2.3mf), which the answer gives. "
				+ PERSONS_OWN),
			"input_schema": {"type": "object", "additionalProperties": false,
				"required": ["format"], "properties": {
				"format": {"type": "string", "enum": ["ldraw", "studio", "glb", "gltf", "obj",
					"stl", "3mf", "picture", "bricklink", "rebrickable", "instructions", "all_models",
					"pickabrick",
					# mcpreach (APP_UX8 #11): the booklet's PDF.
					"pdf"]},
				"condition": {"type": "string", "enum": ["new", "used", "any"],
					"description": "bricklink: the condition wanted (CONDITION N or U; any leaves it out)"},
				"wanted_list": {"type": "integer", "description": "bricklink: the ID of one of the person's wanted lists (WANTEDLISTID, the number after wantedMoreID= in its address); 0 for the main wanted list"},
				"notify": {"type": "boolean", "description": "bricklink: BrickLink emails the person when a lot of a part is listed for sale (NOTIFY Y)"},
				# subexport (APP_UX7 #19).
				"submodels": {"type": "boolean", "description": "ldraw: each sub-model as an LDraw file of its own, with its own sub-models and steps, in one .zip"},
				"submodel": {"type": "string", "description": "ldraw: only this sub-model as an LDraw file of its own, by its name in the model tree (Wing, Wing (copy 2), or a path Ship#1/Wing#2)"},
			}},
		},
		{
			"name": "brickify",
			"description": ("Lay a 3D model in LEGO® bricks, as Make, Brickify a 3D model… does: an "
				+ "OBJ, STL, glTF/GLB, PLY, 3MF, VOX or FBX laid at the size asked (studs along "
				+ "its longest side) "
				+ "in slopes, curves and tiles, or plain bricks and plates, as one "
				+ "sub-assembly named after the file, beside what is built. file= its path on "
				+ "this computer (the desktop app), or url= an http(s) "
				+ "link to the file, fetched by the app (96 MB at most, 4 MB in a browser; an OBJ's .mtl and a "
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
				+ "sticker, as Make, Print on a part… and Put a sticker on… do. brick= the "
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
				+ "link to a PNG, JPEG, WebP or SVG (4 MB at most in a browser). Or the LEGO Group's own, as Make, Printed "
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
		# setcheck (APP_UX10 #4): File › Compare with the set….
		{
			"name": "compare_with_set",
			"description": ("What differs between the model and a real set, and where, as File, Compare, "
				+ "Compare with the set… lists it: the model checked against the set's own model "
				+ "from the library (LDraw's model repository, stepped by its author as the "
				+ "booklet is). Every part taken away, added, swapped for another mould or part, "
				+ "recoloured, moved (a stud is enough) or put in another sub-model, under the "
				+ "set's own step it is in (step 12; step 3 of the Wing, which goes on in step "
				+ "12), each with where it is in the model (its sub-model and the line of its "
				+ "file), its #N as look_at_model numbers it, and the edit_model call that puts "
				+ "it back as the set has it. A model that is the set says it matches. set= the "
				+ "set's number as on its box (7140 or 7140-1); without it, the set the model was "
				+ "opened from (open_model library=). most= how many changes are listed (60). "
				+ "show=true opens it in the person's window too, drawn on the model. Changes "
				+ "nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"set": {"type": "string"},
				"most": {"type": "integer"},
				"show": {"type": "boolean"},
			}},
		},
		{
			"name": "weakest_joints",
			"description": ("What gives first in the model as it stands, as View, Stress "
				+ "weighs it and the status bar's verdict says: every joint that alone holds "
				+ "what is past it (a cantilever's root, a part hung under another, a tower's "
				+ "foot), levered about the edge it would turn on, weakest first, each with the "
				+ "part that would come off, what it hangs from or stands on, its studs, the "
				+ "weight past it and its margin against the studs' working load (1 N a stud: "
				+ "under 1 is past it, under 2 within twice it; it lets go at about 1.9 times "
				+ "it, 3.1 times into a part a stud wide). A touch, one face resting on another "
				+ "with no stud between, carries "
				+ "only what stands on it, so it never shares a joint's load; a piece standing "
				+ "on touches alone past where it touches is said too. Read this instead of "
				+ "rebuilding the model in check_design to weigh it. Each joint past or near its "
				+ "working load comes with its fix, as Stress's Strengthen finds it: the fewest "
				+ "parts (up to three: a plate across the seam, a brick under it, a second pin) "
				+ "checked for room and weighed with the model, and the edit_model call that "
				+ "puts them down as one undo step; make that call as given. part= one part's "
				+ "number (look_at_model) for what holds it; count= how many joints (8); "
				+ "mine=true the fixes of the person's own parts (Parts, My bricks). lift_by= a "
				+ "part's number: the model lifted by that part off the floor, as Stress's Lift "
				+ "shows it (a car by its roof, a wall by a top brick): what each joint between "
				+ "it and the rest carries, which lets go first, and every part that comes away. "
				+ "Changes nothing."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"part": {"type": "integer"},
				"count": {"type": "integer"},
				"mine": {"type": "boolean"},
				# loadtest (APP_UX8 #13): Stress's Lift.
				"lift_by": {"type": "integer"},
			}},
		},
		GalleryTool.definition(),
		PatternTool.definition(),
		# pointat (APP_UX8 #17).
		{
			"name": "point_at",
			"description": ("Point parts out to everyone building this model with the person in "
				+ "a Build together session, as the person's Alt-W over a part does: each other "
				+ "person, and the person, sees them outlined in the person's colour with "
				+ "\"<their name>'s Claude\" over them, for 5 seconds, and their status bar says who "
				+ "points at what. Use it to show the others the part a reply is about. part= its "
				+ "number (look_at_model), or parts= up to 50. Changes nothing, the model or any "
				+ "file. Out of a session it says so: starting or joining one is the person's "
				+ "(File › Build together…), with a link they send."),
			"input_schema": {"type": "object", "additionalProperties": false, "properties": {
				"part": {"type": "integer", "description": "the part's number in look_at_model"},
				"parts": {"type": "array", "items": {"type": "integer"}, "maxItems": 50,
					"description": "several parts' numbers, pointed out together"},
			}},
		},
		# swapfind (APP_UX8 #9).
		_replace_parts_definition(),
	] + HandTools.definitions() + SeeTools.definitions() + PaletteTool.definitions()


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
			return await _edit_steps(input)
		"booklet_layout":
			return await _booklet_layout(input)
		"edit_booklet":
			return await _edit_booklet(input)
		# pagesetup.
		"page_setup":
			return await _page_setup(input)
		"lay_flex":
			return await _lay_flex(input)
		"pose_model":
			return await _pose(input)
		"move_part":
			var grabbing: GrabDrag = app.get("_grab_drag")
			if grabbing == null:
				return "This app cannot move parts on their joints."
			if str(input.get("part", "")).strip_edges().is_empty():
				return _what_moves(grabbing)
			# Asked to show it as well, the move answered pictured as
			# edit_model's change is: f1's session raised an arm on its ball
			# and then asked view_board to show the person.
			if not (input.get("picture") is bool and bool(input["picture"])):
				return await grabbing.for_session(input)
			var world: BrickWorld = app.get("_world")
			var was: Dictionary = {}
			for brick: BrickWorld.Brick in world.bricks():
				was[brick.id] = brick.transform
			var moved_said: String = await grabbing.for_session(input)
			var moved := PackedInt64Array()
			for brick: BrickWorld.Brick in world.bricks():
				if not was.has(brick.id) or not (was[brick.id] as Transform3D).is_equal_approx(brick.transform):
					moved.append(brick.id)
			if moved.is_empty():
				return moved_said
			# A ball's turn seen along its axis, where the swing shows whole.
			var view: String = "corner"
			var way: Array = input.get("axis", []) as Array
			if way.size() == 3:
				var along := Vector3(absf(float(way[0])), absf(float(way[1])), absf(float(way[2])))
				view = "top" if along.y > maxf(along.x, along.z) else "right" if along.x >= along.z else "front"
			return await _seeing().pictured(moved_said, moved, true, view, "moved")
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
		"edit_collection":
			return await _edit_collection(input)
		"render_model":
			return await _render(input, work)
		"render_queue":
			return _render_queue(input)
		# lights (APP_UX5 #7).
		"light_model":
			return _light_model(input)
		# mcpsee3: View › Viewpoint › Save this view….
		"save_view":
			return await _save_view(input)
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
		"weakest_joints":
			return await _weakest_joints(input)
		"compare_with_set":
			return await _compare_with_set(input)
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
		"mirror_parts", "split_parts", "merge_parts", "measure", "in_view":
			if _hands == null:
				_hands = HandTools.new()
				_hands.app = app
			var handled: Variant = await _hands.run(tool, input)
			# A change answered with it pictured, as edit_model's is (SeeTools).
			if handled is String and not _hands.changed.is_empty():
				return await _seeing().pictured(handled, _hands.changed, input.get("picture"))
			return handled
		"view_board", "booklet_page":
			return await _seeing().run(tool, input, work)
		# pointat (APP_UX8 #17).
		"point_at":
			return _point_at(input)
		# swapfind (APP_UX8 #9).
		"replace_parts":
			return await _replace_parts(input)
		# Edit, Pattern…'s grid (PatternTool), answered with the copies
		# pictured as the hand tools' changes are.
		"pattern_parts":
			if _pattern == null:
				_pattern = PatternTool.new()
				_pattern.app = app
			var laid: String = _pattern.run(input)
			if not _pattern.changed.is_empty():
				return await _seeing().pictured(laid, _pattern.changed, input.get("picture"))
			return laid
		# mcppalettes: the person's palettes (PaletteTool); a sub-assembly put
		# down answered with it pictured, as the hand tools' changes are.
		"palettes", "edit_palette":
			if _palette == null:
				_palette = PaletteTool.new()
				_palette.app = app
			var kept: String = await _palette.run(tool, input)
			if not _palette.changed.is_empty():
				return await _seeing().pictured(kept, _palette.changed, input.get("picture"))
			return kept
	return "No tool called %s." % tool


func _seeing() -> SeeTools:
	if _see == null:
		_see = SeeTools.new()
		_see.app = app
	return _see


## check_design's answer from outside, the parts its findings name pictured
## (SeeTools.findings_pictured, APP_UX5 seeing2).
func findings_pictured(answer: Variant, input: Dictionary) -> Variant:
	return await _seeing().findings_pictured(answer, input)


# -- a motor's mount, said before Simulate (mcpreach3) ---------------------------


## How real sets mount a motor's case, said with attachment_points on one.
## y6's and r1's sessions (APP_UX10's walk: 32 and 30 calls) stood a SPIKE
## Prime large motor on 1 x 1 bricks, one stud each; Simulate then said its
## output "turns on nothing", since the case itself swivelled on those
## studs, and each found that out by trying move_part and other mounts.
const MOTOR_MOUNT_WORDS := ("How real sets mount a motor's case: pins through two or more of "
	+ "the case's own pin holes, not all on one line, into a Technic beam or frame beside it, as "
	+ "SPIKE Prime's and Robot Inventor's own models do; or one part's two or more studs in the "
	+ "case's holes (where_to_attach parts=[its number] lists them). Stood on parts that each "
	+ "hold it by one stud (1 x 1 bricks or plates under it), the case swivels on them, and "
	+ "Simulate turns the case instead of its output. The output's holes are for what it drives, "
	+ "never for the mount.")
## The joints a motor's case swivels on, as a drag reads them: one stud, or
## one line of pins or an axle in round holes.
const MOTOR_LOOSE_KINDS: Array[String] = ["stud", "pin", "axle"]


## [param answer] of [param tool] with what it should say of a motor's
## mount: attachment_points on a motor, how real sets mount it; check_design,
## edit_model and submit_design, each motor in the model checked (or in the
## design checked, by its own reading of the joints) that stands on joints
## its case swivels on, named before Simulate is run.
func motor_mount_said(tool: String, answer: Variant, input: Dictionary) -> Variant:
	if app == null or assistant == null:
		return answer
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	if world == null or library == null:
		return answer
	if tool == "attachment_points":
		var asked: Array = [input] + (input.get("parts", []) as Array if input.get("parts") is Array else [])
		for one: Variant in asked:
			if not one is Dictionary:
				continue
			var part: String = str((one as Dictionary).get("part", ""))
			if (one as Dictionary).has("brick"):
				var brick: BrickWorld.Brick = world.get_brick(int((one as Dictionary)["brick"]))
				part = brick.part_id if brick != null else ""
			if not part.is_empty() and not Simulation.motor_of(library, part).is_empty():
				return _appended(answer, MOTOR_MOUNT_WORDS)
		return answer
	var said: String = ""
	if tool == "check_design" and (input.get("edit") is Dictionary or input.get("bricks") is Array):
		said = await _trial_motors_loose(input, library)
	elif tool == "submit_design" or _lays_motor(input.get("add"), library):
		# edit_model only when it lays a motor: the joints are read whole
		# for it, and the motors already down were named when laid.
		said = await _motors_loose(world, library)
	return answer if said.is_empty() else _appended(answer, said)


## The motors on the baseplate whose case a drag turns on joints of [constant
## MOTOR_LOOSE_KINDS], as move_part would take hold of them: words, or "".
func _motors_loose(world: BrickWorld, library: PartLibrary) -> String:
	var grabbing: GrabDrag = app.get("_grab_drag")
	if grabbing == null:
		return ""
	var loose := PackedStringArray()
	var motors: Dictionary = Simulation.motors_in(world.bricks(), library)
	if motors.is_empty():
		return ""
	if not grabbing.is_ready():
		await grabbing._ready_for_session()
	for id: Variant in motors:
		var held: Variant = grabbing.held_of([int(id)])
		if held is Grab and (held as Grab).link != null and MOTOR_LOOSE_KINDS.has((held as Grab).link.kind):
			loose.append(_motor_loose_words(world, library, int(id), (held as Grab).link))
	return _loose_said(loose)


## check_design's design, read as rigid bodies by itself (Bodies.read on a
## world of its own, on a worker), for its motors whose case hangs on such a
## joint. Only a design or an edit that lays a motor: the motors on the
## baseplate were named at the edit that laid them, and a model read whole
## for an edit that lays none is time spent for nothing.
func _trial_motors_loose(input: Dictionary, library: PartLibrary) -> String:
	var what_if: bool = input.get("edit") is Dictionary
	if not _lays_motor((input["edit"] as Dictionary).get("add") if what_if else input.get("bricks"), library):
		return ""
	var trial: Assistant.Model = assistant._edit(input["edit"]) if what_if else assistant._read_model(input)
	if trial == null or trial.placements.is_empty() or trial.placements.size() > MOST_TRIAL_PARTS:
		return ""
	var stage: BrickWorld = assistant._stage_of(trial)
	var part_ids: Dictionary = {}
	for brick: BrickWorld.Brick in stage.bricks():
		part_ids[brick.part_id] = true
	var shaped: Array = part_ids.keys()
	var bodies: Variant = await WorkerTasks.awaited(func() -> Variant:
		Exact.shapes_for(library, shaped)
		var covers := Builder.new()
		var lattice := BrickLattice.new()
		lattice.keeps_columns = false
		for brick: BrickWorld.Brick in stage.bricks():
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh != null:
				lattice.occupy_boxes(brick.id, covers.boxes_for(mesh, brick.transform))
		covers.free()
		return Bodies.read(stage, library, lattice, {}, {}), "read a design's joints", library)
	var loose := PackedStringArray()
	if bodies is Bodies:
		for id: Variant in Simulation.motors_in(stage.bricks(), library):
			var key: Variant = (bodies as Bodies).body_of.get(int(id))
			var link: Bodies.Link = (bodies as Bodies).parent_link.get(key) if key != null else null
			if link != null and link.turns and MOTOR_LOOSE_KINDS.has(link.kind):
				# Numbered as the check numbers a design's bricks, from 0.
				var index: int = stage.bricks().find(stage.get_brick(int(id)))
				loose.append(_motor_loose_words(stage, library, int(id), link,
					"brick %d" % index if not what_if else ""))
	stage.free()
	return _loose_said(loose)


## Whether [param given] (a design's bricks, an edit's add) lays a motor.
static func _lays_motor(given: Variant, library: PartLibrary) -> bool:
	if not given is Array:
		return false
	for one: Variant in given:
		if one is Dictionary and not Simulation.motor_of(library, str((one as Dictionary).get("part", ""))).is_empty():
			return true
	return false


## The most parts a design checked is read for its motors' mounts.
const MOST_TRIAL_PARTS := 2000


func _motor_loose_words(world: BrickWorld, library: PartLibrary, id: int, link: Bodies.Link,
		named: String = "") -> String:
	var brick: BrickWorld.Brick = world.get_brick(id)
	var motor: String = Simulation.motor_of(library, brick.part_id) if brick != null else ""
	return "%s, the %s, swivels %s at %s" % ["#%d" % id if named.is_empty() else named,
		(Simulation.MOTORS[motor] as Array)[0] if Simulation.MOTORS.has(motor) else "motor",
		link.words(), GrabDrag.at_words(link.point)]


static func _loose_said(loose: PackedStringArray) -> String:
	if loose.is_empty():
		return ""
	return ("Before Simulate, its mount: %s, as a drag reads its joints (move_part shows it). Its case "
		+ "is held by nothing else, so Simulate would turn the case, not its output. Mount it as real "
		+ "sets do: pins through two or more of the case's pin holes, not all on one line, into a "
		+ "beam or a frame, or one part's two or more studs in its holes.") % "; ".join(loose)


## [param text] said after [param answer], a String or content blocks.
static func _appended(answer: Variant, text: String) -> Variant:
	if answer is Array:
		var out: Array = (answer as Array).duplicate()
		out.append({"type": "text", "text": text})
		return out
	var was: String = str(answer)
	return text if was.is_empty() else "%s\n\n%s" % [was, text]


## Why [param tool] is not done now, before it begins, or "".
func refusal(tool: String, input: Dictionary) -> String:
	# A bench's run (DesignMemory.holding): a picture or a model from a link
	# can be the answer a design is judged against, as one from Commons or
	# the gallery can ([method _fetch] is reached only past here).
	if DesignMemory.holding() and (tool == "brickify" and input.has("url")
			or tool == "print_part" and input.has("picture_url")):
		return ("While a design is being scored, no link is fetched: what it holds could be the "
			+ "answer it is judged against.")
	if app == null:
		return "This app cannot do that from outside."
	var shell: Shell = app.get("_shell")
	if shell != null and shell.read_only and not _while_looking(tool, input):
		return ("This tab shows a model shared to look at: it can be listed and its booklet "
			+ "made, not changed or written out. Open in Brickworks copies it into the "
			+ "person's own models.")
	if assistant != null and assistant.is_busy() and changes(tool, input):
		return "The app's own designer is building right now; wait for it to finish."
	# A run kept to a list of parts: a tool that makes parts of its own is not.
	if not PartsOnly.tool_refusal(tool).is_empty():
		return PartsOnly.tool_refusal(tool)
	# As clear_model: a request about the selected parts changes those alone.
	if assistant != null and assistant.asked_about_selection() and changes(tool, input):
		return ("Not now — the person asked about the parts they selected, and this would "
			+ "change more than those. Change them with edit_selection.")
	return ""


## The tools that change the model.
const CHANGES: Array[String] = ["set_floor", "edit_steps", "edit_booklet", "lay_flex", "pose_model", "move_part",
	"define_motion", "play_motion",
	"undo", "open_model", "brickify", "print_part", "make_unique", "colour_hidden_parts",
	"make_sections", "break_out_section",
	"mirror_parts", "split_parts", "merge_parts",
	# Edit, Pattern…'s grid (PatternTool).
	"pattern_parts",
	# pagesetup: the booklet's page.
	"page_setup",
	# lights (APP_UX5 #7): the lights kept with the model.
	"light_model"]


## Whether [param tool] called with [param input] changes the model: one of
## [constant CHANGES], and not in a form that only reads it (as a model
## shared to look at allows, [method _while_looking]). By the call, not the
## tool: light_model's list was refused while the designer built, as edit_steps'
## list and set_floor's question were (lreview, 2026-11-07).
static func changes(tool: String, input: Dictionary) -> bool:
	# mcppalettes: a palette's sub-assembly put down changes the model; the
	# rest of edit_palette changes only the person's palettes.
	if tool == "edit_palette":
		return str(input.get("action", "")) == "place"
	# hubprogram: simulate_mechanism's program= sets the model's program.
	if tool == "simulate_mechanism":
		return input.has("program")
	return tool in CHANGES and not _while_looking(tool, input)


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
			return not bool(input.get("record", false)) and not input.has("program")
		"export_model":
			# mcpreach: the booklet's PDF, as its page is.
			return str(input.get("format", "")) in ["instructions", "pdf"]
		"suggest_sections", "evaluate_section", "booklet_layout", "list_motions", "weakest_joints":
			return true
		# setcheck: the model checked against its set, read.
		"compare_with_set":
			return true
		"measure", "in_view":
			return true
		"view_board", "booklet_page":
			return true
		# pagesetup: how the page is set up, read.
		"page_setup":
			return input.is_empty()
		# mcppalettes: the person's palettes, read.
		"palettes":
			return true
		# lights (APP_UX5 #7): the model's lights, listed.
		"light_model":
			return str(input.get("op", "list")) == "list"
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


## Parts from which edit_steps works its steps out paced (plan_paced).
const STEPS_PACED_FROM := 300


func _edit_steps(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var shell: Shell = app.get("_shell")
	var op: String = str(input.get("op", "list"))
	# stepsearch: find= is the list's, and changes nothing.
	if input.has("find") and op != "list":
		return "find= lists the steps that place a part; give it with no op= (or op \"list\")."
	if input.has("find") and str(input["find"]).strip_edges().is_empty():
		return "Give find= a part's number, its name or a colour, or both (\"red 3001\")."
	var steps: Array[Instructions.Step] = []
	# Worked out a slice a frame on a big model: in one go, the Charger's
	# 1,083 parts held the window a second on the desktop and several in a
	# browser, whose page says nothing to the relay meanwhile (bigedit).
	if world.brick_count() >= STEPS_PACED_FROM:
		var job: Working.Job = Working.begin("Setting out the steps…")
		await job.shown()
		steps = await Instructions.plan_paced(world, library, store.scenery, {}, job, true)
		job.end()
	else:
		steps = Instructions.plan(world, library, store.scenery, {}, true)
	if steps.is_empty():
		return "There is nothing built to have steps."
	match op:
		"list":
			if input.has("find"):
				return _found_steps(steps, str(input["find"]).strip_edges())
			return _list_steps(steps, int(input.get("from", 1)))
		"next", "prev", "new", "to":
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
			if op != "to":
				return _steps_why(shell.change_steps(op, ids, null), op, ids, steps, null)
			if not input.has("step"):
				return "Give step= the number of the step to put them in, from edit_steps's list."
			var into: Instructions.Step = _step_numbered(steps, int(input["step"]))
			var last: Instructions.Step = steps[steps.size() - 1]
			# Past the last: a new step after it, as far as a step goes (t9's
			# "three steps later" of a part two from the end, mcpreach3).
			if into == null and int(input["step"]) > last.number and last.callout_step == 0:
				# All of the last step among them: a step after it would leave
				# it empty, so they go in the last step, and that is said.
				var whole_last: bool = not last.brick_ids.is_empty()
				for brick_id: int in last.brick_ids:
					whole_last = whole_last and ids.has(brick_id)
				if whole_last:
					var into_last: String = _steps_why(shell.change_steps("to", ids, last), "next", ids,
						steps, null)
					if into_last.begins_with("the steps are as they were"):
						return into_last
					return ("%s. There are %d steps, and a step after the last would leave step %d "
						+ "empty, and an empty step is taken out, so they are in step %d, the "
						+ "last.") % [into_last, last.number, last.number, last.number]
				var said: String = _steps_why(shell.change_steps("new", ids, last), "next", ids,
					steps, null)
				if said.begins_with("the steps are as they were"):
					return said
				return ("%s. There are %d steps, so step %d is a new one after the last: a step "
					+ "is only made next to one with parts in it, never with empty steps "
					+ "between.") % [said, last.number, last.number + 1]
			if into == null:
				return "There is no step %d: the steps run 1 to %d." % [int(input["step"]),
					last.number]
			return _steps_why(shell.change_steps(op, ids, into), op, ids, steps, into)
		"earlier", "later", "merge", "delete":
			if not input.has("step"):
				return "Give step= a step's number from edit_steps's list."
			var at: Instructions.Step = _step_numbered(steps, int(input["step"]))
			if at == null:
				return "There is no step %d: the steps run 1 to %d." % [int(input["step"]),
					steps[steps.size() - 1].number]
			return shell.change_steps(op, [], at)
		"name":
			# stepnames: one call, one undo (Shell.change_look "name").
			if not input.has("step") or not input.has("name"):
				return "Give step= a step's number from edit_steps's list, and name= what it is called (\"\" takes it off)."
			var named: Instructions.Step = _step_numbered(steps, int(input["step"]))
			if named == null:
				return "There is no step %d: the steps run 1 to %d." % [int(input["step"]),
					steps[steps.size() - 1].number]
			# A callout's step as edit_booklet takes one (snreview F5).
			if input.has("callout_step"):
				var inside: Instructions.Step = _step_numbered(steps, named.number,
					maxi(1, int(input["callout_step"])))
				if inside == null or int(input["callout_step"]) < 1:
					return ("Step %d puts on no sub-assembly built in a callout." % named.number) \
						if not named.attaches() or named.callout_steps <= 0 \
						else "Step %d's callout has steps 1 to %d." % [named.number, named.callout_steps]
				named = inside
			return _sentence(shell.change_look("name", named, {"name": str(input["name"])}))
	return "op is one of list, to, next, prev, new, earlier, later, merge, delete, name."


# -- the booklet, by hand --------------------------------------------------------


## Why a step edit of parts changed nothing, after the window's own words
## for it ([param said], Shell.change_steps): t9's `next` on a part alone in
## the last step, and `new` on it, each answered "the steps are as they
## were" and nothing more, and the session tried both before telling the
## person the app would not (APP_UX10's walk; mcpreach3). [param steps] are
## as they were before the edit. Any other answer is handed back as it is.
static func _steps_why(said: String, op: String, ids: Array, steps: Array[Instructions.Step],
		into: Instructions.Step) -> String:
	if said != "the steps are as they were" or steps.is_empty():
		return said
	var step_of: Dictionary = {}
	var size_of: Dictionary = {}
	for step: Instructions.Step in steps:
		if step.callout_step > 0:
			continue
		size_of[step.number] = step.brick_ids.size()
		for brick_id: int in step.brick_ids:
			step_of[brick_id] = step.number
	var held: Dictionary = {}
	for brick_id: Variant in ids:
		if step_of.has(int(brick_id)):
			held[step_of[int(brick_id)]] = int(held.get(step_of[int(brick_id)], 0)) + 1
	var parts := PackedStringArray()
	for brick_id: Variant in ids:
		parts.append("#%d" % int(brick_id))
	var them: String = ", ".join(parts)
	var one: bool = ids.size() == 1
	if held.size() != 1:
		return ("the steps are as they were: %s %s in steps of different sub-models, and a part "
			+ "moves only within its own sub-model's steps; move each sub-model's parts on their "
			+ "own.") % [them, "is" if one else "are"] if held.is_empty() else said
	var at: int = int(held.keys()[0])
	var whole: bool = int(held[at]) >= int(size_of.get(at, 0))
	var first: int = steps[0].number
	var last: int = steps[steps.size() - 1].number
	if op == "to" and into != null and into.number == at:
		return "the steps are as they were: %s %s in step %d already." % [them,
			"is" if one else "are", at]
	if whole and op == "next" and at == last:
		return ("the steps are as they were: %s %s all of step %d, the last step: a step after "
			+ "it would leave step %d empty, and an empty step is taken out, so %s %s built last "
			+ "already. To build %s later still, move other parts to before %s (to, with "
			+ "step=).") % [them, "is" if one else "are", at, at, "it" if one else "they",
			"is" if one else "are", "it" if one else "them", "it" if one else "them"]
	if whole and op == "prev" and at == first:
		return ("the steps are as they were: %s %s all of step %d, the first step: a step before "
			+ "it would leave step %d empty, and an empty step is taken out, so %s %s built "
			+ "first already.") % [them, "is" if one else "are", at, at, "it" if one else "they",
			"is" if one else "are"]
	if whole and op == "new":
		return ("the steps are as they were: %s %s all of step %d already, and new makes a step "
			+ "of parts taken out of a step they share. next or prev moves %s a step; to, with "
			+ "step=, puts %s in any step.") % [them, "is" if one else "are", at,
			"it" if one else "them", "it" if one else "them"]
	return said


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


## pagesetup: the booklet's page set up (Shell.page_setup, as Page setup…
## sets it): one undo. With nothing asked, how it is set up and the styles
## kept.
func _page_setup(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var shell: Shell = app.get("_shell")
	if input.is_empty():
		var styles: Array = BookletSheet.styles().keys()
		styles.sort()
		return "The booklet's page: %s. %s" % [BookletSheet.of(world).words(),
			("Styles kept: %s." % ", ".join(styles)) if not styles.is_empty()
				else "No style is kept yet: save_as= keeps this page as one."]
	var fields: Dictionary = {}
	for field: String in ["size", "orientation", "margin", "colour", "number", "parts", "usual",
			"style", "save_as", "remove_style"]:
		if input.has(field):
			fields[field] = input[field]
	if input.has("picture_url") or input.has("picture_data"):
		var image: Variant = await _page_picture(input, "picture")
		if image is String:
			return image
		var kept: Array = BookletSheet.picture_of(image)
		fields["picture"] = kept[0]
		fields["picture_data"] = kept[1]
	elif str(input.get("picture", "")).to_lower() in ["none", "off", "false"]:
		fields["picture"] = ""
	# booklook: the cover, the words on every page, the booklet's colours.
	for field: String in BookletSheet.TEXTS + ["box_frame", "box_fill", "box_corners",
			"number_colour", "outline_colour"]:
		if input.has(field):
			fields[field] = input[field]
	if input.has("cover_picture_url") or input.has("cover_picture_data"):
		var image: Variant = await _page_picture(input, "cover_picture")
		if image is String:
			return image
		var cover: Array = BookletSheet.cover_of(image)
		fields["cover_picture"] = cover[0]
		fields["cover_picture_data"] = cover[1]
	elif str(input.get("cover_picture", "")).to_lower() in ["model", "none", "off", "false"]:
		fields["cover_picture"] = ""
	return _sentence(shell.page_setup(fields))


## The picture [param input]'s [param field]_data or [param field]_url
## gives: an Image, or what was wrong as the answer's words.
func _page_picture(input: Dictionary, field: String) -> Variant:
	if input.has(field + "_data"):
		var read: Dictionary = PictureFile.from_data(str(input[field + "_data"]))
		if read.has("error"):
			return _sentence(str(read["error"]))
		return read["image"]
	var fetched: Dictionary = await _fetch(str(input[field + "_url"]).strip_edges(),
		PictureFile.MOST_BYTES)
	if fetched.has("error"):
		return str(fetched["error"])
	var image: Image = PictureFile.decode(fetched["bytes"])
	if image == null:
		return _sentence(PictureFile.not_read(fetched["bytes"], "That link"))
	return image


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
	if input.has("callout_step"):
		var inside: Instructions.Step = _step_numbered(steps, at.number,
			maxi(1, int(input["callout_step"])))
		if inside == null or int(input["callout_step"]) < 1:
			return ("Step %d puts on no sub-assembly built in a callout." % at.number) \
				if not at.attaches() or at.callout_steps <= 0 \
				else "Step %d's callout has steps 1 to %d." % [at.number, at.callout_steps]
		at = inside
		var whole: Array = input.keys().filter(func(field: String) -> bool:
			return not field in ["step", "callout_step", "turn", "tilt", "place", "text", "arrow", "guide"])
		if not whole.is_empty():
			return ("A callout's step takes turn= and tilt=, and on a callout with pages of its "
				+ "own place=, text= and arrow=; %s= is the callout's own, set on step %d.") \
				% [str(whole[0]), at.number]
	if int(input.has("place")) + int(input.has("text")) + int(input.has("arrow")) \
			+ int(input.has("guide")) > 1:
		return "One at a time: place=, text=, arrow= or guide=, each its own undo step."
	if input.has("guide"):
		return _lay_guide(input["guide"], at)
	if input.has("place") or input.has("text") or input.has("arrow"):
		return await _edit_page(input, at)
	if bool(input.get("follow", false)):
		return await _follow_page(at)
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
	var extras: Variant = _booklet_extras(input, world, at)
	if extras is String:
		return extras
	fields.merge(extras)
	if fields.is_empty():
		return ("Say what to set: turn=, tilt=, zoom=, size=, page=, parts=, sign=, callout=, "
			+ "per_page=, pull=, colours=, colours_all=, actual_size= or preview=. "
			+ "booklet_layout says how each step is printed now.")
	var said: String = shell.change_look("set", at, fields)
	var now: String = ""
	if at.authored_step >= 0 or AuthorSteps.any(world, store.scenery):
		var again: Instructions.Step = _step_numbered(Instructions.plan(world, library,
			store.scenery, {}, true), at.number, at.callout_step)
		if again != null and again.authored_step >= 0:
			now = BookletLooks.said(world, again.authored_in, again.authored_step)
			if again.in_callout() and now.is_empty():
				now = "seen as the callout faces"
	var named: String = ("step %d's callout step %d" % [at.number, at.callout_step]) \
		if at.in_callout() else "step %d" % at.number
	return said + (("; %s is now: %s" % [named, now]) if not now.is_empty() else "") \
		+ _extras_said


## edit_booklet's Studio extras (booklet3) as BookletLooks keeps them:
## pull=, colours=, colours_all=, actual_size= and preview=; or what is wrong
## with one, said. What else to say of them goes in [member _extras_said].
func _booklet_extras(input: Dictionary, world: BrickWorld, at: Instructions.Step) -> Variant:
	var fields: Dictionary = {}
	_extras_said = ""
	if input.has("pull"):
		var pull: Variant = input["pull"]
		var studs: float = BookletLooks.PULL_STUDS
		var parts: Array = []
		if pull is Dictionary:
			studs = float(pull.get("studs", BookletLooks.PULL_STUDS))
			var asked: Variant = pull.get("parts", [])
			if not (asked is Array):
				asked = [asked]
			var pulled: Variant = _pulled_parts(asked, at, world)
			if pulled is String:
				return pulled
			parts = pulled
		elif pull is bool:
			studs = BookletLooks.PULL_STUDS if pull else 0.0
		elif pull is float or pull is int:
			studs = float(pull)
		else:
			return ("pull= is studs (0 puts the parts back), true, or {studs, parts: [the step's "
				+ "brick numbers or part ids]}.")
		if studs > BookletLooks.PULL_MOST:
			return "pull= is at most %s studs." % BookletLooks._number(BookletLooks.PULL_MOST)
		fields["pull"] = {"studs": maxf(0.5, studs), "parts": parts} if studs > 0.0 else null
	if input.has("colours"):
		var all: bool = bool(input.get("colours_all",
			BookletLooks.booklet(world).get("colours_all", false)))
		fields["colours"] = null if bool(input["colours"]) == all else bool(input["colours"])
	if input.has("colours_all"):
		fields["colours_all"] = bool(input["colours_all"])
	if input.has("actual_size"):
		var actual: Variant = input["actual_size"]
		if actual is Array:
			fields["actual_size"] = (actual as Array).map(func(part: Variant) -> String:
				return str(part).to_lower().trim_suffix(".dat"))
		elif actual is bool:
			fields["actual_size"] = actual
		elif str(actual) == "auto":
			fields["actual_size"] = null
		else:
			return "actual_size= is true, false, \"auto\" or [part ids]."
	if input.has("preview"):
		fields["preview"] = bool(input["preview"])
	return fields


## What _booklet_extras has to say beside the change: which parts a pull by
## brick number pulls.
var _extras_said: String = ""


## The part ids a pull's [param asked] names in step [param at]: each the
## step's brick number (look_at_model's, as view_board's highlight= takes)
## or a part id; or why not, with the step's parts. A session pulled the
## wing out by its brick number, parts: [3]: it became the part id "3.0",
## matched nothing in the step, and was kept without a word, so the page drew
## no pull (APP_UX5, MCP walk). The booklet keeps a pull by part id, so the
## step's other parts of that id are pulled too, and said.
func _pulled_parts(asked: Array, at: Instructions.Step, world: BrickWorld) -> Variant:
	var library: PartLibrary = app.get("_library")
	var of_brick: Dictionary = {}
	var ids_of: Dictionary = {}
	for brick_id: int in at.brick_ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var part: String = brick.part_id.to_lower().trim_suffix(".dat")
		of_brick[brick_id] = part
		if not ids_of.has(part):
			ids_of[part] = []
		(ids_of[part] as Array).append(brick_id)
	var parts: Array = []
	var by_number: Array = []
	var unknown := PackedStringArray()
	for raw: Variant in asked:
		var part: String = ""
		var number: int = 0
		if raw is float or raw is int:
			number = int(raw)
		else:
			# Quotes round it are a session's (Quotes.off, mcpsee3).
			var said: String = Quotes.off(str(raw)).to_lower().trim_prefix("#") \
				.trim_suffix(".dat")
			if ids_of.has(said):
				part = said
			elif said.is_valid_int():
				number = int(said)
		if part.is_empty() and of_brick.has(number):
			part = of_brick[number]
			by_number.append(number)
		elif part.is_empty() and ids_of.has(str(number)) and number != 0:
			part = str(number)
		if part.is_empty():
			unknown.append(str(raw).trim_suffix(".0") if raw is float else str(raw))
		elif not part in parts:
			parts.append(part)
	var named := PackedStringArray()
	var listed: Array = of_brick.keys()
	listed.sort()
	for brick_id: int in listed.slice(0, 24):
		named.append("#%d %s (%s)" % [brick_id, HandTools._part_name(library, of_brick[brick_id]),
			of_brick[brick_id]])
	if listed.size() > 24:
		named.append("and %d more" % (listed.size() - 24))
	var step: String = ("step %d's callout step %d" % [at.number, at.callout_step]) \
		if at.in_callout() else "step %d" % at.number
	if not unknown.is_empty():
		return ("Nothing changed: %s %s not in %s. pull's parts= takes the step's brick numbers or "
			% [", ".join(unknown), "is" if unknown.size() == 1 else "are", step]
			+ "part ids; %s's parts are %s." % [step, ", ".join(named)])
	var also := PackedStringArray()
	for number: int in by_number:
		for other: int in ids_of[of_brick[number]]:
			if not other in by_number and not also.has("#%d" % other):
				also.append("#%d" % other)
	if not by_number.is_empty():
		var which := PackedStringArray()
		for number: int in by_number:
			which.append("#%d is a %s (%s)" % [number, HandTools._part_name(library,
				of_brick[number]), of_brick[number]])
		_extras_said = "; pulled by part: %s" % ", ".join(which)
		if not also.is_empty():
			_extras_said += (", and the booklet keeps a pull by part, so %s, the same part in "
				% ", ".join(also) + "this step, %s pulled too" % ("is" if also.size() == 1 else "are"))
	return parts


## A guide on every page of the booklet (Shell.change_look "guide"), as
## dragging one out of the page editor's ruler lays it: one undo.
func _lay_guide(given: Variant, at: Instructions.Step) -> String:
	var guide: Dictionary = given if given is Dictionary else {}
	var axis: String = str(guide.get("axis", ""))
	if not axis in ["x", "y"]:
		return "guide= {axis: \"x\" (upright, at= mm from the left) or \"y\" (across, from the top), at}."
	var page: Vector2 = BookletSheet.of(app.get("_world")).size()
	var most: float = page.x if axis == "x" else page.y
	var fields: Dictionary = {"axis": axis, "at": null, "was": guide.get("was")}
	if bool(guide.get("remove", false)):
		fields["was"] = guide.get("was", guide.get("at"))
		if fields["was"] == null:
			return "guide= {axis, at, remove: true}: at= is the guide to take off."
	elif not guide.has("at") or float(guide["at"]) < 0.0 or float(guide["at"]) > most:
		return "guide= at= is 0 to %s mm from the page's %s." % [BookletLooks._number(most),
			"left" if axis == "x" else "top"]
	else:
		fields["at"] = float(guide["at"])
	var had: Dictionary = BookletLooks.guides(app.get("_world"))
	var said: String = (app.get("_shell") as Shell).change_look("guide", at, fields)
	var now: Dictionary = BookletLooks.guides(app.get("_world"))
	if now == had:
		return "No guide %s at %s mm to %s: the guides are %s." % [
			"upright" if axis == "x" else "across", BookletLooks._number(float(fields["was"])),
			"take off" if fields["at"] == null else "move", _guides_said(now)] \
			if fields["was"] != null else said
	return "%s; the guides now: %s. Nothing printed shows them." % [said, _guides_said(now)]


static func _guides_said(guides: Dictionary) -> String:
	var each := PackedStringArray()
	for axis: String in ["x", "y"]:
		for at: Variant in guides.get(axis, []):
			each.append("%s at %s mm" % ["upright" if axis == "x" else "across",
				BookletLooks._number(float(at))])
	return "none" if each.is_empty() else ", ".join(each)


## The page by hand (Shell.change_look "place", "note", "text"), as the
## page editor's drags and Add words do: one undo. Each kept with the room
## the step has on its page now, as the page editor keeps it.
func _edit_page(input: Dictionary, at: Instructions.Step) -> String:
	var shell: Shell = app.get("_shell")
	var entry: Booklet.Entry = await _laid_entry(at)
	if at.in_callout() and (entry == null or entry.panel.size.x <= 0.0):
		return ("Step %d's callout is built in a box on step %d's page: lay out that page, "
			+ "or callout=false gives the callout pages of its own.") % [at.number, at.number]
	var room: Variant = BookletLooks.said_rect(entry.panel) if entry != null else null
	if input.has("arrow"):
		var arrow: Dictionary = input["arrow"] if input["arrow"] is Dictionary else {}
		var points: Array = []
		for name: String in ["x1", "y1", "x2", "y2"]:
			if arrow.has(name):
				points.append(float(arrow[name]))
		var bends: Variant = _bends_of(arrow)
		if bends is String:
			return bends
		if arrow.has("index"):
			var index: int = int(arrow["index"])
			var fields: Dictionary = {"index": index, "room": room}
			if bool(arrow.get("remove", false)):
				fields["remove"] = true
			elif points.is_empty() and bends != null and entry != null \
					and index >= 0 and index < entry.drawn_arrows.size():
				# Bent alone: its ends kept where they are on the page.
				var had: Array = BookletLooks.arrow_points(entry.drawn_arrows[index])
				if not had.is_empty():
					points = [(had[0] as Vector2).x, (had[0] as Vector2).y,
						(had[1] as Vector2).x, (had[1] as Vector2).y]
			if points.size() >= 4:
				fields["at"] = points + (bends if bends != null else [])
			for name: String in ["colour", "width"]:
				if arrow.has(name):
					fields[name] = arrow[name]
			var changed: String = shell.change_look("arrow_edit", at, fields)
			if arrow.has("x2") and arrow.has("y2") and not fields.has("remove"):
				changed += _aimed(entry, at.number, points, index)
			return changed
		if points.size() < 4:
			return "arrow= {x1, y1, x2, y2} in mm: where it starts and where it points."
		var index: int = entry.drawn_arrows.size() if entry != null else 0
		return shell.change_look("arrow", at, {"at": points + (bends if bends != null else []),
			"colour": str(arrow.get("colour", "red")), "width": float(arrow.get("width", 0.9)),
			"room": room}) + _aimed(entry, at.number, points, index)
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
			# Turned about its middle and faded, as the page editor's knob and
			# Opacity do; moved too only where x, y, w or h is given.
			if place.has("opacity"):
				var percent: float = float(place["opacity"])
				if percent < BookletLooks.FAINTEST * 100.0 or percent > 100.0:
					return "opacity= is percent, %d to 100: 50 is half seen." \
						% roundi(BookletLooks.FAINTEST * 100.0)
				fields["opacity"] = percent / 100.0
			if place.has("turn"):
				fields["turn"] = float(place["turn"])
			if not (fields.has("turn") or fields.has("opacity")) \
					or ["x", "y", "w", "h"].any(func(name: String) -> bool: return place.has(name)):
				var now: Rect2 = _now_at(entry, "note", int(place.get("index", -1)))
				fields["at"] = [float(place.get("x", now.position.x)), float(place.get("y", now.position.y)),
					float(place.get("w", now.size.x)), float(place.get("h", now.size.y))]
		return shell.change_look("note", at, fields)
	if not BookletLooks.ITEMS.has(item):
		return "place= {item: picture, parts, callout, number or note, x, y, w, h} in mm."
	if place.has("turn") or place.has("opacity"):
		return ("turn= and opacity= turn and fade words or a picture added: place= {item: "
			+ "\"note\", index, turn, opacity}. The step's %s is drawn as the booklet draws it.") % item
	if bool(place.get("back", false)):
		return shell.change_look("place", at, {"item": item, "at": null, "room": room})
	if not place.has("x") or not place.has("y"):
		return "place= needs x and y, in mm from the page's top left corner."
	var now: Rect2 = _now_at(entry, item)
	return shell.change_look("place", at, {"item": item, "at": [float(place["x"]),
		float(place["y"]), float(place.get("w", now.size.x)), float(place.get("h", now.size.y))],
		"room": room})


## The page step [param at] is on laid out on every later page with as
## many steps, as the page editor's Apply to later pages does: one undo.
func _follow_page(at: Instructions.Step) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var maker := BookletMaker.new()
	maker.library = app.get("_library")
	app.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(world, store.scenery, "Model")
	var plan: Array[Instructions.Step] = maker.plan
	maker.queue_free()
	for index: int in pages.size():
		if pages[index].kind != "steps" \
				or not pages[index].entries.any(func(entry: Booklet.Entry) -> bool: return entry.number == at.number):
			continue
		var later: Dictionary = PageEditor.later_layout(pages, index, plan)
		if not bool(later["placed_any"]):
			return ("Nothing on page %d is placed yet: place= its picture, parts list or number "
				+ "first, then follow=true lays the later pages out the same.") % pages[index].number
		if (later["laid"] as Array).is_empty():
			return "No page after page %d has %d steps." % [pages[index].number,
				pages[index].entries.size()]
		var said: String = (app.get("_shell") as Shell).place_pages(later["placed"],
			"page %d's layout on %d later pages" % [pages[index].number, (later["laid"] as Array).size()])
		if not (later["left"] as Array).is_empty():
			said += "; pages %s have another number of steps and were left as they were" \
				% ", ".join(PackedStringArray((later["left"] as Array).map(
					func(page: int) -> String: return str(page))))
		return said + ". booklet_layout says where each thing is now."
	return "Step %d is on no page of steps." % at.number


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
			if entry.number != at.number:
				continue
			# A callout's step: on its own pages, or in the box on this one.
			if at.in_callout():
				return entry.callout.steps[at.callout_step - 1] if entry.callout != null \
					and at.callout_step <= entry.callout.steps.size() else null
			return entry
	return null


## The points [param arrow] (edit_booklet's arrow=) bends through, flat
## [bx, by, ...]: its bends=, or bx and by; null when it gives none, or
## what is wrong with them.
static func _bends_of(arrow: Dictionary) -> Variant:
	if arrow.has("bx") and arrow.has("by") and not arrow.has("bends"):
		return [float(arrow["bx"]), float(arrow["by"])]
	if not arrow.has("bends"):
		return null
	var given: Variant = arrow["bends"]
	var flat: Array = []
	for point: Variant in given if given is Array else [null]:
		if point is Array and (point as Array).size() == 2:
			flat.append_array([float(point[0]), float(point[1])])
		elif point is Dictionary and (point as Dictionary).has("x") and (point as Dictionary).has("y"):
			flat.append_array([float(point["x"]), float(point["y"])])
		else:
			return "bends= is [[x, y], ...] in mm: the points the arrow bends through, in order."
	if flat.size() / 2 > BookletLooks.MOST_BENDS:
		return "An arrow bends through at most %d points." % BookletLooks.MOST_BENDS
	return flat


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
## The step numbered [param number], the model's own; with [param inside],
## that step of the callout it puts on (a callout's steps carry the number of
## the step that puts it on).
static func _step_numbered(steps: Array[Instructions.Step], number: int,
		inside: int = 0) -> Instructions.Step:
	var found: Instructions.Step = null
	for step: Instructions.Step in steps:
		if step.number != number:
			continue
		if inside > 0:
			if step.callout_step == inside:
				return step
		elif found == null or step.callout_step == 0:
			found = step
	return found


func _list_steps(steps: Array[Instructions.Step], from: int) -> String:
	var said := PackedStringArray()
	said.append(_steps_whose(steps))
	var wheres: PackedStringArray = _steps_where(steps)
	if steps.any(func(step: Instructions.Step) -> bool: return _built_in_place(step)):
		said.append("A sub-model's steps take only its own parts, and a sub-model goes in a "
			+ "step whole, built in its own steps before that step.")
	var shown: int = 0
	var characters: int = 0
	for index: int in steps.size():
		var step: Instructions.Step = steps[index]
		if step.number < from:
			continue
		var ids: PackedInt64Array = step.brick_ids
		var numbers := PackedStringArray()
		for brick_id: int in ids.slice(0, 12):
			numbers.append("#%d" % brick_id)
		if ids.size() > 12:
			numbers.append("and %d more" % (ids.size() - 12))
		var where: String = wheres[index]
		var line: String = "  %d%s: %s" % [step.number, where, " ".join(numbers)]
		if not step.name.is_empty():
			# stepnames: its name, as the timeline says it.
			line = "  %d%s %s: %s" % [step.number, where, Motions.quoted(step.name),
				" ".join(numbers)]
		characters += line.length()
		if characters > 6000:
			said.append("  ... edit_steps {\"from\": %d} for the rest." % step.number)
			break
		said.append(line)
		shown += 1
	if shown == 0:
		said.append("  none from step %d." % from)
	return "\n".join(said)


## "24 steps, the model's own." or worked out by the app: the head of
## edit_steps' list and of its find.
func _steps_whose(steps: Array[Instructions.Step]) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var count: int = steps[steps.size() - 1].number
	return "%d step%s, %s." % [count, "" if count == 1 else "s",
		"the model's own" if AuthorSteps.any(world, store.scenery)
			else "worked out by the app (the first edit makes them the model's own)"]


## Where each of [param steps] is, as edit_steps says it after the step's
## number: " (in the Wing, 2 of 3)", " (puts on the Wing x2)", "" for the
## model's own. The steps of a sub-model built where it stands,
## not in a callout, are named as a callout's are: listed bare, the island's
## rocks read as the model's own parts, and a session moved them "to" the
## baseplates' step (stepsto).
static func _steps_where(steps: Array[Instructions.Step]) -> PackedStringArray:
	var built: Dictionary = {}      ## sub-model's path -> how many steps it is built in
	for step: Instructions.Step in steps:
		if _built_in_place(step):
			built[step.authored_in] = int(built.get(step.authored_in, 0)) + 1
	var counted: Dictionary = {}
	var out := PackedStringArray()
	for step: Instructions.Step in steps:
		var where: String = ""
		if step.callout_step > 0:
			where = " (in the %s, %d of %d)" % [step.assembly, step.callout_step,
				step.callout_steps]
		elif _built_in_place(step):
			counted[step.authored_in] = int(counted.get(step.authored_in, 0)) + 1
			where = " (in the %s, %d of %d)" % [Instructions._name_of(step.authored_in),
				int(counted[step.authored_in]), int(built[step.authored_in])]
		elif not step.copies.is_empty():
			where = " (puts on the %s%s)" % [step.assembly,
				" x%d" % step.copies.size() if step.copies.size() > 1 else ""]
		# The step it starts, which has no step of its own to be named in
		# (Step.within): the model's step that puts the copies on.
		if not step.within.is_empty():
			where = where.trim_suffix(")") + ("; " if not where.is_empty() else " (") \
				+ "starts the step %s)" % Motions.quoted(step.within)
		out.append(where)
	return out


## edit_steps' find=: the steps that place what [param said] names, found
## as the timeline's find finds them (StepsBar.find_in) and numbered as the
## list numbers them, each with how many it places and their numbers.
## Reads, and changes nothing.
func _found_steps(steps: Array[Instructions.Step], said: String) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var found: Dictionary = StepsBar.find_in(StepsBar.step_lots(steps, world), library, said)
	var hits: Array = found["hits"]
	var head: String = _steps_whose(steps)
	if hits.is_empty():
		return "%s\n%s." % [head, StepsBar.none_words(library, said, found["other"])]
	var takes: Dictionary = found["parts"]
	var colour: int = int(found["colour"])
	var wheres: PackedStringArray = _steps_where(steps)
	var placed: int = 0
	for hit: Array in hits:
		placed += int(hit[1])
	var lines := PackedStringArray([head, "“%s”: %d part%s, placed in %d step%s:" % [said, placed,
		"" if placed == 1 else "s", hits.size(), "" if hits.size() == 1 else "s"]])
	var characters: int = 0
	for n: int in hits.size():
		var hit: Array = hits[n]
		var step: Instructions.Step = steps[int(hit[0])]
		var numbers := PackedStringArray()
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null and takes.has(brick.part_id) \
					and (colour < 0 or brick.color_code == colour):
				numbers.append("#%d" % brick_id)
		if numbers.size() > 12:
			var more: int = numbers.size() - 12
			numbers = numbers.slice(0, 12)
			numbers.append("and %d more" % more)
		var what := Instructions.Step.new()
		what.parts = hit[2]
		var line: String = "  %d%s: %s, %s" % [step.number, wheres[int(hit[0])],
			what.summary(library), " ".join(numbers)]
		if not step.name.is_empty():
			line = "  %d%s %s: %s, %s" % [step.number, wheres[int(hit[0])],
				Motions.quoted(step.name), what.summary(library), " ".join(numbers)]
		characters += line.length()
		if characters > 6000:
			lines.append("  ... and %d more steps; a narrower find= lists fewer." % (hits.size() - n))
			break
		lines.append(line)
	return "\n".join(lines)


## Whether [param step] is one of a sub-model's own, built where it stands
## rather than in a callout.
static func _built_in_place(step: Instructions.Step) -> bool:
	return step.callout == 0 and step.authored_step >= 0 and not step.authored_in.is_empty()


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
	if kind == "band":
		for raw: Variant in input.get("sprockets", []):
			var brick: BrickWorld.Brick = _brick(int(raw))
			if brick == null or Bands.round_of(brick, library) == null:
				return "#%d is not round: a band goes round a pulley, a wheel, a bush or an axle." % int(raw)
			sprockets.append(brick.id)
		if sprockets.size() < 2:
			return "Give sprockets= two or more round parts' numbers, in order round the loop."
	elif chain:
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
	var laid: Flex.Laid = await flex.lay(kind, anchors, sprockets, colour, item,
		str(input.get("part", "")))
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


const NO_JOINTS := ("a joint is a sub-assembly on a hinge, a turntable, a clip on a bar or a ball. "
	+ "Name the part that turns as an assembly (edit_model's assemblies), standing on its hinge. "
	+ "Parts on pins, axles, studs and steering move without one, as a drag moves them: "
	+ "move_part with no part= lists them, and animate_model takes them by part (#14).")


## The turns a joint pose_model lists is tried at, each way, before it is
## said to have no room to turn.
const STUCK_DEGREES: Array[float] = [10.0, 90.0]


func _pose(input: Dictionary) -> String:
	var panel: PosePanel = app.get("_pose")
	# lock= checked before anything is read or written (jointlock): false is
	# the same as absent while nothing is locked.
	if input.has("lock"):
		if not input["lock"] is bool:
			return "lock= is true (lock the joint) or false (unlock it). Nothing was changed."
		var motions_now: Motions = (app.get("_world") as BrickWorld).motions
		if not bool(input["lock"]) and (motions_now == null or motions_now.locks.is_empty()):
			input = input.duplicate()
			input.erase("lock")
	if input.has("degrees") and not (input["degrees"] is float or input["degrees"] is int):
		return "degrees= is a number, -180 to 180. Nothing was changed."
	# The assemblies a design named are sub-models only once tagged, as a
	# save tags them; until then nothing in it could turn.
	if assistant != null:
		assistant._tag_assemblies()
	var joints: Array[Poser.Joint] = panel.joints_now()
	# A click hinge, a hinge or a turntable a drag turns, with no assembly
	# named on it, numbered after the assemblies' (mcpreach3). Read to list
	# them, or for one asked by a number past the assemblies', never to pose
	# an assembly's joint named: that waited 2.8 to 7.7 s on the read (m3review L2).
	var grabbing: GrabDrag = app.get("_grab_drag")
	var named_joint: Poser.Joint = _joint_named(joints, str(input["joint"]).strip_edges()) \
		if input.has("joint") else null
	var drags: Array = []
	if named_joint == null:
		drags = await _drag_joints(grabbing, joints)
	if input.has("joint") and not drags.is_empty():
		var picked: String = str(input["joint"]).strip_edges().trim_prefix("#")
		# A drag joint by a part of it ("#357"), as a session read its number.
		if picked.is_valid_int() and int(picked) > joints.size() + drags.size():
			for n: int in drags.size():
				if (drags[n][2] as PackedInt64Array).has(int(picked)):
					picked = str(joints.size() + n + 1)
		if picked.is_valid_int() and int(picked) > joints.size() \
				and int(picked) <= joints.size() + drags.size():
			var drag: Array = drags[int(picked) - joints.size() - 1]
			if not input.has("lock"):
				return await _pose_drag(grabbing, drag, input)
			return await _with_lock(panel, _drag_sides(drag), input, func() -> String:
				return await _pose_drag(grabbing, drag, input))
	if joints.is_empty() and drags.is_empty():
		var world: BrickWorld = app.get("_world")
		var builder: Builder = app.get("_builder")
		var ids := PackedInt64Array()
		for brick: BrickWorld.Brick in world.bricks():
			ids.append(brick.id)
		var on_balls: String = JointSnap.balls_said(world, app.get("_library"), builder.lattice, ids)
		var motors: String = _motors_driven(world, app.get("_store"), app.get("_library"))
		return "Nothing here turns: " + NO_JOINTS + ("" if on_balls.is_empty() else " " + on_balls) \
			+ ("" if motors.is_empty() else " " + motors) + await _pose_holds()
	# A model with one joint: degrees= and lock= need no joint= (g2's session
	# listed the joints only to read "1").
	if not input.has("joint") and (input.has("degrees") or input.has("lock")):
		if joints.size() + drags.size() == 1:
			var one: Dictionary = input.duplicate()
			one["joint"] = "1"
			return await _pose(one)
		return ("degrees= and lock= need joint=: this model has %d joints, listed by pose_model with no "
			+ "arguments. Nothing was changed.") % (joints.size() + drags.size())
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
			said.append("  %d. %s, on its %s, at %d° (%d parts)%s%s" % [n + 1,
				one.label(), one.kind(), roundi(one.angle), one.ids.size(),
				", with no room to turn 10° or 90° either way" if held else "",
				", locked" if not panel.poser.lock_words(one).is_empty() else ""])
		for n: int in drags.size():
			said.append("  %d. %s" % [joints.size() + n + 1, _drag_joint_words(grabbing, drags[n])])
		if stuck > 0:
			said.append("A joint with no room is often not what moves: move_part with no part= "
				+ "lists what a drag moves, and animate_model takes those by part (#14).")
		elif not drags.is_empty():
			# As "Nothing here turns" said it before a drag's hinges were listed.
			said.append("Parts on pins, axles, studs and steering move without an assembly too, as "
				+ "a drag moves them: move_part with no part= lists them, and animate_model takes "
				+ "them by part (#14).")
		return "Joints:\n%s\npose_model {\"joint\": \"1\", \"degrees\": 45} swings one.%s" \
			% ["\n".join(said), await _pose_holds()]
	var asked: String = str(input["joint"]).strip_edges()
	var joint: Poser.Joint = named_joint
	if joint == null:
		return "No joint %s: there are %d, numbered in pose_model's list." % [asked,
			joints.size() + drags.size()]
	if input.has("lock"):
		var moving: Dictionary = {}
		for id: int in joint.ids:
			moving[id] = true
		var posed: Dictionary = input.duplicate()
		posed.erase("lock")
		return await _with_lock(panel, [moving, joint.pair], input, func() -> String:
			return await _pose(posed) if posed.has("degrees") else "%s is at %d°." % [joint.label(),
				roundi(joint.angle)])
	if not input.has("degrees"):
		var held_said: String = panel.poser.lock_words(joint)
		return "%s is at %d°%s. Give degrees= to swing it." % [joint.label(), roundi(joint.angle),
			"" if held_said.is_empty() else "; " + held_said]
	var wanted: float = clampf(float(input["degrees"]), -180.0, 180.0)
	var world: BrickWorld = app.get("_world")
	var before: Vector3 = _middle_of(world, joint.ids)
	var reached: float = panel.set_angle(joint.path, wanted)
	if not panel.poser.refused.is_empty():
		return "%s. Nothing was changed." % panel.poser.refused
	# Which way it went, in the plates look_at_model counts: a turn goes by
	# the right hand about its axis, so +30° about x takes a +z end down.
	# f1's session read edit_model's pitch (+ lifts the +z end) into it,
	# swung its arm down, and looked at a picture to find out.
	var rose: float = (_middle_of(world, joint.ids).y - before.y) / BrickLattice.PLATE
	var went: String = "" if absf(rose) < 0.25 else ", its parts' middle %s plates %s" % [
		Balance.studs(absf(rose)), "higher" if rose > 0.0 else "lower"]
	if absf(reached - wanted) > 0.5:
		return "%s stops at %d°%s: any further and it runs into something.%s" % [
			joint.label(), roundi(reached), went, await _pose_holds()]
	return "%s at %d°%s.%s" % [joint.label(), roundi(reached), went, await _pose_holds()]


## The joints a drag turns that no assembly is named on: each a body on a
## click hinge, a hinge or a turntable (Bodies.parent_link), as [body key,
## Bodies.Link, its parts], biggest first, none whose parts a joint of
## [param named] moves. r2's session built an arm on a click hinge, asked
## pose_model, and was told "Nothing here turns" until it named the arm an
## assembly (APP_UX10's walk; mcpreach3): a drag found its hinge at once.
const DRAG_JOINT_KINDS: Array[String] = ["click", "hinge", "turntable"]
## How many of them pose_model lists.
const MOST_DRAG_JOINTS := 8


func _drag_joints(grabbing: GrabDrag, named: Array[Poser.Joint]) -> Array:
	if grabbing == null:
		return []
	# Read on a worker, as move_part reads them: on this thread a big model's
	# joints held the window seconds.
	if not grabbing.is_ready():
		await grabbing._ready_for_session()
	var bodies: Bodies = grabbing.read_bodies()
	if bodies == null:
		return []
	var posed: Dictionary = {}
	for joint: Poser.Joint in named:
		for id: int in joint.ids:
			posed[id] = true
	var out: Array = []
	for key: Variant in bodies.parent_link:
		var link: Bodies.Link = bodies.parent_link[key]
		if bodies.flexible.has(key) or not link.turns or not DRAG_JOINT_KINDS.has(link.kind):
			continue
		var ids: PackedInt64Array = bodies.members.get(key, PackedInt64Array())
		if ids.is_empty() or posed.has(int(ids[0])):
			continue
		out.append([int(key), link, ids])
	out.sort_custom(func(x: Array, y: Array) -> bool:
		return (x[2] as PackedInt64Array).size() > (y[2] as PackedInt64Array).size())
	return out.slice(0, MOST_DRAG_JOINTS)


## A drag joint's line in pose_model's list: the part a drag takes it by,
## its joint and where, and where it stands from where it was built.
func _drag_joint_words(grabbing: GrabDrag, drag: Array) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var link: Bodies.Link = drag[1]
	var ids: PackedInt64Array = drag[2]
	var brick: BrickWorld.Brick = world.get_brick(int(ids[0]))
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
	var angle: String = "as built"
	var held: Variant = grabbing.held_of([int(ids[0])])
	if held is Grab:
		var built: float = (held as Grab).from_built()
		if not is_nan(built) and roundi(wrapf(built, -180.0, 180.0)) != 0:
			angle = "%d° from where it was built" % roundi(wrapf(built, -180.0, 180.0))
	var locked: bool = world.motions != null and not world.motions.locks.is_empty() \
		and world.motions.lock_split(_drag_sides(drag)[0], world, app.get("_builder")) != null
	return "#%d %s%s, %s at %s, %s (%d part%s)%s%s" % [int(ids[0]),
		Inventory._tidy(info.name) if info != null else brick.part_id if brick != null else "?",
		" and what is built on it" if ids.size() > 1 else "", link.words(),
		GrabDrag.at_words(link.point), angle, ids.size(), "" if ids.size() == 1 else "s",
		", clicking every %s°" % Balance.tidy(link.detent) if link.detent > 0.0 else "",
		", locked" if locked else ""]


## pose_model joint= one of [method _drag_joints]: turned to degrees= from
## where it was built, as move_part turns it (GrabDrag.for_session), one
## step to undo; with no degrees=, where it stands.
func _pose_drag(grabbing: GrabDrag, drag: Array, input: Dictionary) -> String:
	var ids: PackedInt64Array = drag[2]
	var part: String = "#%d" % int(ids[0])
	var held: Variant = grabbing.held_of([int(ids[0])])
	if not held is Grab:
		return "%s does not turn just now: %s." % [part, str(held)]
	var built: float = (held as Grab).from_built()
	var now: float = 0.0 if is_nan(built) else wrapf(built, -180.0, 180.0)
	if not input.has("degrees"):
		return ("%s is at %d° from where it was built. Give degrees= to swing it: degrees are from "
			+ "where it was built, turned by the right hand about its line.") % [_drag_joint_words(grabbing,
				drag), roundi(now)]
	var wanted: float = clampf(float(input["degrees"]), -180.0, 180.0)
	var said: String = await grabbing.for_session({"part": part, "degrees": wanted - now})
	return "%s, to %d° from where it was built:\n%s%s" % [part, roundi(wanted), said,
		await _pose_holds()]


## The parts a drag joint ([method _drag_joints]) turns, and the two it turns
## between, [its own, the one it is on]: what its lock locks.
static func _drag_sides(drag: Array) -> Array:
	var link: Bodies.Link = drag[1]
	var ids: PackedInt64Array = drag[2]
	var moving: Dictionary = {}
	for id: int in ids:
		moving[id] = true
	for pair: Array in link.pairs:
		if moving.has(int(pair[0])) and not moving.has(int(pair[1])):
			return [moving, [int(pair[0]), int(pair[1])]]
		if moving.has(int(pair[1])) and not moving.has(int(pair[0])):
			return [moving, [int(pair[1]), int(pair[0])]]
	return [moving, []]


## pose_model's lock= on the joint that turns [param sides] ([moving, pair]):
## [param input]'s lock=false unlocks it before [param pose] runs, true locks
## it after, each one step to undo; and [param pose]'s answer with what the
## lock did. A joint the lock holds refuses [param pose] with its words.
func _with_lock(panel: PosePanel, sides: Array, input: Dictionary, pose: Callable) -> String:
	var lines := PackedStringArray()
	if input.has("lock") and not bool(input["lock"]):
		lines.append(panel.set_lock(sides[0], sides[1], false))
	if input.has("degrees") or not input.has("lock"):
		lines.append(await pose.call())
	if input.has("lock") and bool(input["lock"]):
		var refused: bool = lines.size() > 0 and lines[lines.size() - 1].contains(Motions.UNLOCK_WORDS)
		if not refused:
			lines.append(panel.set_lock(sides[0], sides[1], true))
			# What a turn of it now does, tried on a drag's grab, nothing moved.
			var turned: Variant = (app.get("_grab_drag") as GrabDrag).held_of(Array(sides[1]).slice(0, 1)) \
				if (sides[1] as Array).size() == 2 else null
			if turned is String and str(turned).contains(Motions.UNLOCK_WORDS):
				lines.append(("Tried just now, the way a turn of it comes (a drag of its part, as "
					+ "move_part takes it, and pose_model's swing): refused, and nothing moved, so it stands "
					+ "exactly where it was locked. A turn tried again is refused the same way: %s.") % (
					str(turned).get_slice(":", 0)))
	# Which others are locked, so a session unlocking one knows what still holds.
	var world: BrickWorld = app.get("_world")
	if input.has("lock") and world.motions != null and not world.motions.locks.is_empty():
		var named := PackedStringArray()
		for lock: Motions.Lock in world.motions.locks.slice(0, 10):
			named.append(Motions.lock_name(lock, world, app.get("_library"), app.get("_builder")))
		var more: int = world.motions.locks.size() - named.size()
		lines.append("Locked now: %s%s." % [", ".join(named), " and %d more" % more if more > 0 else ""])
	return "\n".join(lines)


## Whether the model holds its pose as it stands now (posehold), as Pose
## says it: each friction joint past what one of its kind was measured to
## hold (data/joint_hold.json), with how far over, and the joints whose hold
## nobody has measured. "" for a model with no friction joint.
func _pose_holds() -> String:
	if not app.has_method("weigh_joints"):
		return ""
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var generation: int = world.generation()
	var report: Stability.Report = await app.call("weigh_joints")
	if report == null or report.balance == null or world.generation() != generation:
		return ""
	var named := func(id: int) -> String:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		return "#%d %s" % [id, Inventory._tidy(info.name) if info != null else brick.part_id if brick != null else "?"]
	var words: String = PoseHold.pose_words(report.balance, named, 8)
	return "" if words.is_empty() else "\nThe pose, each friction joint against what one of its kind holds: " + words


## The middle of where these parts stand.
static func _middle_of(world: BrickWorld, ids: PackedInt64Array) -> Vector3:
	var sum := Vector3.ZERO
	var count: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			sum += brick.transform.origin
			count += 1
	return sum / maxi(count, 1)


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
	var motors: String = _motors_driven(world, store, library)
	if moving.is_empty():
		lines.append("Nothing in it hangs on a joint: every part is held rigidly to what stays (%s)."
			% bodies.summary())
		if not motors.is_empty():
			lines.append(motors)
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
	if not motors.is_empty():
		lines.append(motors)
	lines.append("Nothing was changed. move_part part=N says what moving it does; degrees= turns it.")
	return "\n".join(lines)


## The joint a session names: its number in pose_model's list, its path or
## its name. Null when none is.
static func _joint_named(joints: Array[Poser.Joint], asked: String) -> Poser.Joint:
	asked = asked.strip_edges()
	if asked.is_valid_int() and int(asked) >= 1 and int(asked) <= joints.size():
		return joints[int(asked) - 1]
	for one: Poser.Joint in joints:
		if one.path == asked or one.label().to_lower() == asked.to_lower():
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
			if joint != null and joint.kind() == "ball":
				# A motion keeps a turn about one line, and a ball's is about
				# three: kept, it would be a new kind of line in the file.
				return ("%s is a ball's turn: pose_model sets it; a motion turns a joint about one "
					% joint.label() + "line, so animate_model takes hinges, turntables, clips and "
					+ "parts on pins and axles.")
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
			+ "plays it; one step: undo takes it out.%s") % [Motions.quoted(ANIMATION), _let_go_said(motions)]
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
	# Its file's motion lines this could not read, kept in it as they are.
	if not motions.unread.is_empty():
		var unread: String = motions.unread_words()
		lines.append("%s%s." % [unread.left(1).to_upper(), unread.substr(1)])
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
	# unit spikemotors
	var motors: String = _motors_said(world, store, app.get("_library"))
	if not motors.is_empty():
		lines.append(motors)
	# end unit spikemotors
	lines.append("play_motion {\"name\": …} plays one (reverse=true backwards); render_motion renders "
		+ "it. Nothing was changed.")
	return "\n".join(lines)


## The motors, and that what is on a motor's output turns when the motor
## drives it, not by a drag or a pose (mcpreach2): a drag holds a motor
## whole, case and hub, so move_part listed an arm pinned to a SPIKE motor's
## hub as moving with the case, pose_model said "Nothing here turns", and
## APP_UX9's y6 session told the person Simulate "doesn't treat the motor's
## output hub as something that turns" without asking it. "" for none.
static func _motors_driven(world: BrickWorld, store: ModelStore, library: PartLibrary) -> String:
	var motors: String = _motors_said(world, store, library)
	if motors.is_empty():
		return ""
	return motors + (" What is keyed or pinned into a motor's output turns when the motor drives "
		+ "it, not by a drag or a pose: simulate_mechanism driver=<the motor's number> turns it, and "
		+ "attachment_points brick=<the motor's number> names the output's holes.")


# unit spikemotors
## The motors the model holds, each by name with its stall and speed at its
## volts (Simulation.MOTORS), and what Simulate does with one; "" for none.
static func _motors_said(world: BrickWorld, store: ModelStore, library: PartLibrary) -> String:
	var said := PackedStringArray()
	var count: int = 0
	var motors: Dictionary = Simulation.motors_in(world.bricks(), library)
	for id: int in motors:
		if store.scenery.has(id):
			continue
		var made: String = motors[id]
		count += 1
		if said.size() < 6:
			var it: Array = Simulation.MOTORS[made]
			said.append("#%d the %s (%s): it stalls at %s N·cm and turns %s rpm with no load, at %s V" % [
				id, it[0], made, Simulation.figure(float(it[1])),
				Simulation.figure(float(it[2])), Simulation.figure(float(it[3]))])
	if count == 0:
		return ""
	if count > said.size():
		said.append("and %d more" % (count - said.size()))
	return ("Motors in it: %s. simulate_mechanism turns the model from one and says where it stalls "
		+ "under what it lifts.") % "; ".join(said)
# end unit spikemotors


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
	# unit drive
	if motion.path != null:
		out.append("    The whole model driven %s, over %s s%s, from where it stands. %s" % [motion.path.said(),
			Motions.num(motion.path.seconds, 2), ", eased" if motion.path.how == "EASE" else "",
			player.path_words(motion.path)])
	# end unit drive
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
		return "Took %s out of the model. One step: undo puts it back.%s" % [Motions.quoted(name),
			_let_go_said(motions)]
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
		if input.has("tracks") or input.has("driver") or input.has("path"):
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
	var let_go: String = _let_go_said(motions)
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
		+ "model put back: %s. play_motion plays it%s; one step: undo takes it out.%s") % [
		"Changed" if replaced else "Kept", Motions.quoted(name), Motions.num(motion.length(), 2), joints,
		"" if joints == 1 else "s", (" after %s, which it follows" % ", then ".join(first))
		if not first.is_empty() else "", player.said(played), (" alone, from where the model stands, and "
		+ "with sequence=true after %s" % ", then ".join(first)) if not first.is_empty() else "", let_go]


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
	var let_go: String = _let_go_said(motions)
	builder.record([{"undo": "motions", "motions": had}], "%s the sequence %s" % [
		"changed" if replaced else "made", Motions.quoted(motion.name)])
	var drawn: MotionRender = MotionRender.frames_of(player, [motion], false, MotionPlayer.PLAY_FPS)
	player.results[motion.name.to_lower()] = " ".join(drawn.lines)
	return ("%s %s in the model, a sequence of %d (%s s): %s, each from where the one before left the "
		+ "model. It is saved with it. Played once to check, and the model put back: %s play_motion plays "
		+ "it (reverse=true backwards, in reverse order), render_motion renders it whole; one step: undo "
		+ "takes it out.%s") % ["Changed" if replaced else "Kept", Motions.quoted(motion.name),
		motion.sequence.size(), Motions.num(motions.seconds_of(motion), 2), ", then ".join(Array(motion.sequence).map(
		func(one: String) -> String: return Motions.quoted(one))), " ".join(drawn.lines), let_go]


## What [param motions]' last change let go of the lines it did not read
## (Motions.let_go_words), as a sentence after a reply's own; "" for none.
static func _let_go_said(motions: Motions) -> String:
	return "" if motions.let_go.is_empty() else " %s." % motions.let_go_words()


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
	# unit drive: the whole model driven along a path.
	if input.has("path"):
		if not (input["path"] is Dictionary):
			return "path= is {\"legs\": [{\"straight\": 32}, {\"left\": 90}], \"seconds\": 7}."
		var path: Variant = player.path_from(input["path"])
		if path is String:
			return "%s" % path
		motion.path = path
	# end unit drive
	if motion.tracks.is_empty() and motion.driver == null and motion.path == null:
		return ("Give tracks= (each a joint and its keys), driver= (a joint and how many times to "
			+ "turn it) or path= (where the whole model drives); list_motions suggests some.")
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
	var sheet_at: Array = _six_of(poses.size())
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
	lines.append("The picture: %d of its frames, at %s, left to right and down, the last its end."
		% [times.size(), _times_words(times)])
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
	var store: ModelStore = app.get("_store")
	for _n: int in count:
		var words: String = builder.redo_words() if again else (
			builder.history_words(1)[0] if builder.history_depth() > 0 else "")
		# Past every change, the open they followed (ModelStore.reopen).
		if words.is_empty() and (not again or builder._redo.is_empty()):
			words = store.reopen_words(again)
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
	var next: String = builder.history_words(1)[0] if builder.history_depth() > 0 \
		else store.reopen_words()
	var left: String = ("Next to undo: %s." % next) if not next.is_empty() else "Nothing more to undo."
	var back: String = builder.redo_words() if builder._redo.size() > 0 else store.reopen_words(true)
	if not back.is_empty():
		left += " undo {\"redo\": true} puts back %s." % back
	return "%s %s. %s" % ["Redid" if again else "Undid", "; ".join(done), left]


# -- opening -----------------------------------------------------------------------


func _open(input: Dictionary) -> String:
	if bool(input.get("into", false)):
		return await _open_into(input)
	var store: ModelStore = app.get("_store")
	var replace: bool = bool(input.get("replace_moved", false))
	var opening: bool = false
	for key: String in ["name", "link", "library"]:
		opening = opening or not str(input.get(key, "")).strip_edges().is_empty()
	# replace_moved alone: in the model open now.
	if replace and not opening:
		return await _moved_said(store, true)
	var kept: String = ""
	# Only a file name asks for it: false, null or "" are as if not sent.
	var save_first: Variant = input.get("save_first")
	if opening and save_first is String and not (save_first as String).strip_edges().is_empty():
		kept = _save_first(store, save_first as String)
		if not kept.is_empty() and not kept.begins_with("Saved "):
			return kept
	var before: int = store.world.generation()
	var said: String = await _open_now(input)
	# Opened: what its file names by a moved or alias number, or has no file
	# for, said; and with replace_moved, the moved and alias ones replaced.
	if store.world.generation() == before or not store.not_opened.is_empty():
		return _first(kept, said)
	return _first(kept, said + await _moved_said(store, replace))


## open_model save_first=: the model on the baseplate saved in the person's
## models under [param asked], as save_model saves it, before an open over
## it; "Saved ..." said, "" with nothing to save, or why not. g1's session was refused the open over
## a car it had built, then refused the save, and stopped to ask the person
## which of three ways to go (APP_UX10's walk; mcpreach3): the window's own
## Save changes? asks once and saves, and this is that Save.
func _save_first(store: ModelStore, asked: String) -> String:
	if not store.has_unsaved_work():
		return ""
	var file: String = CommandSocket._model_file(asked)
	if file.is_empty():
		return "save_first takes a file name, such as car.ldr; nothing was saved or opened."
	var path: String = ModelStore.SAVE_DIR + file
	if FileAccess.file_exists(path) and path != store.saved_path(store.title):
		return ("There is already a model called %s, and it is not this one: save_first takes "
			+ "another name. Nothing was saved or opened.") % file
	if assistant != null:
		assistant._tag_assemblies()
	if not bool(app.call("save_model", path)):
		return "Could not write %s; nothing was opened." % file
	return "Saved %s as %s, in the person's models, where Open finds it." % [store.title, file]


static func _first(before: String, then: String) -> String:
	return then if before.is_empty() else "%s %s" % [before, then]


## open_model's word on the parts the model open now names by a number LDraw
## has moved or keeps as an alias, or has no file for (ModelStore.moved), as
## the person's bar over the model and its list offer them; with [param
## replace] (replace_moved=true), the moved and alias ones written as the
## parts they point to in every sub-model, one step to undo, as its Update
## all does (ModelBar.replace_moved). Each number in a few words, at most
## MovedParts.SAID_ROWS of them and how many more: 10179-1's every sub-model
## named was 5,000 characters (mvreview F5).
func _moved_said(store: ModelStore, replace: bool) -> String:
	var renumbered := PackedStringArray()
	var absent := PackedStringArray()
	var numbers: Array = store.moved.keys()
	numbers.sort()
	for number: String in numbers:
		var row: Dictionary = store.moved[number]
		if str(row["kind"]) == MovedParts.MISSING:
			absent.append("%s (%s)" % [number, MovedParts.used_words(row)])
		else:
			renumbered.append("%s %s (%s)" % [number, MovedParts.why_words(row), MovedParts.used_words(row)])
	var said: String = ""
	# Not in a Build together session: the others' copies are not changed
	# with it, as the person's own bar refuses it there.
	var together: Node = app.get("_together_made")
	if replace and not renumbered.is_empty() and together != null and bool(together.get("live")):
		return (" Not replaced: the person is in a Build together session, whose others' copies "
			+ "would keep the old numbers; replace them once they leave it (File › Build "
			+ "together…). Its moved and alias parts: %s.") % _some(renumbered)
	if replace and not renumbered.is_empty():
		var bar: ModelBar = app.get("_bar")
		var done: String = bar.replace_moved(store.moved.keys())
		if done.begins_with("Could not"):
			return " " + done
		said = (" Replaced, in every sub-model, as one step (undo puts back the file as it was): "
			+ "%s.") % done.get_slice(" — ", 0)
		absent.clear()
		for number: String in store.moved:
			var row: Dictionary = store.moved[number]
			if str(row["kind"]) == MovedParts.MISSING:
				absent.append("%s (%s)" % [number, MovedParts.used_words(row)])
	elif replace:
		said = " Nothing to replace: no part of it is named by a moved or alias number."
	elif not renumbered.is_empty():
		said = (" Its file names parts by %d numbers LDraw has moved or keeps as aliases; each is "
			+ "drawn as the part it points to, and the file keeps the old number: %s. "
			+ "open_model replace_moved=true writes them as those parts in every sub-model, as one "
			+ "step, as the person's Update all does.") % [renumbered.size(), _some(renumbered)]
	if not absent.is_empty():
		said += (" No file in the library, kept in the file and not shown: %s; search_parts finds "
			+ "one like it.") % _some(absent)
	return said


## At most MovedParts.SAID_ROWS of [param rows], and how many more.
static func _some(rows: PackedStringArray) -> String:
	if rows.size() <= MovedParts.SAID_ROWS:
		return "; ".join(rows)
	return "%s; and %d more" % ["; ".join(rows.slice(0, MovedParts.SAID_ROWS)),
		rows.size() - MovedParts.SAID_ROWS]


func _open_now(input: Dictionary) -> String:
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
	# A model's saves with no name: the model open now's.
	if name.is_empty() and bool(input.get("versions", false)) and not store.example \
			and store.title != ModelStore.UNTITLED:
		name = store.title
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
		if input.has("version"):
			return _compare(chosen, kept, int(input["version"]))
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
	var unsaved: bool = store.has_unsaved_work()
	var was: String = store.title
	if unsaved and not bool(input.get("discard_changes", false)):
		return _unsaved_refusal(store)
	if assistant != null:
		assistant.forget_built()
	if version >= 1:
		var landed: int = await bar.open_version(kept[version - 1], chosen.name)
		if landed < 0:
			return "Could not open that version of %s: %s. The model on the baseplate, %s, is as it was." % [
				chosen.name, store.not_opened, store.title]
		return ("Opened %s as saved %s: %d parts. look_at_model to see it. The person's Save "
			+ "makes it the newest save.") % [chosen.name, kept[version - 1].when(), landed] \
			+ _replaced_words(store, unsaved, was) + _opened_motions()
	var placed: int = await bar.open_with_progress(chosen.path)
	if placed < 0:
		return "Could not open %s: %s. The model on the baseplate, %s, is as it was." % [
			chosen.name, store.not_opened, store.title]
	bar.opened.emit(placed)
	return "Opened %s: %d parts%s. look_at_model to see it." % [chosen.name, placed,
		ModelBar.unshown_words(store)] + _replaced_words(store, unsaved, was) + _opened_motions()


## open_model versions=true version=N: what changed in the model open now
## since its save [param version] of [param kept], as File, Compare, Compare with…
## matches it (ModelDiff), and inside the sub-assembly the person is editing
## when they are; opening nothing and drawing nothing.
func _compare(chosen: ModelStore.Entry, kept: Array[ModelVersions.Version], version: int) -> String:
	var store: ModelStore = app.get("_store")
	if version < 1 or version > kept.size():
		return "%s has %d versions: version is 1 (the newest) to %d. versions=true lists them." % [
			chosen.name, kept.size(), kept.size()]
	if chosen.example or chosen.name.to_lower() != store.title.to_lower():
		return ("A save is compared with the model open now, %s; %s is not open. open_model "
			+ "name=%s opens it first.") % [store.title, chosen.name, chosen.name]
	var text: String = ModelVersions.read(kept[version - 1].path)
	if text.is_empty():
		return "That save of %s could not be read." % chosen.name
	var shell: Shell = app.get("_shell")
	var inside: String = shell.assemblies.entered if shell != null and shell.assemblies != null \
		else ""
	var library: PartLibrary = app.get("_library")
	var diff: ModelDiff = ModelDiff.between(ModelDiff.parts_of_text(text, library, inside),
		ModelDiff.parts_of_world(app.get("_world"), store.scenery, store.lift(), store.awaited_now(),
			inside))
	return CompareView.said_of(diff, kept[version - 1], inside, library) \
		+ "\nNothing was opened or changed. File, Compare, Compare with… shows the person the same."


## Why an open is refused: the person's changes would go, and a session
## does not discard them unasked.
static func _unsaved_refusal(store: ModelStore) -> String:
	return ("Not opened: the model on the baseplate, %s, has changes that are not saved, "
		+ "and they are the person's. To keep them, open again with save_first= a file name "
		+ "(car.ldr): it is saved in their models first, never refused, then opened over. Or "
		+ "ask the person and give discard_changes=true: undo then brings their model back.") \
		% store.title


## What an open that took a model off the baseplate says of it: " The model
## it replaced, X, was not saved: undo brings it back."; "" when there was
## none, or it was saved as it stood.
static func _replaced_words(store: ModelStore, unsaved: bool, replaced: String) -> String:
	if not unsaved or not store.can_reopen():
		return ""
	return " The model it replaced, %s, was not saved: undo brings it back." % replaced


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
	var unsaved: bool = store.has_unsaved_work()
	var was: String = store.title
	if unsaved and not discard:
		return _unsaved_refusal(store)
	var answer: Dictionary = await shared.fetch(id)
	if int(answer["code"]) != 200 or not answer["body"] is Dictionary:
		return "Could not open %s: %s." % [id, SharedModels.trouble(answer, "the gallery did not answer")]
	var body: Dictionary = answer["body"]
	# What gallery open= will not show, this will not open (a bench's run).
	if GalleryTool.held(body):
		return GalleryTool.held_words(body, id)
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
	return ("Opened a copy of %s (%s)%s: %s, saved in the person's models as %s, theirs to "
		+ "change; the shared one stays as it was, and sharing this one says it was remixed from "
		+ "it. Licence %s. look_at_model to see it.") % [name, url,
		", by %s" % author if not author.is_empty() else "",
		await _parts_against_box(store, ""), kept, terms] \
		+ _replaced_words(store, unsaved, was) + _opened_motions()


## The opened model's part count as a builder counts it (Inventory.pieces_in),
## and what else the model holds and its box says where they differ: the Cat
## D11 "3,868 parts (6,793 pieces drawn: a cable, a hose or a motor's case is
## drawn in segments)", 6680-1 "76 parts (its box holds 67)". [param number]
## is its set's, or "" for none to ask after.
func _parts_against_box(store: ModelStore, number: String) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var parts: int = Inventory.pieces_in(world, library, store.scenery)
	var drawn: int = world.brick_count() - store.scenery.size()
	var said := PackedStringArray()
	if drawn != parts:
		said.append("%s pieces drawn: a cable, a hose or a motor's case is drawn in segments"
			% CollectionDialog._comma(drawn))
	if not number.is_empty():
		var box: int = await ModelLibrary.box_of(number)
		if box > 0 and not ModelLibrary.agrees(parts, box):
			said.append("its box holds %s" % CollectionDialog._comma(box))
	return "%s parts%s" % [CollectionDialog._comma(parts),
		" (%s)" % "; ".join(said) if not said.is_empty() else ""]


## The library id of LDraw's model of the set [said] names: its number
## ("10179" is 10179-1) or the only one its words name; "" for none.
func _library_id_of(books: ModelLibrary, said: String) -> String:
	var every: Array = await books.models()
	var number: String = SetInventories.normal(said)
	for entry: Dictionary in every:
		if str(entry["set"]).to_lower() == number and str(entry.get("alternate_of", "")).is_empty():
			return str(entry["id"])
	var found: Dictionary = ModelLibrary.search(every, {"q": said.left(100), "theme": "", "decade": "",
		"size": "", "sort": "newest", "page": 1})
	return str(found["models"][0]["id"]) if int(found["total"]) == 1 else ""


## open_model library=: LDraw's model of a real set, from the library File,
## Library… shows (ModelLibrary), opened in place of what is on the baseplate
## as open_model name= opens one, credited to whoever made it
## (ModelStore.credit). Not saved: it is the person's to save, as a set
## opened from the window is.
# -- a model into this one ----------------------------------------------------------


## open_model into=true: a saved model, an example (name=), LDraw's model of
## a real set (library=) or a gallery model (link=) put into the model open
## now as one sub-assembly with its author's steps, as File, Import, Into this
## model… and the library's Put in this model do, in one call: put down
## beside the model, or with its low corner at x= and z= studs, turned turn=
## quarter turns, on whatever is under it there. Nothing is replaced, so
## nothing unsaved is asked after; one undo takes it all out. A set or a
## gallery model goes in only where its licence lets it be built on
## (LibraryDialog.may_build_on), its maker credited in its sub-model's header.
func _open_into(input: Dictionary) -> String:
	var store: ModelStore = app.get("_store")
	var builder: Builder = app.get("_builder")
	var name: String = str(input.get("name", "")).strip_edges().trim_suffix(".ldr")
	var text: String = ""
	var called: String = ""
	var credit: String = ""
	var credited: Dictionary = {}
	var file: String = ""
	if not str(input.get("library", "")).strip_edges().is_empty():
		var books: ModelLibrary = app.get("_model_library")
		if books == null:
			return "This app has no library."
		var id: String = str(input["library"]).strip_edges()
		if not ModelLibrary.is_id(id):
			id = await _library_id_of(books, id)
			if id.is_empty():
				return "LDraw's library has no 3D model of %s. gallery library=true q= finds a set." \
					% str(input["library"])
		var entry: Dictionary = await books.find(id)
		if entry.is_empty():
			return books.trouble + " gallery library=true q= finds a set."
		if not LibraryDialog.may_build_on(str(entry["licence"])):
			return "%s's licence (%s) does not let it be put in another model." % [
				ModelLibrary.title_of(entry), entry["licence"]]
		var got: Dictionary = await books.model_text(entry)
		if not str(got["error"]).is_empty():
			return "Could not fetch %s: %s" % [ModelLibrary.title_of(entry), got["error"]]
		text = str(got["text"])
		called = ModelLibrary.title_of(entry)
		file = str(entry["file"]).get_file()
		credited = ModelLibrary.credit_of(entry)
		credit = ModelBar.credit_words(credited) + (" (%s)" % entry["page"]
			if not str(entry["page"]).is_empty() else "")
	elif not str(input.get("link", "")).strip_edges().is_empty():
		var link: String = str(input["link"]).strip_edges()
		var id: String = link.get_slice("/m/", 1).get_slice("/", 0).get_slice("?", 0).get_slice(".", 0) \
			if link.contains("/m/") else link
		var shared: SharedModels = app.get("_shared")
		if not SharedModels.is_id(id) or shared == null:
			return ("link is a gallery model's link id, ten letters and digits (gallery lists them), "
				+ "or its address, https://brickworks.diy/m/<id>.")
		var answer: Dictionary = await shared.fetch(id)
		if int(answer["code"]) != 200 or not answer["body"] is Dictionary:
			return "Could not fetch %s: %s." % [id, SharedModels.trouble(answer, "the gallery did not answer")]
		var body: Dictionary = answer["body"]
		if GalleryTool.held(body):
			return GalleryTool.held_words(body, id)
		called = str(body.get("name", "Shared model"))
		if not LibraryDialog.may_build_on(str(body.get("licence", ""))):
			return ("%s's builder kept every right to it (%s): open_model link= opens a copy to "
				+ "build; it cannot go into another model without their leave.") % [called,
				GalleryTool._licence_name(body.get("licence"))]
		text = str(body.get("model", ""))
		file = id + ".ldr"
		credited = SharedModels.credit_of(body, id)
		credit = ModelBar.credit_words(credited) + " (%s)" % str(
			body.get("url", SharedModels.link_for(id)))
	else:
		var chosen: ModelStore.Entry = null
		for entry: ModelStore.Entry in store.list_saved() + store.list_examples():
			if chosen == null and not name.is_empty() and (entry.name.to_lower() == name.to_lower()
					or entry.example and entry.path.get_file().get_basename() == name.to_lower()):
				chosen = entry
		if chosen == null:
			return ("%s open_model with no name lists the saved models and the examples; "
				+ "into=true with name= puts one in this model, library= a real set's.") % (
				"No model called %s." % name if not name.is_empty() else "Which model? name= one.")
		text = store._file_text(chosen.path)
		if text.is_empty():
			return "Could not read %s: %s." % [chosen.name, store.not_opened]
		called = chosen.name
		file = chosen.path.get_file()
	var held: Dictionary = await store.held_from(text, file, null, called, credited)
	if not str(held["error"]).is_empty():
		return "Could not put %s in this model: %s. The model is as it was." % [called, held["error"]]
	builder.cancel_carry()
	builder.hold_copy(held["items"])
	builder.carrying.bring(held)
	builder.carrying.turn(clampi(int(input.get("turn", 0)), 0, 3))
	var spot: Variant = _into_spot(builder, input)
	if spot == null:
		builder.cancel_carry()
		return ("There is no room for %s %s. x= and z= put its low corner somewhere clear; the "
			+ "model is as it was.") % [held["name"], "there" if input.has("x") or input.has("z")
				else "beside the model"]
	var first: int = builder.place()
	if first == 0:
		builder.cancel_carry()
		return "Could not put %s down. The model is as it was." % held["name"]
	var world: BrickWorld = app.get("_world")
	var path: String = Assemblies.path_of(world.get_brick(first))
	var box := AABB()
	var count: int = 0
	for brick_id: int in builder.selection:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var mesh: Lbm.PartMesh = (app.get("_library") as PartLibrary).mesh_for(brick.part_id)
		if mesh == null:
			continue
		var here: AABB = (brick.transform * mesh.bounds).abs()
		box = here if count == 0 else box.merge(here)
		count += 1
	var whole: String = str(held["root"])
	for segment_end: int in range(Assemblies.segments(path).size()):
		var at: String = "/".join(Assemblies.segments(path).slice(0, segment_end + 1))
		if Assemblies.leaf(at) == str(held["root"]):
			whole = at
			break
	var said: String = ("Put %s in the model as one sub-assembly, %s: %s, its low corner at x=%s "
		+ "y=%s z=%s, %s x %s studs and %s plates tall%s. Its parts are selected; undo takes it "
		+ "all out.") % [held["name"], whole, Builder._many(builder.selection.size()),
		_num(box.position.x / 20.0), _num(box.position.y / 8.0),
		_num(box.position.z / 20.0), _num(box.size.x / 20.0), _num(box.size.z / 20.0),
		_num(box.size.y / 8.0), ModelBar.held_words(held).replace(" — ", "; ")]
	if not credit.is_empty():
		said += " Its maker is credited in its sub-model's header: %s." % credit
	return said + " look_at_model to see it."


## Where a model brought in goes down for a session: its low corner on the
## ground at the studs [param input] gives, else beside the model, 2 studs clear of it on
## its right, stepped further out until it fits; the group aimed there from
## above, standing on whatever is under it (Carry.aim). Null where it
## cannot go.
func _into_spot(builder: Builder, input: Dictionary) -> Variant:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var held := AABB()
	var first: bool = true
	for item: Dictionary in builder.carrying.items:
		var mesh: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if mesh == null:
			continue
		var turned := Transform3D(Basis(Vector3.UP, builder.carrying.turns * PI * 0.5), Vector3.ZERO)
		var here: AABB = ((turned * (item["at"] as Transform3D)) * mesh.bounds).abs()
		held = here if first else held.merge(here)
		first = false
	var model := AABB()
	var any: bool = false
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if store.scenery.has(brick.id) or mesh == null:
			continue
		var here: AABB = (brick.transform * mesh.bounds).abs()
		model = here if not any else model.merge(here)
		any = true
	var given: bool = input.has("x") or input.has("z")
	var corner := Vector3(float(input.get("x", 0.0)) * 20.0, 0.0, float(input.get("z", 0.0)) * 20.0)
	if not given and any:
		corner = Vector3(model.end.x + 40.0, 0.0, model.position.z)
	var top: float = (model.end.y if any else 0.0) + 400.0
	for tries: int in (1 if given else 24):
		var at: Vector3 = corner + Vector3(40.0 * tries, 0.0, 0.0) - held.position
		builder.carrying.aim(builder.lattice, builder, Vector3(at.x, top, at.z), Vector3.DOWN)
		# A corner given is on the ground: over the model there is no room,
		# not the model put on top of it (imreview mcp_args).
		if builder.carrying.can_place() and (not given or builder.carrying.stands_on_ground(builder)):
			return at
	return null



static func _num(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


func _open_library(id: String, discard: bool) -> String:
	var store: ModelStore = app.get("_store")
	var bar: ModelBar = app.get("_bar")
	var books: ModelLibrary = app.get("_model_library")
	if books == null:
		return "This app has no library."
	# A set's number ("10179", "10179-1") or its name, as well as an id:
	# LDraw's model of that set, when the library has one (sets364).
	if not ModelLibrary.is_id(id):
		var said: String = id
		id = await _library_id_of(books, said)
		if id.is_empty():
			return ("LDraw's library has no 3D model of %s. Every set's parts list is on the site: "
				+ "%s/library/set/<number>; gallery library=true q= finds a set.") % [said, Deployment.api_base()]
	var unsaved: bool = store.has_unsaved_work()
	var was: String = store.title
	if unsaved and not discard:
		return _unsaved_refusal(store)
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
	if not str(result["error"]).is_empty():
		return "Could not open %s: %s. The model on the baseplate, %s, is as it was." % [
			title, result["error"], store.title]
	store.credit = ModelLibrary.credit_of(entry)
	store.touch()
	bar.opened.emit(placed)
	var since: int = Time.get_ticks_msec()
	while not store.awaited.is_empty() and Time.get_ticks_msec() - since < 120000:
		await app.get_tree().create_timer(0.3).timeout
	return ("Opened %s: %s%s, %s (%s). It is LDraw's model of the real set: credit %s and keep "
		+ "to its licence in anything made from it. Not saved: save_model keeps it in the person's "
		+ "models. look_at_model to see it.") % [title,
		await _parts_against_box(store, str(entry["set"]) if str(entry.get("alternate_of", "")).is_empty()
			else ""),
		ModelBar.left_out_words(result, false) + ModelBar.looks_words(store),
		ModelBar.credit_words(store.credit), entry["page"],
		str(entry["author"]) if not str(entry["author"]).is_empty() else "its maker"] \
		+ _replaced_words(store, unsaved, was) + _opened_motions()


# -- the parts list and the collection ------------------------------------------------


## submit_design mine=true (ownlimit, APP_UX8 #5): the model as it now
## stands against what the person owns (OwnCounts.said: every part theirs, or
## each one it goes over and by how many), said after the answer's first
## paragraph, where a session reads it before the passes it is told to go on
## with. A design that was not built is answered as it was: nothing went
## down to hold to anything. [param answer] is the call's text, or its blocks
## (a picture with it), whose first text is told.
func held_to_mine(answer: Variant) -> Variant:
	var text: String = answer if answer is String else ""
	var block: Dictionary = {}
	if answer is Array:
		for one: Variant in answer:
			if one is Dictionary and str((one as Dictionary).get("type", "")) == "text":
				block = one
				text = str(block.get("text", ""))
				break
	if not text.begins_with("Built"):
		return answer
	var shell: Shell = app.get("_shell")
	var mine: CollectionStore = shell.collection_store if shell != null else null
	var world: BrickWorld = app.get("_world")
	if mine == null or world == null:
		return answer
	if mine.on_hand.is_empty() and not mine.collection.is_empty():
		await mine.refresh_pool()
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var used: Dictionary = SetBin.used_in(world, store.scenery, library)
	var paragraphs: PackedStringArray = text.split("\n\n")
	paragraphs.insert(1, OwnCounts.said(mine.on_hand, used, library))
	if block.is_empty():
		return "\n\n".join(paragraphs)
	block["text"] = "\n\n".join(paragraphs)
	return answer


## submit_design pool= (mcpreach2, APP_UX9's past parity 1): a design held to
## one real set's parts, or several sets' together, checked as mine=true is
## (held_to_mine): the model as it now stands against the set's inventory as
## What can I build? counts it (OwnCounts.set_needs: no spares, nothing nobody
## owns alone), each part it uses more of than the set has and by how many,
## and what in the set could stand in, said after the answer's first
## paragraph. A set is named by its number as Rebrickable writes it
## ("31058-1"; "31058" is its first version, SetInventories.normal), never by
## its name: many sets share one ("Fire Station"), and a session that has only
## a name finds the number with gallery library=true q=. None of a set under
## test (DesignMemory.holds): its parts list is a bench session's answer.
func held_to_pool(answer: Variant, pool: String) -> Variant:
	var text: String = answer if answer is String else ""
	var block: Dictionary = {}
	if answer is Array:
		for one: Variant in answer:
			if one is Dictionary and str((one as Dictionary).get("type", "")) == "text":
				block = one
				text = str(block.get("text", ""))
				break
	if not text.begins_with("Built"):
		return answer
	var paragraphs: PackedStringArray = text.split("\n\n")
	paragraphs.insert(1, await _pool_said(pool))
	if block.is_empty():
		return "\n\n".join(paragraphs)
	block["text"] = "\n\n".join(paragraphs)
	return answer


## What a design held to [param pool] hears: every part in the sets named, or
## each it goes over.
func _pool_said(pool: String) -> String:
	var numbers := PackedStringArray()
	for raw: String in pool.replace(";", ",").replace(" ", ",").split(",", false):
		var normal: String = SetInventories.normal(raw)
		if not normal.is_empty() and not numbers.has(normal):
			numbers.append(normal)
	if numbers.is_empty():
		return "pool= names no set: give a set's number, \"31058-1\" (gallery library=true q= finds one)."
	var shell: Shell = app.get("_shell")
	var books: CollectionStore = shell.collection_store if shell != null else null
	var library: PartLibrary = app.get("_library")
	if books == null or books.inventories == null:
		return "pool=%s, but this app has no set inventories: nothing could be held to them." % pool
	var found: Dictionary = await books.inventories.lookup(numbers)
	var have: Dictionary = {}
	var named := PackedStringArray()
	var trouble := PackedStringArray()
	var pieces_had: int = 0
	for number: String in numbers:
		var record: Variant = found.get(number)
		if DesignMemory.holds(number, str((record as Dictionary).get("n", "")) if record is Dictionary else ""):
			trouble.append("set %s is under test in this run, so its parts are not given" % number)
			continue
		if not record is Dictionary:
			trouble.append(books.inventories.trouble if not books.inventories.trouble.is_empty()
				else "no set %s is in Rebrickable's inventories (gallery library=true q= finds a set's number)" % number)
			continue
		named.append("%s %s" % [number, str((record as Dictionary).get("n", ""))])
		var needs: Dictionary = OwnCounts.set_needs(record, library)
		for key: String in needs:
			have[key] = int(have.get(key, 0)) + int(needs[key])
			pieces_had += int(needs[key])
	if have.is_empty():
		return "pool=%s: %s, so nothing could be held to it." % [pool, "; ".join(trouble)]
	var sets: String = " and ".join(named)
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var used: Dictionary = SetBin.used_in(world, store.scenery, library)
	var pieces: int = 0
	for key: String in used:
		if library == null or Collection.ownable(Collection.part_of(key), library):
			pieces += int(used[key])
	var rows: Array = OwnCounts.over(have, used, library)
	var not_found: String = "" if trouble.is_empty() else " (%s)" % "; ".join(trouble)
	if rows.is_empty():
		return ("From %s's parts alone (pool): every one of its %s is in the set%s in its colour, "
			+ "%s of the %s %s.%s") % [sets, Counted.of(pieces, "piece"), "s" if named.size() > 1 else "",
			Counted.of(maxi(0, pieces_had - pieces), "piece left", "pieces left"),
			"sets'" if named.size() > 1 else "set's", Working.comma(pieces_had), not_found]
	var short: int = 0
	var lines := PackedStringArray()
	for row: Dictionary in rows:
		short += int(row["short"])
		if lines.size() < 40:
			lines.append("  " + _pool_row_said(row, library))
	if rows.size() > 40:
		lines.append("  and %d more parts." % (rows.size() - 40))
	return ("Over %s's parts (pool): %s it uses more of than the set%s %s, %s over in all%s:\n%s\n"
		+ "Change each to a part the set has with edit_model, or tell the person what else they would "
		+ "need; parts_list which=\"compare\" a=\"open\" b=\"%s\" sets the two side by side.") % [sets,
		Counted.of(rows.size(), "part"), "s" if named.size() > 1 else "", "have" if named.size() > 1 else "has",
		Counted.of(short, "piece"), not_found, "\n".join(lines), named[0].get_slice(" ", 0)]


## One part over a set's: "3001 Brick 2 x 4 in Red (4): 6 used, the set has 4,
## 2 over; it has it spare in Black (3)", as OwnCounts says a collection's.
static func _pool_row_said(row: Dictionary, library: PartLibrary) -> String:
	var stand_in := PackedStringArray()
	for swap: Dictionary in row.get("swaps", []):
		stand_in.append("%d spare in %s" % [int(swap["qty"]), OwnCounts._colour(int(swap["colour"]), library)])
	for combo: Dictionary in row.get("combos", []):
		var pieces := PackedStringArray()
		for piece: Array in combo["parts"]:
			pieces.append("%d x %s" % [int(piece[1]), OwnCounts._part(str(piece[0]), library)])
		stand_in.append("%s in its colour for %s" % [" and ".join(pieces),
			"one of them" if int(combo["qty"]) == 1 else "%d of them" % int(combo["qty"])])
	return "%s in %s: %d used, the set has %d, %d over%s" % [OwnCounts._part(str(row["part"]), library),
		OwnCounts._colour(int(row["colour"]), library), int(row["need"]), int(row["have"]), int(row["short"]),
		"; it has " + ", ".join(stand_in) if not stand_in.is_empty() else ""]


func _parts_list(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var which: String = str(input.get("which", "model"))
	if which == "compare":
		return await _parts_compare(input)
	var limit: int = clampi(int(input.get("limit", 60)), 1, 500)
	var stock: Inventory = Inventory.of(world, library, store.scenery)
	if which == "model":
		if stock.lots.is_empty():
			return "Nothing is built yet."
		var said := PackedStringArray()
		said.append("%s in %s, %s." % [Counted.of(stock.pieces, "piece"),
			Counted.of(stock.lots.size(), "lot"), stock.weight()])
		for lot: Inventory.Lot in stock.lots.slice(0, limit):
			said.append("  %3d x %s %s, %s%s" % [lot.count, lot.part_id, lot.name, lot.color_name,
				" (element %s)" % lot.element if not lot.element.is_empty() else ""])
		if stock.lots.size() > limit:
			said.append("  and %d more lots: limit= for more." % (stock.lots.size() - limit))
		return "\n".join(said)
	if not which in ["need", "buildable"]:
		return "which is model, need, buildable or compare."
	var shell: Shell = app.get("_shell")
	var mine: CollectionStore = shell.collection_store
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
		said.append("Short of %s." % Counted.of(short, "lot") if short > 0 else "They own every piece.")
		said.append(MINE_SAID)
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
	var most: int = mini(limit, 25) if not input.has("limit") else limit
	var said := PackedStringArray()
	if ranked.is_empty():
		said.append("No models to measure.")
	else:
		said.append("%d models against the collection, as My collection's What can I " % ranked.size()
			+ "build?'s Models ranks them, most of it owned first:")
		for one: Array in ranked.slice(0, most):
			var cover: Dictionary = one[2]
			said.append("  %d%% %s (%s): owns %d of its %d pieces in their colours, %d missing; %d%% in any colour"
				% [roundi(100.0 * float(cover["exact"])), one[0], one[1], int(cover["owned"]), int(cover["pieces"]),
				int(cover["missing"]), roundi(100.0 * float(cover["any_colour"]))])
		said.append("open_model name= opens a saved model or an example; an official model opens from My "
			+ "collection, What can I build? in the window. limit= lists more.")
	said.append("")
	said.append(await _buildable_sets(mine, most))
	return "\n".join(said)


## parts_list which="buildable"'s block of real sets (setsbuild): every set
## Rebrickable lists, ranked against the person's parts as What can I
## build?'s Real sets ranks them (SetRanking), in the same order, the sets
## they own left out; the first [param most].
func _buildable_sets(mine: CollectionStore, most: int) -> String:
	var ranking: SetRanking = await mine.inventories.ranking()
	if ranking == null:
		return "Real sets: every set's parts could not be read (%s)." % mine.inventories.trouble
	var ranked: SetRanking.Ranked = ranking.rank(mine.on_hand)
	var own: Dictionary = SetRanking.owned_sets(mine.collection)
	var listed: PackedInt32Array = ranked.listed(own, SetRanking.FEWEST)
	var now: int = ranked.at_least(listed, 1.0)
	var said := PackedStringArray([("Real sets: every one Rebrickable lists of %d pieces or more (%s), against "
		+ "the same parts, as What can I build?'s Real sets ranks them, the sets they own left out (the "
		+ "window's size choice lists smaller ones too). They could build %s now, and %s more have 90%% of "
		+ "their pieces or more:") % [SetRanking.FEWEST, Working.comma(listed.size()), Counted.of(now, "set"),
		Working.comma(ranked.at_least(listed, 0.9) - now)]])
	for n: int in listed.slice(0, most):
		said.append("  " + ranked.said(n))
	said.append("Each set's pieces count as What do I need? counts them: their sets' parts and loose parts, "
		+ "another moulding of a part standing in, no stickers. In the window, My collection, What can I "
		+ "build?, Real sets, a set's What do I need? lists what is short, to order; limit= lists more.")
	return "\n".join(said)


# -- comparesets: two sets' or models' parts (APP_UX6 #7) ---------------------------


## parts_list which="compare": a= against b=, as File, Compare, Compare two sets or
## models… shows them (PartsCompare), and with shop= the list to buy to build
## b from a written for that shop by the parts list's own writers.
func _parts_compare(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	var store: ModelStore = app.get("_store")
	var shell: Shell = app.get("_shell")
	if not input.has("a") or not input.has("b"):
		return ("compare takes a= and b=: each a set number (\"7140\"), a saved model's or "
			+ "an example's name, or \"open\" for the model open now.")
	var shop: String = str(input.get("shop", ""))
	if not shop in ["", "bricklink", "rebrickable", "pickabrick"]:
		return "shop is bricklink, rebrickable or pickabrick."
	var inventories: SetInventories = shell.collection_store.inventories \
		if shell != null and shell.collection_store != null else null
	var sides: Array = []
	for name: String in ["a", "b"]:
		var side: PartsCompare.Pile = await PartsCompare.side_for(str(input[name]), store, world,
			library, inventories)
		if not side.ok():
			return "%s: %s." % [name, side.trouble]
		sides.append(side)
	var compared: PartsCompare = PartsCompare.between(sides[0], sides[1])
	var said: String = compared.said(library, clampi(int(input.get("limit", 30)), 1, 2000))
	if shop.is_empty() or compared.only_b.is_empty():
		return said
	var exports: Exports = app.get("_exports")
	# BrickLink's condition, wanted list and email as the person chose them
	# last (ShopLists.Wants.kept), as the parts list's button writes them.
	var wrote: String = await exports.stock_list(shop, compared.to_buy(library),
		compared.file_name())
	return said + "\n" + wrote.left(1).to_upper() + wrote.substr(1) + "."


# -- mybricks: the person's own loose bricks (APP_UX5 #2) ---------------------------

## The most lots one call adds or takes off.
const MOST_LOTS := 500


## edit_collection: lots added, marked as this chat's, or taken off its own,
## all or nothing, as one change at the account (CollectionStore
## .change_lots, api/collection.js op "lots"), in turn with every other
## write; with neither, the collection read back afresh. A lot taken off
## carries the count this chat was last shown of it, and is refused when
## that is no longer so (mb2review finding 7).
func _edit_collection(input: Dictionary) -> String:
	var shell: Shell = app.get("_shell")
	var dialog: CollectionDialog = shell.collection if shell != null else null
	if dialog == null:
		return "This app has no collection."
	var mine: CollectionStore = dialog.store
	var library: PartLibrary = app.get("_library")
	var account: Account = app.get("_account")
	if account == null or not account.signed_in():
		return ("The person is not signed in, and a collection is kept with their account: "
			+ "they sign in (Account), then it can be read and added to.")
	# keptbuilt (APP_UX9 #6): sets kept built on a shelf, or taken apart. An
	# empty list asks nothing, as an empty add= does.
	var built: Variant = input.get("built")
	var marking_built: bool = built != null and not (built is Array and (built as Array).is_empty())
	if marking_built and input.get("missing") != null:
		return ("Nothing was changed: missing= marks a set's missing parts and built= the sets kept built, "
			+ "one thing a call: send them in separate calls.")
	# mcpreach3 (APP_UX10's r5): sets added by number, and built= on them.
	# A list, or one number as a string; false, null, "" or [] are as if not sent.
	var adding_sets: Variant = input.get("sets")
	if (adding_sets is Array and not (adding_sets as Array).is_empty()) \
			or (adding_sets is String and not (adding_sets as String).strip_edges().is_empty()):
		return await _collection_sets(dialog, mine, input)
	# partplaces (APP_UX9 #14): where each part and colour is kept.
	var placing: Variant = input.get("place")
	if placing != null and not (placing is Array and (placing as Array).is_empty()):
		return await _collection_places(mine, library, input)
	# localbricks (APP_UX6 #8): a set's missing lots marked and unmarked.
	if input.get("missing") != null:
		return await _collection_marks(mine, library, input)
	if marking_built:
		return await _collection_built(mine, input)
	var adding: Variant = input.get("add", [])
	var removing: Variant = input.get("remove", [])
	if not adding is Array or not removing is Array:
		return "add and remove are lists of {part, color, count}."
	if (adding as Array).is_empty() and (removing as Array).is_empty():
		var trouble_read: String = await mine.load_collection()
		return _collection_said(mine, library, clampi(int(input.get("limit", 60)), 1, 2000)) \
			+ ("" if trouble_read.is_empty() else "\n(" + trouble_read + ")")
	if (adding as Array).size() + (removing as Array).size() > MOST_LOTS:
		return "At most %d lots a call; send the rest in another." % MOST_LOTS
	var who: String = _collection_who()
	var mark: String = _collection_chat()
	var refused := PackedStringArray()
	var added: Dictionary = {}   ## part/colour -> lot, counts of one part and colour together
	var order: Array = []
	for n: int in (adding as Array).size():
		var lot: Variant = _collection_lot(adding[n], library, true)
		if lot is String:
			refused.append("add %d: %s" % [n + 1, lot])
			continue
		var key: String = "%s/%d" % [lot["part"], int(lot["colour"])]
		if added.has(key):
			added[key]["qty"] = mini(100000, int(added[key]["qty"]) + int(lot["qty"]))
		else:
			added[key] = {"part": lot["part"], "colour": lot["colour"], "qty": lot["qty"], "by": who}
			if not mark.is_empty():
				added[key]["chat"] = mark
			order.append(key)
	# Taken down by what was asked, at the account: several of one lot add
	# up, and a count of none takes all of it (mbreview finding 9).
	var down: Dictionary = {}
	var down_order: Array = []
	for n: int in (removing as Array).size():
		var lot: Variant = _collection_lot(removing[n], library, false)
		if lot is String:
			refused.append("remove %d: %s" % [n + 1, lot])
			continue
		var key: String = "%s/%d" % [lot["part"], int(lot["colour"])]
		if not down.has(key):
			down[key] = {"part": lot["part"], "colour": lot["colour"], "qty": 0, "by": who}
			if not mark.is_empty():
				down[key]["chat"] = mark
			down_order.append(key)
		if int(down[key]["qty"]) >= 0:
			down[key]["qty"] = -1 if int(lot["qty"]) == 0 else int(down[key]["qty"]) + int(lot["qty"])
	if not refused.is_empty():
		return ("Nothing was changed: " + _reasons(refused)
			+ ". search_parts finds a part's LDraw number; colours are LDraw codes.")
	var add_lots: Array = []
	for key: String in order:
		add_lots.append(added[key])
	# Each at the count this chat was last shown: the copy here is what its
	# last answer or read back said. One not there is read afresh once.
	for key: String in down_order:
		if mine.collection.lot_of(str(down[key]["part"]), int(down[key]["colour"]), who, mark).is_empty():
			await mine.load_collection()
			break
	var down_lots: Array = []
	var own := PackedStringArray()
	for key: String in down_order:
		var one: Dictionary = (down[key] as Dictionary).duplicate()
		one["qty"] = maxi(0, int(one["qty"]))
		var held: Dictionary = mine.collection.lot_of(str(one["part"]), int(one["colour"]), who, mark)
		if held.is_empty():
			own.append(("%s in colour %d is the person's own lot, which only they change (My collection)"
				if not mine.collection.lot_of(str(one["part"]), int(one["colour"])).is_empty()
				else "%s in colour %d is not a lot this chat added (the person may have kept it or taken it "
				+ "back)") % [one["part"], int(one["colour"])])
			continue
		one["was"] = int(held["qty"])
		down_lots.append(one)
	if not own.is_empty():
		return "Nothing was changed: %s. edit_collection with nothing reads back what is there." % _reasons(own)
	var done: Dictionary = await mine.change_lots(add_lots, down_lots)
	if done["kind"] != CollectionStore.DONE:
		return _not_made(done, "this chat was shown it")
	var said := PackedStringArray()
	if not add_lots.is_empty():
		var pieces: int = 0
		var lines := PackedStringArray()
		for lot: Dictionary in add_lots:
			pieces += int(lot["qty"])
			lines.append("  %d x %s" % [int(lot["qty"]), _lot_words(lot, library)])
		said.append("Added %s, %s, to the person's collection, each marked as this chat's:"
			% [Counted.of(add_lots.size(), "lot"), Counted.of(pieces, "piece")])
		said.append_array(lines)
		var held_back: String = CollectionStore.clamped_words(done["body"])
		if not held_back.is_empty():
			said.append(held_back[0].to_upper() + held_back.substr(1) + ".")
	if not down_lots.is_empty():
		said.append("Took down %s of this chat's." % Counted.of(down_lots.size(), "lot"))
	var theirs: Array = mine.collection.added_lots().filter(func(lot: Dictionary) -> bool:
		return _chats(lot, who, mark))
	said.append(("The person sees what this chat added under My collection, Added by %s (%s now), "
		+ "and keeps it or takes it back with one button. parts_list which=\"need\" measures the "
		+ "model against the collection now; edit_collection with nothing reads it back.")
		% [who, Counted.of(theirs.size(), "lot")])
	return "\n".join(said)


## The name this session's lots are marked with, as the account keeps it.
func _collection_who() -> String:
	var named: String = Collection.who_name(str(assistant.who) if assistant != null else "")
	return named if not named.is_empty() else CommandSocket.CLAUDE


## Which chat this session's lots are marked as: the relay's, or the
## session's own connection when it names none.
func _collection_chat() -> String:
	return chat if not chat.is_empty() else connection


## Whether [param lot] is one [param who]'s chat [param chat] added.
static func _chats(lot: Dictionary, who: String, chat: String) -> bool:
	return str(lot.get("by", "")) == who and str(lot.get("chat", "")) == chat


## One lot as a session gives it for add= or remove=, checked: {"part",
## "colour", "qty"}, or why not, in words ([method _lot_given]); the part one
## anybody owns on its own.
static func _collection_lot(given: Variant, library: PartLibrary, adding: bool) -> Variant:
	var lot: Variant = _lot_given(given, library, 1 if adding else 0, null if adding else 0)
	if lot is String:
		return lot
	if str(lot["part"]).is_empty():
		return _no_part(str(lot["asked"]))
	if not Collection.ownable(str(lot["part"]), library):
		return "%s is not a part anyone owns on its own (a sticker, or a piece of a bigger part)" % lot["part"]
	(lot as Dictionary).erase("asked")
	return lot


## One lot as a session gives it, checked at the edge: {"part", "asked",
## "colour", "qty"}, or why not, in words. Its colour and its count first,
## before anything is looked up (lbfix, lbreview F4): the colour an LDraw
## code (or a colour's name), the count a whole number from [param least]
## to 100,000, [param omitted] when none is given (null: one must be). Then
## the part, by its LDraw number or BrickLink's (PartLibrary.by_shop):
## "part" is "" when the library has none numbered so, "asked" what was
## named, which a set's marks match to the set's own rows before "part".
static func _lot_given(given: Variant, library: PartLibrary, least: int, omitted: Variant) -> Variant:
	if not given is Dictionary:
		return "a lot is {part, color, count}"
	var asked: String = str((given as Dictionary).get("part", "")).strip_edges().to_lower().trim_suffix(".dat")
	if asked.is_empty():
		return "no part"
	var colour: Variant = (given as Dictionary).get("color", (given as Dictionary).get("colour"))
	var code: int = -1
	if colour is int or (colour is float and float(colour) == floorf(float(colour)) and absf(float(colour)) < 1e9):
		code = int(colour)
	elif colour is String and (colour as String).strip_edges().is_valid_int():
		code = int((colour as String).strip_edges())
	elif colour is String:
		var named: Array[PartLibrary.BrickColor] = PartsBin.colours_named(library, colour)
		code = named[0].code if not named.is_empty() else -1
	if code in PartsBin.NOT_A_COLOUR or not library.colors.has(code):
		return "colour %s is not an LDraw colour code" % str(colour)
	var count: Variant = (given as Dictionary).get("count", (given as Dictionary).get("qty", omitted))
	if count == null or not (count is float or count is int) or float(count) != floorf(float(count)) \
			or float(count) < least or float(count) > 100000:
		return "count is a whole number from %d to 100,000" % least
	var id: String = library.resolve(asked)
	if not library.parts.has(id):
		id = library.by_shop(asked)
	if id.is_empty() or not library.parts.has(id):
		id = ""
	return {"part": id, "asked": asked, "colour": code, "qty": int(count)}


static func _no_part(asked: String) -> String:
	return "no part numbered %s (search_parts finds it by its words)" % asked


static func _lot_words(lot: Dictionary, library: PartLibrary) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(str(lot["part"]))
	var colour: PartLibrary.BrickColor = library.color(int(lot["colour"]))
	return "%s%s, %s (%d)" % [lot["part"], " " + Inventory._tidy(info.name) if info != null else "",
		colour.name.replace("_", " ") if colour != null else "colour", int(lot["colour"])]


## The collection read back: its sets, this chat's lots, the person's own.
func _collection_said(mine: CollectionStore, library: PartLibrary, limit: int) -> String:
	var held: Collection = mine.collection
	var who: String = _collection_who()
	var mark: String = _collection_chat()
	var ours: Array = held.added_lots().filter(func(lot: Dictionary) -> bool:
		return _chats(lot, who, mark))
	var others: Array = held.added_lots().filter(func(lot: Dictionary) -> bool:
		return not _chats(lot, who, mark))
	var own: Array = held.own_lots()
	var said := PackedStringArray()
	# Each set once, all its copies together (typed, fetched, a list), and
	# what it is marked as missing: one count a part (lbfix).
	var marks: Dictionary = held.marks(library)
	var kept: Dictionary = held.kept_built(mine.records)
	var copies: Dictionary = {}
	var numbers: Array = []
	for entry: Dictionary in held.sets:
		var number: String = str(entry["set"])
		if not copies.has(number):
			copies[number] = 0
			numbers.append(number)
		copies[number] = int(copies[number]) + maxi(1, int(entry.get("qty", 1)))
	var sets := PackedStringArray()
	for number: String in numbers:
		var record: Dictionary = mine.records.get(number, {})
		var gone: int = 0
		var its: Dictionary = (marks.get(number, {}) as Dictionary).get("missing", {})
		for key: String in its:
			gone += int(its[key])
		var built: int = int((kept.get(number, {}) as Dictionary).get("built", 0))
		sets.append("%s%s%s%s%s" % [number, " " + str(record["n"]) if record.has("n") else "",
			" x%d" % int(copies[number]) if int(copies[number]) > 1 else "", ", %d missing" % gone if gone > 0 else "",
			"" if built == 0 else ", kept built" if built == int(copies[number])
				else ", %d of %d kept built" % [built, int(copies[number])]])
	said.append("The person's collection%s: %s%s, %s of their own, %s this chat added%s; %s on hand in all%s."
		% [" (the copy on this device)" if mine.offline else "", Counted.of(numbers.size(), "set"),
			(" (" + ", ".join(sets.slice(0, 20)) + (", …" if sets.size() > 20 else "") + ")") if not sets.is_empty() else "",
			Counted.of(own.size(), "loose lot"), Counted.of(ours.size(), "lot"),
			", %s other chats added" % Counted.of(others.size(), "lot") if not others.is_empty() else "",
			Counted.of(mine.pieces_on_hand(), "piece"),
			"" if kept.is_empty() else ", the sets kept built left out (built= marks them)"])
	var listed: int = 0
	for group: Array in [[ours, "This chat added (remove= takes any of these off):"],
			[others, "Other chats added (theirs to take off):"],
			[own, "The person's own loose lots (only they change these):"]]:
		if (group[0] as Array).is_empty():
			continue
		said.append(str(group[1]))
		for lot: Dictionary in group[0]:
			if listed >= limit:
				break
			listed += 1
			var place: String = held.place_of(str(lot["part"]), int(lot["colour"]), library)
			said.append("  %d x %s%s" % [int(lot["qty"]), _lot_words(lot, library),
				", kept in " + place if not place.is_empty() else ""])
	var total: int = ours.size() + others.size() + own.size()
	# The marks, by set: what missing= changes, a count a part.
	var shown_marks: int = 0
	for number: String in numbers:
		if not marks.has(number):
			continue
		var its: Dictionary = marks[number]["missing"]
		total += its.size()
		for key: String in _sorted_keys(its):
			if listed >= limit:
				break
			if shown_marks == 0:
				said.append("Marked missing on their sets (missing= puts any to a count, all a set's copies together):")
			listed += 1
			shown_marks += 1
			said.append("  %s: %d x %s" % [number, int(its[key]), _lot_words({"part": Collection.part_of(key),
				"colour": Collection.colour_of(key)}, library)])
	if total > listed:
		said.append("  and %d more lots: limit= for more." % (total - listed))
	# partplaces: where things are kept, by place, their sets' parts too.
	if not held.places.is_empty():
		var by_place: Dictionary = {}
		for key: String in held.places:
			var at: String = str(held.places[key])
			if not by_place.has(at):
				by_place[at] = []
			(by_place[at] as Array).append(_lot_words({"part": Collection.part_of(key),
				"colour": Collection.colour_of(key)}, library))
		var named: Array = by_place.keys()
		named.sort_custom(func(a: String, b: String) -> bool: return Collection.place_less(a, b))
		said.append("Where they keep parts (place= sets them, \"\" takes one off): %s in %s:" % [
			Counted.of(held.places.size(), "part and colour", "parts and colours"), Counted.of(named.size(), "place")])
		for at: String in named.slice(0, 20):
			var those: Array = by_place[at]
			said.append("  %s: %s%s" % [at, "; ".join(PackedStringArray(those.slice(0, 6))), "; and %d more" % (those.size() - 6)
				if those.size() > 6 else ""])
		if named.size() > 20:
			said.append("  and %d more places." % (named.size() - 20))
	said.append(MINE_SAID)
	return "\n".join(said)


## What a session reading the person's collection is told of designing from
## it (ownlimit): guidance goes in a tool's result, where a session reads it.
const MINE_SAID := ("To design from their parts only, give submit_design mine=true: the app holds the "
	+ "design to what they own (these sets' parts less what is marked missing and the sets kept built, and the loose lots), "
	+ "and its answer names each part it uses more of than they own, by how many, with what of theirs "
	+ "could stand in.")


# -- localbricks: a set's missing parts, for a session (APP_UX6 #8) --------------------


## How a session names a set's lots, said after a refusal.
const NAME_LOTS := ("Name each part as the set's inventory lists it (search_parts finds a number); colours "
	+ "are LDraw codes; count is how many of it are missing, all the set's copies together.")


## edit_collection missing=: how many of each part a set the person owns is
## missing, at the account (api/collection.js op "missing"), made again
## after two reviews (lbfix, lbreview F1-F6):
##
##   One count per part per set: every entry of the set's number the person
##   owns together (typed, fetched from Rebrickable, a BrickLink list), each
##   mark by Collection.key_of, so a mark kept under an older number (179 for
##   6141) is the same mark (Collection.marks). Read and written through
##   that one count: a write is one op per entry, the count spread over the
##   entries as far as each holds the part (the marks already there kept
##   first), under the number the inventory has, the part's other numbers in
##   that entry put to 0 in the same op.
##
##   Changed only as named, and said: each lot named is put to the count
##   asked, and the reply lists each change "was N, now M", so the person or
##   their AI can put it back, and what of "now" another device or tab made
##   meanwhile. none=true says a set has nothing missing, and is refused
##   while anything is marked, naming it: the lots are named to unmark them,
##   or none=true sent again with marked= the number of lots it named, which
##   unmarks them all while that is still so (lbcheck L2). Every reply lists
##   at most SHOWN_LOTS lots, then counts the rest, as the read back does.
##
##   Validated at the edge: every colour and count checked before anything is
##   looked up (_lot_given). A number is matched to the set's own rows first,
##   then as the library resolves it (an old number, BrickLink's): the set's
##   inventory is the truth for a mark (lbcheck M1). Every refusal names the
##   number asked.
##
##   One thing per call: with add= or remove= it is refused.
func _collection_marks(mine: CollectionStore, library: PartLibrary, input: Dictionary) -> String:
	for other: String in ["add", "remove"]:
		var also: Variant = input.get(other)
		if also != null and not (also is Array and (also as Array).is_empty()):
			return ("Nothing was changed: missing= changes a set's marks and %s= loose lots, one thing a call: "
				+ "send them in separate calls.") % other
	var asked: Variant = input["missing"]
	if not asked is Dictionary:
		return "missing is {set, lots: [{part, color, count}]}, or {set, none: true}."
	var number: String = SetInventories.normal(str((asked as Dictionary).get("set", "")).strip_edges())
	if number.is_empty():
		return "missing.set is a set's number, like 7140-1."
	var none: Variant = (asked as Dictionary).get("none")
	var given: Variant = (asked as Dictionary).get("lots")
	var seen: Variant = (asked as Dictionary).get("marked")
	if none != null and not none is bool:
		return "missing.none is true or false."
	if none == true and given != null:
		return ("Nothing was changed: none=true says the set has nothing missing and takes no lots; send one or "
			+ "the other.")
	if seen != null and (none != true or not (seen is int or seen is float) or float(seen) != floorf(float(seen))
			or float(seen) < 0 or float(seen) > 100000):
		return ("Nothing was changed: missing.marked goes with none=true, the number of lots its refusal said were "
			+ "marked.")
	var named: Array = []
	if none != true:
		if not given is Array or (given as Array).is_empty():
			return "missing.lots is a list of {part, color, count}, or none=true says the set has nothing missing."
		if (given as Array).size() > MOST_LOTS:
			return "At most %d lots a call; send the rest in another." % MOST_LOTS
		var bad := PackedStringArray()
		for n: int in (given as Array).size():
			var lot: Variant = _lot_given(given[n], library, 0, null)
			if lot is String:
				var part: String = str((given[n] as Dictionary).get("part", "")).strip_edges() \
					if given[n] is Dictionary else ""
				bad.append("lot %d%s: %s" % [n + 1, " (%s)" % part if not part.is_empty() else "", lot])
			else:
				named.append(lot)
		if not bad.is_empty():
			return "Nothing was changed: %s. %s" % [_reasons(bad), NAME_LOTS]
	var trouble_read: String = await mine.load_collection()
	var entries: Array = mine.collection.entries_of(number)
	if entries.is_empty():
		return ("Nothing was changed: %s is not a set in the person's collection%s. edit_collection with nothing "
			+ "reads back their sets.") % [number, "" if trouble_read.is_empty() else " (" + trouble_read + ")"]
	var record: Dictionary = mine.records.get(number, {})
	if record.is_empty():
		record = (await mine.inventories.lookup(PackedStringArray([number]))).get(number, {})
	if record.is_empty():
		return "Nothing was changed: no inventory of %s is known here, so its parts cannot be marked." % number
	var title: String = ("%s %s" % [number, str(record.get("n", ""))]).strip_edges()
	# One copy's lots in the pool's spelling: key -> [part, colour, how many],
	# the part and colour as the inventory has them.
	var per_copy: Dictionary = {}
	for row: Variant in record.get("p", []):
		if not row is Array or (row as Array).size() < 3:
			continue
		var key: String = Collection.key_of(str(row[0]), int(row[1]), library)
		if per_copy.has(key):
			per_copy[key][2] = int(per_copy[key][2]) + int(row[2])
		else:
			per_copy[key] = [str(row[0]), int(row[1]), int(row[2])]
	var copies: int = 0
	for entry: Dictionary in entries:
		copies += maxi(1, int(entry.get("qty", 1)))
	# What is marked now, one count a part, and the number each is written
	# under: the inventory's, or for a part it no longer lists, as it is kept.
	var marked: Dictionary = (mine.collection.marks(library).get(number, {}) as Dictionary).get("missing", {})
	var spelled: Dictionary = {}
	for key: String in per_copy:
		spelled[key] = [per_copy[key][0], per_copy[key][1]]
	for entry: Dictionary in entries:
		for lot: Dictionary in Collection.missing_lots(entry):
			var key: String = Collection.key_of(str(lot["part"]), int(lot["colour"]), library)
			if not spelled.has(key):
				spelled[key] = [str(lot["part"]), int(lot["colour"])]
	var wanted: Dictionary = {}
	var order: Array = []
	var bad := PackedStringArray()
	if none == true:
		if marked.is_empty():
			return "Nothing to change: %s has nothing marked missing." % title
		# Made whole in one call once what is marked was shown: the count of
		# lots it was refused with sent back (lbcheck L2). Refused otherwise,
		# naming what is marked now, bounded as the read back is.
		if seen == null or int(seen) != marked.size():
			var pieces: int = 0
			for key: String in marked:
				pieces += int(marked[key])
			var said := PackedStringArray()
			said.append("Nothing was changed: %s has %s marked missing%s, %s:" % [title, Counted.of(marked.size(), "lot"),
				"" if seen == null else " now, not the %d sent" % int(seen), Counted.of(pieces, "piece")])
			var lots: Array = []
			for key: String in _sorted_keys(marked):
				lots.append(["  %s: %d" % [_marked_words(key, spelled, library), int(marked[key])], int(marked[key])])
			said.append_array(_bounded(lots))
			said.append(("none=true says a set has nothing missing once what is marked was shown: send none=true "
				+ "with marked=%d to unmark all %s in one call, or name the lots to unmark, each with count 0. The "
				+ "reply says what was marked.") % [marked.size(), Counted.of(marked.size(), "lot")])
			return "\n".join(said)
		for key: String in _sorted_keys(marked):
			wanted[key] = 0
			order.append(key)
	else:
		# Each lot named, matched to the set by its key, at a count its copies hold.
		for n: int in named.size():
			var lot: Dictionary = named[n]
			var asked_for: String = str(lot["asked"])
			var key: String = _set_key(lot, spelled, library)
			if key.is_empty():
				bad.append("lot %d: %s" % [n + 1, _no_part(asked_for) if str(lot["part"]).is_empty()
					else "%s%s in colour %d is not in %s's inventory" % [asked_for, " (LDraw's %s)" % lot["part"]
					if str(lot["part"]) != asked_for else "", int(lot["colour"]), number]])
				continue
			var as_asked: String = asked_for if str(spelled[key][0]) == asked_for \
				else "%s (its inventory's %s)" % [asked_for, spelled[key][0]]
			var most: int = int(per_copy[key][2]) * copies if per_copy.has(key) else int(marked.get(key, 0))
			if int(lot["qty"]) > most:
				bad.append("lot %d: %s has %d of %s in colour %d%s, so from 0 to %d of it can be missing" % [n + 1,
					number, most, as_asked, int(lot["colour"]),
					" in its %d copies" % copies if copies > 1 and per_copy.has(key) else "", most])
				continue
			if wanted.has(key):
				bad.append("lot %d: %s in colour %d is named twice" % [n + 1, as_asked, int(lot["colour"])])
				continue
			wanted[key] = int(lot["qty"])
			order.append(key)
	if not bad.is_empty():
		return "Nothing was changed: %s. %s" % [_reasons(bad), NAME_LOTS]
	# Each entry's lots to write, by key: [key, lots, how many more or fewer
	# it marks there].
	var writes: Array = []
	for _entry: Dictionary in entries:
		writes.append([])
	var before: Dictionary = {}
	for key: String in order:
		var held: Array = []
		var room: Array = []
		var total: int = 0
		for entry: Dictionary in entries:
			var now: int = int(Collection.missing_keys(entry, library).get(key, 0))
			held.append(now)
			total += now
			room.append(int(per_copy[key][2]) * maxi(1, int(entry.get("qty", 1))) if per_copy.has(key) else now)
		before[key] = total
		if total == int(wanted[key]):
			continue
		var after: Array = held.duplicate()
		if int(wanted[key]) > total:
			var more: int = int(wanted[key]) - total
			for e: int in entries.size():
				var put: int = mini(more, maxi(0, int(room[e]) - int(after[e])))
				after[e] = int(after[e]) + put
				more -= put
		else:
			var less: int = total - int(wanted[key])
			for e: int in range(entries.size() - 1, -1, -1):
				var take: int = mini(less, int(after[e]))
				after[e] = int(after[e]) - take
				less -= take
		for e: int in entries.size():
			if int(after[e]) != int(held[e]):
				(writes[e] as Array).append([key, _mark_writes(entries[e], key, int(after[e]), spelled[key], library),
					int(after[e]) - int(held[e])])
	# One op an entry, or several for more lots than an op takes, each
	# whole keys.
	var ops: Array = []
	for e: int in entries.size():
		var lots: Array = []
		var moved: Dictionary = {}
		for group: Array in writes[e]:
			if not lots.is_empty() and lots.size() + (group[1] as Array).size() > MOST_MARK_CHANGES:
				ops.append([e, lots, moved])
				lots = []
				moved = {}
			lots.append_array(group[1])
			moved[group[0]] = group[2]
		if not lots.is_empty():
			ops.append([e, lots, moved])
	if ops.is_empty():
		var lines: Array = []
		for key: String in order:
			lines.append(["  %s: %d" % [_marked_words(key, spelled, library), int(before[key])], int(before[key])])
		return "Nothing to change: %s is marked so already:\n%s" % [title, "\n".join(_bounded(lines))]
	var stopped: Dictionary = {}
	var stopped_on: Dictionary = {}
	var made: int = 0
	## key -> how many more (or fewer) this call's ops that were made marked.
	var ours: Dictionary = {}
	for op: Array in ops:
		var body: Dictionary = {"op": "missing", "set": number, "lots": op[1]}
		var src: String = str((entries[op[0]] as Dictionary).get("src", ""))
		if not src.is_empty():
			body["src"] = src
		var done: Dictionary = await mine.change(body)
		if done["kind"] != CollectionStore.DONE:
			stopped = done
			stopped_on = entries[op[0]]
			break
		made += 1
		for key: String in op[2]:
			ours[key] = int(ours.get(key, 0)) + int(op[2][key])
	if made == 0:
		return _not_made(stopped, "it was read", true)
	# Said from the collection as the account now has it: what each lot was,
	# and what it is; and what of that came from somewhere else meanwhile
	# (another device, a tab, the person's own page), apart from this call's.
	var now_marked: Dictionary = (mine.collection.marks(library).get(number, {}) as Dictionary).get("missing", {})
	var changed: Array = []
	var already: Array = []
	for key: String in order:
		var was: int = int(before[key])
		var now: int = int(now_marked.get(key, 0))
		var theirs: int = now - was - int(ours.get(key, 0))
		if was != now:
			changed.append(["  %s: was %d, now %d%s" % [_marked_words(key, spelled, library), was, now,
				"" if theirs == 0 else " (%d of it marked meanwhile by another device or tab, not this call)" % theirs
				if theirs > 0 else " (%d of it unmarked meanwhile by another device or tab, not this call)" % -theirs],
				now, was])
		elif now == int(wanted[key]):
			already.append(["  %s: %d" % [_marked_words(key, spelled, library), now], now])
	var said := PackedStringArray()
	said.append("%s what %s is marked missing (%s):" % ["Changed" if stopped.is_empty()
		else "Changed only part of", title, "its %d copies together" % copies if copies > 1 else "its one copy"])
	said.append_array(_bounded(changed))
	if not already.is_empty():
		said.append("Already so:")
		said.append_array(_bounded(already))
	if not stopped.is_empty():
		said.append("The rest was not changed: %s. edit_collection with nothing reads back what is there; send the rest again from it."
			% _stopped_words(stopped, stopped_on, entries.size() > 1))
	var whole: Dictionary = mine.collection.wholeness(_as_one_entry(number, copies, now_marked), record, library)
	said.append(("%d of its %d pieces are marked missing now%s%s. To put any back, send its count as it was. What do "
		+ "I need? for it (My collection, Closest to whole) lists what to find; the pool, What do I need?, What can I "
		+ "build? and a bin built from it count only what is there.") % [int(whole["marked"]), int(whole["pieces"]),
		"" if int(whole["loose"]) == 0 else ", %d of them made up by their loose parts" % int(whole["loose"]),
		"" if int(whole["marked"]) > 0 else ": it is whole"])
	return "\n".join(said)


## edit_collection built=: sets the person keeps built on a shelf, or takes
## apart (keptbuilt, APP_UX9 #6). Each a set number (every copy of it kept
## built) or {set, copies} (that many; 0 takes it apart), every copy of the
## number together, as its Built mark in My collection counts them: all in
## one change at the account (CollectionStore.set_built, op "built"), from
## the counts read afresh, all or nothing. Each said "was N, now M", to put
## back, and the pieces left to build with. A set is never added here: one
## not in the collection is refused, named.
func _collection_built(mine: CollectionStore, input: Dictionary) -> String:
	for other: String in ["add", "remove"]:
		var also: Variant = input.get(other)
		if also != null and not (also is Array and (also as Array).is_empty()):
			return ("Nothing was changed: built= marks sets and %s= changes loose lots, one thing a call: "
				+ "send them in separate calls.") % other
	var asked: Variant = input["built"]
	if not asked is Array or (asked as Array).is_empty():
		return "built is a list of set numbers, like [\"7140-1\"], or of {set, copies}."
	if (asked as Array).size() > MOST_LOTS:
		return "At most %d sets a call; send the rest in another." % MOST_LOTS
	var trouble_read: String = await mine.load_collection()
	var checked: Dictionary = _built_asked(mine.collection, asked)
	if not (checked["bad"] as PackedStringArray).is_empty():
		return "Nothing was changed: %s.%s" % [_reasons(checked["bad"]),
			"" if trouble_read.is_empty() else " (" + trouble_read + ")"]
	var done: Dictionary = await mine.set_built(_built_sent(checked["changes"]))
	if done["kind"] != CollectionStore.DONE:
		return _not_made(done, "it was read")
	return _built_said(mine, checked["changes"])


## built= read against [param held], changing nothing: {"changes": each
## {set, was, built, copies}, "bad": what is wrong with any, by its place}.
## [param adding] are sets the same call adds first, a copy each (sets=):
## counted with the copies held, and not refused as not the person's. A
## number as sets= reads it (_set_text: an en dash, a zero-width mark).
static func _built_asked(held: Collection, asked: Array,
		adding: PackedStringArray = PackedStringArray()) -> Dictionary:
	var changes: Array = []
	var bad := PackedStringArray()
	var seen: Dictionary = {}
	for n: int in asked.size():
		var one: Variant = asked[n]
		var raw: String = str(one) if one is String else str((one as Dictionary).get("set", "")) \
			if one is Dictionary else ""
		var number: String = SetInventories.normal(_set_text(raw))
		if number.is_empty():
			bad.append("built %d: a set's number, like 7140-1, or {set, copies}" % (n + 1))
			continue
		if seen.has(number):
			bad.append("built %d: %s is named twice" % [n + 1, number])
			continue
		seen[number] = true
		var copies: int = held.copies_of(number) + (1 if adding.has(number) else 0)
		if copies == 0:
			bad.append("built %d: %s is not a set in the person's collection%s (they add it in My collection)"
				% [n + 1, number, "" if adding.is_empty() else ", nor among sets="])
			continue
		var wanted: int = copies
		if one is Dictionary:
			var given: Variant = (one as Dictionary).get("copies")
			if not (given is int or given is float) or float(given) != floorf(float(given)) \
					or int(given) < 0 or int(given) > copies:
				bad.append("built %d: copies is a whole number from 0 to %d, the copies of %s they %s"
					% [n + 1, copies, number, "would own once sets= adds one" if adding.has(number) else "own"])
				continue
			wanted = int(given)
		var was: int = 0
		for entry: Dictionary in held.entries_of(number):
			was += Collection.built_of(entry)
		changes.append({"set": number, "was": was, "built": wanted, "copies": copies})
	return {"changes": changes, "bad": bad}


## [method _built_asked]'s changes as CollectionStore.set_built sends them.
static func _built_sent(changes: Array) -> Array:
	return changes.map(func(one: Dictionary) -> Dictionary:
		return {"set": one["set"], "was": one["was"], "built": one["built"]})


## built= made at the account: each set's mark, was and now, and the pieces
## left to build with.
func _built_said(mine: CollectionStore, changes: Array) -> String:
	var lines := PackedStringArray()
	for one: Dictionary in changes:
		var record: Dictionary = mine.records.get(str(one["set"]), {})
		lines.append("  %s%s: kept built %d of %d (was %d)%s" % [one["set"],
			" " + str(record["n"]) if record.has("n") else "", int(one["built"]), int(one["copies"]), int(one["was"]),
			", taken apart" if int(one["built"]) == 0 and int(one["was"]) > 0 else ""])
	return ("Marked at the person's account, as the Built mark in My collection shows it:\n%s\n"
		+ "A copy kept built stands on their shelf: its parts are left out of What can I build?, My bricks, "
		+ "parts_list need and submit_design mine=true, its spares apart; %s are now theirs to build with. "
		+ "To put any back, send built=[{set, copies: the was}].") % ["\n".join(lines),
			Counted.of(mine.pieces_on_hand(), "piece")]


## edit_collection sets=: each set added, a copy, by the window's own Add a
## set (CollectionDialog.add_sets), and then built= on them when it is given,
## in one call. r5's session was asked to add 31058-1, kept built, and told
## the person it could not: sets came in only by My collection, and built=
## refused a set not yet theirs (APP_UX10's walk; mcpreach3). Said: each
## set's copies, was and now, as built= says its marks, and the loose parts
## and the pieces on hand after it.
##
## Every argument, built= too, is checked before the add: a built= refused
## after it answered "Nothing was changed", the session sent the call again,
## and the set was added twice (m3review H2). A reply lost after the add is
## told it may have been made, to read before sending again (_not_made).
func _collection_sets(dialog: CollectionDialog, mine: CollectionStore, input: Dictionary) -> String:
	for other: String in ["add", "remove", "missing", "place"]:
		var also: Variant = input.get(other)
		if also != null and not (also is Array and (also as Array).is_empty()):
			return ("Nothing was changed: sets= adds sets and %s= is another change, one thing a call "
				+ "(built= may come with sets=): send them in separate calls.") % other
	var asked: Variant = input["sets"]
	if asked is String:
		asked = [asked]
	if (asked as Array).size() > MOST_SETS_ADDED:
		return "At most %d sets a call; send the rest in another." % MOST_SETS_ADDED
	# built= with them: a list, or one number as a string; false, null, ""
	# and [] are as if not sent.
	var built: Variant = input.get("built")
	var marking: Array = []
	if built is Array:
		marking = built
	elif built is String:
		marking = [] if (built as String).strip_edges().is_empty() else [built]
	elif built != null and not (built is bool and not bool(built)):
		return "Nothing was changed: built is a list of set numbers, like [\"31058-1\"], or of {set, copies}."
	if marking.size() > MOST_LOTS:
		return "Nothing was changed: at most %d sets in built= a call; send the rest in another." % MOST_LOTS
	# A set's number as Rebrickable writes them: letters and digits, one at
	# least a digit, and its version ("31058-1").
	var shape: RegEx = RegEx.create_from_string("^(?=[a-z0-9]*[0-9])[a-z0-9]+-[0-9]+$")
	var numbers := PackedStringArray()
	var bad := PackedStringArray()
	for n: int in (asked as Array).size():
		var number: String = SetInventories.normal(_set_text(asked[n]))
		if number.is_empty() or shape.search(number) == null:
			bad.append("sets %d: a set's number, like 31058-1" % (n + 1))
		elif numbers.has(number):
			bad.append("sets %d: %s is named twice" % [n + 1, number])
		else:
			numbers.append(number)
	if not bad.is_empty():
		return "Nothing was changed: %s." % _reasons(bad)
	var trouble_read: String = await mine.load_collection()
	if not marking.is_empty():
		bad = _built_asked(mine.collection, marking, numbers)["bad"]
		if not bad.is_empty():
			return "Nothing was changed: %s.%s" % [_reasons(bad),
				"" if trouble_read.is_empty() else " (" + trouble_read + ")"]
	var before: Dictionary = {}
	for number: String in numbers:
		before[number] = mine.collection.copies_of(number)
	var done: Dictionary = await dialog.add_sets(" ".join(numbers))
	if done["kind"] != CollectionStore.DONE:
		return _not_made(done, "it was read")
	var unknown: PackedStringArray = mine.collection.unknown_sets
	var lines := PackedStringArray()
	for number: String in numbers:
		var record: Dictionary = mine.records.get(number, {})
		lines.append("  %s%s: %s now (was %d)%s" % [number,
			" " + str(record["n"]) if record.has("n") else "",
			Counted.of(mine.collection.copies_of(number), "copy", "copies"), int(before[number]),
			", no inventory is known for it, so it adds no parts" if unknown.has(number) else ""])
	var said: String = ("Added to the person's collection, as Add a set in My collection adds it:\n%s"
		% "\n".join(lines))
	if not marking.is_empty():
		said += "\n" + await _built_after_add(mine, marking)
	else:
		said += ("\nEvery part of it is theirs to build with until it is marked kept built on a shelf "
			+ "(built=, or its Built mark in My collection).")
	return said + ("\nTheir loose parts, in no set: %s in %s. Pieces on hand to build with, sets kept "
		+ "built left out but their spares counted: %s. The person takes a set out in My collection "
		+ "(its row's Remove).") % [Counted.of(mine.collection.loose_pieces(), "loose part"),
			Counted.of(mine.collection.parts.size(), "lot"), Counted.of(mine.pieces_on_hand(), "piece")]


## sets='s built=, once the sets are added: marked as built= alone marks
## them, from the counts the add left. The sets are in by then, so what
## stops the marks is said as theirs alone, never "Nothing was changed", and
## sending sets= again would add another copy.
func _built_after_add(mine: CollectionStore, marking: Array) -> String:
	const AGAIN := ("Never send sets= again for them: the sets are added, and sets= would add another "
		+ "copy each.")
	var checked: Dictionary = _built_asked(mine.collection, marking)
	if not (checked["bad"] as PackedStringArray).is_empty():
		return "Their Built marks were not made: %s. Send built= alone to mark them. %s" % [
			_reasons(checked["bad"]), AGAIN]
	var done: Dictionary = await mine.set_built(_built_sent(checked["changes"]))
	if done["kind"] == CollectionStore.UNREACHED:
		return ("Their Built marks: no answer came, so they may have been made (%s). edit_collection with "
			+ "nothing reads back what is there: read it before sending built= again. %s") % [done["said"], AGAIN]
	if done["kind"] != CollectionStore.DONE:
		return "Their Built marks were not made: %s. Send built= alone to mark them. %s" % [
			"Brickworks could not be reached" if done.get("offline", false) else _account_said(done, false), AGAIN]
	return _built_said(mine, checked["changes"])


## The most sets one sets= adds.
const MOST_SETS_ADDED := 20


## A set's number as sent, made plain: Unicode's spaces and the marks that
## take no room gone (Collection.place_text), and a dash of any kind (an en
## dash, a minus) the hyphen Rebrickable writes. "" for what is not text.
static func _set_text(raw: Variant) -> String:
	if not raw is String:
		return ""
	var text: String = Collection.place_text(raw as String).replace(" ", "")
	for dash: int in [0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2212, 0xFE63, 0xFF0D]:
		text = text.replace(String.chr(dash), "-")
	return text


## The most lots one "missing" op changes (api/collection.js MOST_LOT_CHANGES).
const MOST_MARK_CHANGES := 2000


## A refusal's reasons, "; " between them: the first [constant
## MOST_REASONS] named and the rest counted, so 300 parts not held come
## back in a few lines, not 24,000 characters (ppreview F8).
static func _reasons(reasons: Variant) -> String:
	var all := PackedStringArray(reasons)
	if all.size() <= MOST_REASONS:
		return "; ".join(all)
	return "%s; and %d more" % ["; ".join(
		all.slice(0, MOST_REASONS)), all.size() - MOST_REASONS]


## How many reasons a refusal names before it counts the rest.
const MOST_REASONS := 10


## The first SHOWN_LOTS of [param lines] (each [line, ...]), then how many
## more, as edit_collection with nothing lists them all.
static func _said_first(lines: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for one: Array in lines.slice(0, SHOWN_LOTS):
		out.append(str(one[0]))
	if lines.size() > SHOWN_LOTS:
		out.append("  and %d more: edit_collection with nothing, limit=, lists where each is kept" % (lines.size()
			- SHOWN_LOTS))
	return out


## edit_collection place=: where the person keeps each part and colour
## (partplaces, APP_UX9 #14), each {part, color, place} ("" takes it off),
## all in one change at the account (CollectionStore.set_places, op
## "place"), from the places read afresh, all or nothing. A part is named
## by its LDraw number or BrickLink's, a colour by its code or its name,
## and only one the collection holds is placed: a loose lot of it, or in a
## set of theirs. Each said "was, now", to put back.
func _collection_places(mine: CollectionStore, library: PartLibrary, input: Dictionary) -> String:
	for other: String in ["add", "remove", "built"]:
		var also: Variant = input.get(other)
		if also != null and not (also is Array and (also as Array).is_empty()):
			return ("Nothing was changed: place= says where parts are kept and %s= changes the collection, one "
				+ "thing a call: send them in separate calls.") % other
	if input.get("missing") != null:
		return ("Nothing was changed: place= says where parts are kept and missing= marks a set's missing parts, "
			+ "one thing a call: send them in separate calls.")
	var asked: Variant = input["place"]
	if not asked is Array:
		return "place is a list of {part, color, place}."
	if (asked as Array).size() > MOST_LOTS:
		return "At most %d places a call; send the rest in another." % MOST_LOTS
	var trouble_read: String = await mine.load_collection()
	var held: Collection = mine.collection
	var holds: Dictionary = held.held_keys(mine.records, library)
	var changes: Array = []
	var bad := PackedStringArray()
	var seen: Dictionary = {}
	for n: int in (asked as Array).size():
		var one: Variant = asked[n]
		if not one is Dictionary:
			bad.append("place %d: a place is {part, color, place}" % (n + 1))
			continue
		var lot: Variant = _lot_given(one, library, 0, 1)
		if lot is String:
			bad.append("place %d: %s" % [n + 1, lot])
			continue
		if str(lot["part"]).is_empty():
			bad.append("place %d: %s" % [n + 1, _no_part(str(lot["asked"]))])
			continue
		var raw: Variant = (one as Dictionary).get("place")
		if not raw is String:
			bad.append("place %d: place is words, like \"drawer 3\" (\"\" takes it off)" % (n + 1))
			continue
		var place: String = Collection.place_text(raw)
		if place.length() > Collection.MOST_PLACE:
			bad.append("place %d: a place is at most %d characters, and that is %d" % [n + 1, Collection.MOST_PLACE,
				place.length()])
			continue
		var key: String = Collection.key_of(str(lot["part"]), int(lot["colour"]), library)
		if seen.has(key):
			bad.append("place %d: %s is named twice" % [n + 1, _lot_words(lot, library)])
			continue
		seen[key] = true
		var was: String = str(held.places.get(key, ""))
		if not place.is_empty() and place != was and not holds.has(key):
			bad.append("place %d: %s is not in the person's collection: neither a loose lot of theirs nor in a set "
				% [n + 1, _lot_words(lot, library)] + "of theirs (they add it in My collection)")
			continue
		changes.append({"part": Collection.part_of(key), "colour": Collection.colour_of(key), "was": was,
			"place": place})
	if not bad.is_empty():
		return "Nothing was changed: %s.%s" % [_reasons(bad),
			"" if trouble_read.is_empty() else " (" + trouble_read + ")"]
	if changes.is_empty():
		return "place is a list of {part, color, place}: name at least one."
	var sent: Array = changes.filter(func(one: Dictionary) -> bool: return str(one["was"]) != str(one["place"]))
	if not sent.is_empty():
		var done: Dictionary = await mine.set_places(sent)
		if done["kind"] != CollectionStore.DONE:
			return _not_made(done, "this chat read it", true)
	var lines: Array = []
	for one: Dictionary in changes:
		lines.append(["  %s: %s (was %s)" % [_lot_words(one, library),
			"in " + str(one["place"]) if not str(one["place"]).is_empty() else "kept nowhere",
			"\"" + str(one["was"]) + "\"" if not str(one["was"]).is_empty() else "nowhere"], 0])
	return ("Kept at the person's account, as My collection's Where it's kept shows it:\n%s\n"
		+ "The parts list sorts by where each is kept, and the booklet's parts boxes say \"from\" the place under "
		+ "each part. To put any back, send place=[{part, color, place: the was}] (\"\" for nowhere).") \
		% "\n".join(_said_first(lines))


## How many lots a reply lists before it counts the rest, as the read back does.
const SHOWN_LOTS := 60


## A reply's lots, each [line, how many marked now, and before when it
## changed]: the first SHOWN_LOTS of them, then how many more and their
## pieces, as the read back counts what it does not list (lbcheck L2).
static func _bounded(lots: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var pieces: int = 0
	var was: int = 0
	for n: int in lots.size():
		if n < SHOWN_LOTS:
			out.append(str(lots[n][0]))
			continue
		pieces += int(lots[n][1])
		was += int(lots[n][2]) if (lots[n] as Array).size() > 2 else int(lots[n][1])
	if lots.size() > SHOWN_LOTS:
		out.append("  and %d more %s, %s%s: edit_collection with nothing, limit=, lists what is marked" % [
			lots.size() - SHOWN_LOTS, "lot" if lots.size() - SHOWN_LOTS == 1 else "lots", Counted.of(pieces, "piece"),
			"" if was == pieces else " now, %d before" % was])
	return out


## What the account said when it did not make an op, in a session's words:
## its own error, without the op's lot number, which is not the session's.
static func _account_said(done: Dictionary, strip_lot: bool) -> String:
	var error: String = str((done.get("body", {}) as Dictionary).get("error", done["said"])) \
		if done.get("body") is Dictionary else str(done["said"])
	return RegEx.create_from_string("^lot \\d+: ").sub(error, "") if strip_lot else error


## A change the account did not make, said to a session (the lots and the
## marks alike): nothing was changed, or it may have been, and why; the
## collection changed since [param since].
static func _not_made(done: Dictionary, since: String, strip_lot: bool = false) -> String:
	if done["kind"] == CollectionStore.UNREACHED:
		return ("No answer came, so it may have been made (%s). edit_collection with nothing reads back what is "
			+ "there: read it before sending this again.") % done["said"]
	if done["kind"] == CollectionStore.CONFLICT:
		return ("Nothing was changed: %s. The collection changed since %s; edit_collection with nothing reads back "
			+ "what is there now.") % [_account_said(done, strip_lot), since]
	if done.get("offline", false):
		return OFFLINE
	return "Nothing was changed: %s." % done["said"]


## Said once, with what to do (lbcheck L4: the store's screen words said it twice).
const OFFLINE := ("Nothing was changed: Brickworks could not be reached. Send it again once it answers; "
	+ "edit_collection with nothing reads back the copy on this device.")


## Why the op on [param entry] was not made, after others were: on which
## copy, when the set has [param several], and in the account's words.
static func _stopped_words(done: Dictionary, entry: Dictionary, several: bool) -> String:
	var copy: String = ""
	if several:
		copy = "on its copy %s, " % {"hand": "typed in", "rebrickable": "from Rebrickable",
			"bricklink_xml": "from a BrickLink list"}.get(str(entry.get("src", "")), "brought in before")
	if done["kind"] == CollectionStore.CONFLICT:
		return "%s%s: another device or tab changed it since it was read" % [copy, _account_said(done, true)]
	if done["kind"] == CollectionStore.UNREACHED:
		return "%sno answer came, so it may have been made (%s)" % [copy, done["said"]]
	if done.get("offline", false):
		return "%sBrickworks could not be reached" % copy
	return copy + str(done["said"])


## Which of a set's lots ([param rows]: key -> anything) a lot named for
## its marks ([method _lot_given]) is, or "" for none. The set's own row
## first: a number its inventory lists is that row, whatever else the
## library makes of the number (lbcheck M1: 3048c is BrickLink's keyword for
## 3048b, 2909c03 its 74741-f1); then the part the number resolves to, an
## old number or BrickLink's.
static func _set_key(lot: Dictionary, rows: Dictionary, library: PartLibrary) -> String:
	var key: String = Collection.key_of(str(lot["asked"]), int(lot["colour"]), library)
	if rows.has(key):
		return key
	if str(lot["part"]).is_empty():
		return ""
	key = Collection.key_of(str(lot["part"]), int(lot["colour"]), library)
	return key if rows.has(key) else ""


## The lots to write in [param entry] so it is marked [param count] of
## [param key]: under [param spelling] (the inventory's number and colour),
## the part's other numbers there put to 0, each from the count kept now.
static func _mark_writes(entry: Dictionary, key: String, count: int, spelling: Array, library: PartLibrary) -> Array:
	var out: Array = []
	for lot: Dictionary in Collection.missing_lots(entry):
		if Collection.key_of(str(lot["part"]), int(lot["colour"]), library) != key:
			continue
		if str(lot["part"]) == str(spelling[0]) and int(lot["colour"]) == int(spelling[1]):
			continue
		out.append({"part": str(lot["part"]), "colour": int(lot["colour"]), "was": int(lot["qty"]), "qty": 0})
	var was: int = Collection.missing_count(entry, str(spelling[0]), int(spelling[1]))
	if was != count:
		out.append({"part": str(spelling[0]), "colour": int(spelling[1]), "was": was, "qty": count})
	return out


## A set's marks as one entry of all its copies, for Collection.wholeness.
static func _as_one_entry(number: String, copies: int, marked: Dictionary) -> Dictionary:
	var lots: Array = []
	for key: String in marked:
		lots.append({"part": Collection.part_of(key), "colour": Collection.colour_of(key), "qty": int(marked[key])})
	return {"set": number, "qty": copies, "missing": lots}


## A marked lot in words, by the number the set's inventory has it under.
static func _marked_words(key: String, spelled: Dictionary, library: PartLibrary) -> String:
	var spelling: Array = spelled.get(key, [Collection.part_of(key), Collection.colour_of(key)])
	return _lot_words({"part": spelling[0], "colour": spelling[1]}, library)


static func _sorted_keys(counts: Dictionary) -> Array:
	var keys: Array = counts.keys()
	keys.sort()
	return keys


# -- rendering and exporting ---------------------------------------------------------


## What a turntable shows, said with it (mcpreach2). Asked for "the camera
## circling the model while it stands still", APP_UX9's session had six
## frames and said "I can't tell you ... the app's render could be turning the
## car in place in front of a fixed camera". It is drawn so
## (StudioRender.turntable turns the model, its contact shadow and its own
## lamps on a pivot before a still camera, studio lights and backdrop), which
## makes the very frames of a camera going round a model that stands still,
## its lights and backdrop going round with it: so the video is said as it is
## seen, and how it is drawn after.
const TURNTABLE_SAID := ("What happens in it: the camera goes once round the model, a full "
	+ "circle from the %s view's height, while the model stands still; the studio's lights and "
	+ "backdrop go round with the camera, so the shadow keeps its side of the frame. No part of "
	+ "the model moves. The last frame is a step short of the first, so it loops. (It is drawn "
	+ "by turning the model on a turntable before a still camera and lights, which makes exactly "
	+ "these frames.)")


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
	if not kind in ["picture", "turntable", "build"]:
		return "kind is picture, turntable or build."
	# A turntable is thirty-six pictures, a build hundreds: quick and small
	# unless asked. A job all the same (ToolJobs): on a big model even that
	# outlasts the three minutes a session waits for an answer.
	var turning: bool = kind != "picture"
	var quality: Dictionary = {"quick": RenderSettings.Quality.QUICK,
		"good": RenderSettings.Quality.GOOD, "best": RenderSettings.Quality.BEST}
	chosen.quality = quality.get(str(input.get("quality", "quick" if turning else "good")),
		RenderSettings.Quality.GOOD)
	var sizes: Dictionary = {"720p": Vector2i(1280, 720), "1080p": Vector2i(1920, 1080),
		"4k": Vector2i(3840, 2160), "square": Vector2i(1080, 1080)}
	chosen.size = sizes.get(str(input.get("size", "720p" if turning else "1080p")),
		Vector2i(1920, 1080))
	# Render's own views, or one the person saved with the model, by its name
	# (SavedViews): drawn from exactly there.
	var view_asked: String = str(input.get("view", "hero"))
	if view_asked in ["hero", "front", "side", "back", "low", "top"]:
		chosen.view = view_asked
		chosen.forget_eye()
	else:
		var at: int = SavedViews.index_of(world.saved_views, view_asked)
		if at < 0:
			return SavedViews.not_kept(world.saved_views, view_asked) \
				+ " Or view is hero, front, side, back, low or top."
		chosen.keep_view(world.saved_views[at], app.get("_camera") as Camera3D)
	var look: String = str(input.get("look", "window"))
	if not RenderSettings.LOOKS.has(look):
		return "look is %s." % LineArt.looks_in_words()
	chosen.look = look
	if input.has("backdrop"):
		var backdrop: String = str(input["backdrop"])
		if backdrop == "none":
			chosen.use_backdrop("white")
			chosen.transparent = true
		elif not chosen.use_backdrop(backdrop):
			return "backdrop is white, gradient, grey, dark or none."
	# lights (APP_UX5 #7): the light the set is in.
	if input.has("light"):
		var light_wrong: String = chosen.take({"light": input["light"]})
		if not light_wrong.is_empty():
			return light_wrong
	if bool(input.get("depth_of_field", false)):
		# A lens wide enough to blur is many frames through it: Best's.
		chosen.f_stop = 4.0
		chosen.focus = 0.4
		chosen.quality = RenderSettings.Quality.BEST
	if kind == "build":
		var seconds: int = int(input.get("seconds", 20))
		if seconds < BuildRender.SHORTEST or seconds > BuildRender.LONGEST:
			return "seconds is %d to %d." % [BuildRender.SHORTEST, BuildRender.LONGEST]
		chosen.frames = seconds * chosen.fps
		kind = "building"
	# video2 (APP_UX6 #11): a turntable or a build as a GIF.
	var as_gif: Variant = null
	if input.has("format"):
		var format: String = str(input["format"])
		if not format in ["webp", "gif"]:
			return "format is webp or gif."
		if kind == "picture" and format == "gif":
			return "format is a turntable's or a build's: a picture is kept as a PNG."
		as_gif = format == "gif"
	var was: Variant = dialog._last.get("output")
	var said: String = await dialog.render_for(kind, chosen, work, as_gif)
	var how: String = _best_said(dialog, chosen)
	if not how.is_empty():
		said = "%s. %s" % [said.trim_suffix("."), how]
	if kind == "turntable" and dialog._last.get("output") != was \
			and str(dialog._last.get("kind", "")) == "turntable":
		said = "%s.\n%s" % [said.strip_edges().trim_suffix("."), TURNTABLE_SAID % view_asked]
	if kind != "picture":
		return _with_frames(said, dialog, was, chosen.fps)
	if dialog.last_picture() == null:
		return said
	var small: Image = dialog.last_picture().duplicate() as Image
	small.resize(800, maxi(roundi(800.0 * small.get_height() / small.get_width()), 1),
		Image.INTERPOLATE_BILINEAR)
	return [{"type": "text", "text": said}, {"type": "image", "source": {"type": "base64",
		"media_type": "image/png", "data": Marshalls.raw_to_base64(small.save_png_to_buffer())}}]


# -- the render jobs' answers: six frames (APP_UX5 seeing2) ------------------------

## How many frames a turntable's, a build's or a motion's answer shows.
const FRAMES_SHOWN := 6


## [param count] frames' numbers, [constant FRAMES_SHOWN] of them spread
## evenly, the first and the last among them.
static func _six_of(count: int) -> Array:
	var out: Array = []
	for k: int in FRAMES_SHOWN:
		var n: int = roundi(float(k) * float(maxi(count - 1, 0)) / float(FRAMES_SHOWN - 1))
		if not out.has(n):
			out.append(n)
	return out


## A turntable's or a build's answer, [param said], with six of the frames
## it made in one picture, the last its end: for a build, the whole model.
## A session asked for the build video, had the files, and said "I haven't
## watched it myself" (APP_UX5, MCP walk). The frames are the ones Render's
## panel loops (RenderDialog), at most 48 of a long video, the last always
## among them; [param was] is the render before this one's, so a render
## cancelled part way shows nothing of the one before it. [param fps] is
## the render's.
func _with_frames(said: String, dialog: RenderDialog, was: Variant, fps: int) -> Variant:
	var last: Dictionary = dialog._last
	var loop: Array = dialog._loop
	if loop.is_empty() or last.get("output") == was or not str(last.get("kind", "")) in [
			"turntable", "building"]:
		return said
	var frames: int = int(last.get("frames", loop.size()))
	var built: BuildRender = last.get("build") as BuildRender
	fps = maxi(fps, 1)
	# The loop keeps every frame of a turntable and every so many of a build,
	# and its last: which frame each kept one is.
	var every: int = 1 if loop.size() >= frames \
		else ceili(float(frames) / float(RenderDialog.LOOP_MOST))
	var images: Array = []
	var times := PackedStringArray()
	var shown := PackedStringArray()
	for index: int in _six_of(loop.size()):
		var texture: ImageTexture = loop[index]
		var image: Image = texture.get_image() if texture != null else null
		if image == null:
			continue
		images.append(image)
		var n: int = frames - 1 if index == loop.size() - 1 else mini(index * every, frames - 1)
		times.append(Motions.num(float(n) / float(fps), 1))
		if built != null and n < built.shown.size():
			shown.append(str(built.shown[n]))
	var picture: Image = PosePanel.sheet_of(images)
	if picture == null:
		return said
	var lines := PackedStringArray([said.strip_edges()])
	lines.append("The picture: %d of its frames, at %s s, left to right and down, the last its end."
		% [images.size(), ", ".join(times)])
	if built != null and not shown.is_empty():
		lines.append("Parts on show in each: %s of %d; the last is the whole model." % [
			", ".join(shown), built.order.size()])
	return [{"type": "text", "text": "\n".join(lines)}, _picture_block(picture)]


## How Best drew the render just made, in Render's words (RenderSettings
## .best_words), read off what drew it: a session asked for Best with the
## product look and guessed from its 4 seconds whether it was path traced
## (APP_UX4, seeing). "" when it was not Best.
static func _best_said(dialog: RenderDialog, chosen: RenderSettings) -> String:
	if chosen.quality != RenderSettings.Quality.BEST:
		return ""
	var traced: bool = dialog.renderer != null and dialog.renderer.traced_last()
	if traced == chosen.traced_here():
		return "Best was drawn so: " + chosen.best_words()
	# Asked to trace and drawn without, or the other way: what it was drawn as.
	var drawn: RenderSettings = chosen.copy()
	drawn.traced = traced
	return "Best was drawn so: " + drawn.best_words()


# -- lights (APP_UX5 #7): the lights kept with the model -------------------------


## light_model: the lights kept with the model (SceneLights) listed, put in,
## changed or taken out, in the file's coordinates, as Render's Lights in the
## model changes them; each change kept with the model as the window's are
## (ModelStore.touch), and Render's dialog shows it when next opened.
func _light_model(input: Dictionary) -> String:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var lights: Array = SceneLights.in_file(world.scene_lights, store.lift())
	var op: String = str(input.get("op", "list"))
	if op == "list":
		return SceneLights.words(lights)
	if not op in ["add", "change", "remove"]:
		return "op is list, add, change or remove."
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing on the baseplate to light yet."
	var number: Variant = _whole(input.get("number", 0))
	if number == null:
		return "number is a whole number, from 1, as op list numbers the lights; nothing changed."
	var at: int = int(number) - 1
	if op != "add" and (at < 0 or at >= lights.size()):
		if lights.is_empty():
			return "The model keeps no lights yet: op add puts one in."
		return "number is 1 to %d, as op list numbers them; nothing changed." % lights.size()
	if op == "remove":
		lights.remove_at(at)
		_keep_lights(lights)
		return "Took light %d out of the model. %s" % [at + 1, SceneLights.words(lights)]
	if op == "add" and lights.size() >= SceneLights.MOST:
		return "A model keeps at most %d lights: op remove takes one out first." % SceneLights.MOST
	if op == "add" and str(input.get("kind", "spot")) == "directional":
		var no_sun: String = SceneLights.joins(lights, {"kind": "directional"})
		if not no_sun.is_empty():
			return "No sun added: %s. op remove takes one out first." % no_sun
	# What it is hung over: the parts named, or the whole model.
	var box := AABB()
	if input.has("over"):
		var given: Variant = input["over"]
		if not given is Array or (given as Array).is_empty():
			return "over is the parts' numbers, from look_at_model."
		var any: bool = false
		for raw: Variant in given:
			var id: Variant = _whole(raw)
			if id == null:
				return ("over is the parts' numbers, from look_at_model: %s is not one; nothing "
					+ "changed.") % JSON.stringify(raw).left(40)
			var brick: BrickWorld.Brick = world.get_brick(int(id))
			if brick == null or store.scenery.has(int(id)):
				return "No part numbered %s (look_at_model numbers them); nothing changed." % str(id)
			var part: AABB = app.call("_box_of", brick)
			box = box.merge(part) if any else part
			any = true
	else:
		box = app.call("_built_bounds")
	var light: Dictionary
	if op == "add":
		var kind: String = str(input.get("kind", "spot"))
		if not kind in SceneLights.KINDS:
			return "kind is spot, point, directional or area."
		var camera: Camera3D = app.get("_camera")
		var way: Vector3 = box.get_center() - camera.global_position if camera != null \
			else Vector3(-0.5, -0.6, -0.6)
		light = SceneLights.in_file([SceneLights.made(kind, box, way)], store.lift())[0]
	else:
		light = (lights[at] as Dictionary).duplicate()
		if input.has("over"):
			var placed: Dictionary = SceneLights.placed([light], store.lift())[0]
			light = SceneLights.in_file([SceneLights.over(placed, box)], store.lift())[0]
	for field: String in ["at", "aim", "colour", "strength", "cone", "size", "shadows"]:
		if input.has(field):
			light[field] = input[field]
	var found: Array = SceneLights.checked(light)
	var checked: Dictionary = found[0]
	if checked.is_empty():
		return ("That is no light: %s. at and aim are three numbers each (aim not all 0), colour "
			+ "#rrggbb, strength above 0 to %d, cone 2 to 160, size 0 to 4000 (a panel's above "
			+ "0); each kept to a thousandth; nothing changed.") % [found[1],
			roundi(SceneLights.STRONGEST)]
	if op == "add":
		lights.append(checked)
		at = lights.size() - 1
	else:
		lights[at] = checked
	_keep_lights(lights)
	return "%s light %d. %s\nrender_model draws it; light=dark draws it alone." % [
		"Put in" if op == "add" else "Changed", at + 1, SceneLights.words(lights)]


## [param said] as a whole number when it is one (a JSON number, or its
## digits), or null: a session's words are anybody's, and int() of an array
## stopped the call with an error (lreview, 2026-11-07).
static func _whole(said: Variant) -> Variant:
	if said is int:
		return said
	if said is float and is_finite(said) and absf(said) < 1e9 and is_equal_approx(said,
			roundf(said)):
		return roundi(said)
	if said is String and (said as String).is_valid_int() and (said as String).length() < 10:
		return (said as String).to_int()
	return null


## [param lights], in the file's coordinates, as the model's: a new array, as
## the window's are, and the change kept.
func _keep_lights(lights: Array) -> void:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	world.scene_lights = SceneLights.placed(lights, store.lift())
	store.touch()


## File, Render queue…, for a session: the window's own queue (RenderQueue).
func _render_queue(input: Dictionary) -> Variant:
	var action: String = str(input.get("action", "list"))
	if not action in ["add", "list", "pause", "go_on", "finish_now", "cancel", "clear"]:
		return "action is add, list, pause, go_on, finish_now, cancel or clear."
	var queue: RenderQueue = RenderQueue.of(app)
	var number: int = int(input.get("number", 0))
	match action:
		"add":
			if not StudioRender.possible():
				return ("Rendering needs something to draw with, and this app is running "
					+ "without a window. Start it in one (godot --path . -- --mcp).")
			var dialog: Node = app.get("_render")
			var chosen: RenderSettings = (dialog.get("settings") as RenderSettings).copy() \
				if dialog != null else RenderSettings.new()
			if dialog == null:
				chosen.view = "current"
			var options: Dictionary = input.duplicate()
			options.erase("action")
			options.erase("number")
			# A view saved with the model, by its name (SavedViews).
			var from_view: String = ""
			if options.has("view") and not str(options["view"]) in ["current", "hero", "front",
					"side", "back", "low", "top"]:
				from_view = str(options["view"])
				options.erase("view")
			var wrong: String = chosen.take(options)
			if not wrong.is_empty():
				return wrong
			var item: RenderQueue.Item = queue.add(chosen, from_view)
			if item == null:
				return queue.last_refusal
			return ("Queued %d: %s, %s. %s\n%s" % [item.number, item.what(),
				"drawing now" if queue.is_drawing() and item.state == "drawing" else "waiting",
				item.settings.best_words() if item.settings.quality
					== RenderSettings.Quality.BEST else "", "\n".join(queue.lines())]).strip_edges()
		"pause", "go_on":
			queue.pause(action == "pause")
		"finish_now":
			if not queue.finish_now():
				return "Nothing path traced is being drawn, so there is nothing to finish early."
		"cancel":
			if not queue.cancel(number):
				return "There is no render %d still to finish; list numbers them." % number
		"clear":
			queue.clear_finished()
		"list":
			if number > 0:
				var shown: RenderQueue.Item = queue.find(number)
				if shown == null:
					return "There is no render %d; list numbers them." % number
				var line: String = "%d. %s: %s" % [number, shown.what(),
					queue.state_words(shown)]
				if shown.picture == null:
					return line
				return [{"type": "text", "text": line}, {"type": "image", "source": {"type": "base64",
					"media_type": "image/png",
					"data": Marshalls.raw_to_base64(shown.picture.save_png_to_buffer())}}]
	var said: PackedStringArray = queue.lines()
	if said.is_empty():
		return "The queue is empty. " + RenderQueue.best_here()
	return "%s\n%s%s" % ["\n".join(said), "Paused. " if queue.paused else "",
		RenderQueue.best_here()]


# -- mcpsee3: View › Viewpoint › Save this view…, for a session ----------------------


## save_view: where the window looks from now, kept with the model by a name
## by the window's own Save this view… (SavedViews.save_now), or with
## remove=true taken out by its Remove. A session asked to keep the person's
## angle could only tell them how to (APP_UX6, the MCP walk's v4). Answered
## with the model drawn from the view, as view_model view= draws it.
func _save_view(input: Dictionary) -> Variant:
	var shell: Shell = app.get("_shell")
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	if shell == null or world == null or store == null:
		return "This app has no window whose view could be kept."
	var asked: String = Quotes.off(str(input.get("name", "")))
	var name: String = SavedViews.clean_name(asked)
	if name.is_empty():
		return ("name= is what to call the view, as View › Viewpoint will list it: Three "
			+ "quarter, say.")
	var views: SavedViews = shell.saved_views()
	if bool(input.get("remove", false)):
		var at_was: int = SavedViews.index_of(world.saved_views, name)
		if at_was < 0:
			return SavedViews.not_kept(world.saved_views, name)
		var called: String = str((world.saved_views[at_was] as Dictionary)["name"])
		views.remove(called)
		return ("Took the view “%s” out of the model%s. %s" % [called,
			"; those after it each have the key before" if at_was < world.saved_views.size()
				and at_was < SavedViews.KEYED else "", SavedViews.listed(world.saved_views)])
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing built to keep a view of yet."
	var replacing: bool = SavedViews.index_of(world.saved_views, name) >= 0
	if views.save_now(name).is_empty():
		return "The window's view could not be kept."
	var at: int = SavedViews.index_of(world.saved_views, name)
	var view: Dictionary = world.saved_views[at]
	var kept: String = str(view["name"])
	var key: String = Keymap.written(SavedViews.COMMAND + str(at + 1)) \
		if at < SavedViews.KEYED else ""
	var yaw: float = wrapf(rad_to_deg(float(view["yaw"])), -180.0, 180.0)
	var pitch: float = rad_to_deg(float(view["pitch"]))
	var lines := PackedStringArray()
	lines.append("Kept the window's view with the model as “%s”%s, view %d of %d%s." % [kept,
		", replacing the one of that name" if replacing else "", at + 1,
		world.saved_views.size(), "; %s looks from it again in the window" % key
			if not key.is_empty() else ""])
	if kept != asked.strip_edges():
		lines.append("Its name is cut to %d letters on one line, as a view keeps it."
			% SavedViews.LONGEST)
	# Its turn as view_model's sides say it: from the front (+z), round
	# towards +x or -x (CadCamera: a yaw of 0 looks from +z).
	var turned: String = "from the front (+z)" if absf(yaw) < 0.5 \
		else "from %.0f° round from the front (+z) towards %s" % [absf(yaw),
			"+x" if yaw > 0.0 else "-x"]
	lines.append("It looks %s, %.0f° %s level, from %s studs away%s%s." % [turned, absf(pitch),
		"above" if pitch >= 0.0 else "below",
		HandTools._n(snappedf(float(view["distance"]) / HandTools.STUD, 0.1)),
		", square on (View, Orthographic)" if bool(view.get("square", false)) else "",
		", the model turned as Build it had turned it" if view.has("frame") else ""])
	lines.append(("view_model, render_model and render_queue draw from it by its name, "
		+ "view=“%s”. It goes into the model's file at its next save (save_model); until then it "
		+ "is unsaved work, as a view saved in the window is.") % kept)
	var said: String = "\n".join(lines)
	if not bool(input.get("picture", true)) or not StudioRender.possible():
		return said
	var render: Node = app.get("_render")
	if render == null or not render.has_method("picture_of_view"):
		return said
	var window: Vector2 = Vector2(app.get_viewport().get_visible_rect().size)
	var tall: int = clampi(roundi(1024.0 * window.y / maxf(window.x, 1.0)), 256, 1024)
	var drawn: Variant = await render.call("picture_of_view", kept, Vector2i(1024, tall))
	if not drawn is Image:
		return said + "\nNo picture of it: " + str(drawn)
	return [{"type": "text", "text": said + "\nThe model from “%s”, as the window draws it:"
		% kept}, _picture_block(drawn as Image)]


## A coroutine. Words, or for a PDF the words and its cover pictured.
func _export(input: Dictionary, work: Working.Job = null) -> Variant:
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var exports: Exports = app.get("_exports")
	var bar: ModelBar = app.get("_bar")
	# Every saved model, whatever is on the baseplate.
	if str(input.get("format", "")) == "all_models":
		var all: String = await exports.all_models()
		return all.left(1).to_upper() + all.substr(1) + "." if not all.is_empty() \
			else "The person has no saved models yet."
	if world.brick_count() - store.scenery.size() <= 0:
		return "There is nothing on the baseplate to export yet."
	# subexport (APP_UX7 #19): each sub-model, or one, as a file of its own.
	if input.has("submodels") or input.has("submodel"):
		return await _export_submodels(input, exports)
	var said: String = ""
	match str(input.get("format", "")):
		"ldraw":
			said = await bar.export_now(exports.folder)
		"studio":
			said = await exports.studio_io()
		"glb", "gltf", "obj", "stl", "3mf":
			said = await exports.model_3d(str(input["format"]))
		"picture":
			if DisplayServer.get_name() == "headless":
				return "A picture needs something to draw with, and this app is running without a window."
			said = await exports.take_picture()
		"bricklink":
			var wants: Variant = ShopLists.Wants.from(input)
			if wants is String:
				return str(wants).left(1).to_upper() + str(wants).substr(1) + "."
			said = await exports.shop_list("bricklink", {}, false, wants)
		"rebrickable":
			said = await exports.shop_list("rebrickable")
		"pickabrick":
			said = await exports.shop_list("pickabrick")
		"instructions":
			if DisplayServer.get_name() == "headless":
				return "The booklet's pictures need something to draw with, and this app is running without a window."
			if BookletMaker.busy:
				return "The booklet is being drawn already."
			var to: String = exports.folder if not exports.folder.is_empty() \
				else Download.downloads()
			# The next name nothing has there (mcpreach): the last booklet is kept.
			var page: String = "" if OS.has_feature("web") else Download.unused(
				to.path_join(SubmodelFile.titled(bar.model_name(), "_instructions.html")))
			said = _kept_said(await app.call("_export_booklet", page, work), page)
		# mcpreach (APP_UX8 #11): the booklet as the PDF Instructions prints.
		"pdf":
			if OS.has_feature("web"):
				return ("In a browser there is no file to read the booklet back from here: format "
					+ "instructions opens the booklet in a tab of its own, and its Save as PDF button "
					+ "downloads the PDF from the person's click.")
			if DisplayServer.get_name() == "headless":
				return "The booklet's pictures need something to draw with, and this app is running without a window."
			if BookletMaker.busy or bool(app.get("_booklet_writing")):
				return "The booklet is being drawn already."
			return await _booklet_pdf(exports, bar, work)
		_:
			return ("format is ldraw, studio, glb, gltf, obj, stl, 3mf, picture, bricklink, rebrickable, "
				+ "pickabrick, instructions, pdf or all_models.")
	return said.left(1).to_upper() + said.substr(1) + "." if not said.is_empty() else "Nothing written."


# -- mcpreach (APP_UX8 #11): the booklet's PDF -----------------------------------------


## export_model's pdf: the booklet drawn as Instructions draws it, into a page
## of the app's own rather than the person's Downloads, then read a page at
## a time into a PDF as the booklet's own Save as PDF does (main's _pdf_file,
## BookletPdf: the type it is set in carried, each letter mapped back to its
## text), written where Export writes under a name nothing has there. A
## session asked for the booklet as a PDF could hand over only its HTML page,
## and sent the person to the window (APP_UX8's MCP walk, x2).
func _booklet_pdf(exports: Exports, bar: ModelBar, work: Working.Job) -> Variant:
	var named: String = SubmodelFile.titled(bar.model_name(), "_instructions")
	var page: String = OS.get_user_data_dir().path_join("booklet_pdf").path_join(named + ".html")
	DirAccess.make_dir_recursive_absolute(page.get_base_dir())
	var drawn: String = str(await app.call("_export_booklet", page, work))
	if not drawn.begins_with("wrote "):
		return drawn.left(1).to_upper() + drawn.substr(1) + "." if not drawn.is_empty() else "Nothing written."
	var to: String = Download.unused((exports.folder if not exports.folder.is_empty()
		else Download.downloads()).path_join(named + ".pdf"))
	if work != null:
		work.say("Writing the PDF…")
	app.set("_booklet_writing", true)
	var pages: int = int(await app.call("_pdf_file", page, to))
	app.set("_booklet_writing", false)
	var cover: Image = _cover_of(page) if pages > 0 else null
	DirAccess.remove_absolute(page)
	if pages <= 0:
		return "Could not write %s." % to
	SaveTo.wrote(to)
	var missed: String = str(app.get("_pdf_missed"))
	var said: String = "Wrote %s, %d pages, the booklet as Instructions prints it%s%s." % [to, pages,
		missed if not missed.is_empty() else ", every letter in the type the PDF carries, none missing",
		Download.kept_note(to)]
	if cover == null:
		return said
	return [{"type": "text", "text": said + " Its cover, as the PDF prints it:"}, _picture_block(cover)]


## Page 1 of the booklet at [param page], drawn as the PDF prints it, in the
## same answer: asked whether a cover's Russian and Greek print as typed, the
## MCP walk's session wrote the PDF in 3 calls and looked at the cover with
## booklet_page in a fourth (mcpreach). Null when it cannot be drawn.
func _cover_of(page: String) -> Image:
	var html: String = FileAccess.get_file_as_string(page)
	if html.is_empty():
		return null
	var drawer := BookletPng.new()
	app.add_child(drawer)
	var image: Image = drawer.page_image(html, 1, SeeTools.PAGE_DENSITY)
	drawer.queue_free()
	return image


## [param said] with what Download.kept_note says of [param path] at its end,
## once it says it wrote it: the booklet's answer is main's, which names the
## path alone.
static func _kept_said(said: String, path: String) -> String:
	if path.is_empty() or not said.begins_with("wrote " + path):
		return said
	return said + Download.kept_note(path)


# -- subexport (APP_UX7 #19) ----------------------------------------------------------


## export_model's submodels=true: each sub-model as an LDraw file of its own,
## with its own sub-models and steps, in one .zip (Exports.each_submodel);
## submodel=NAME: that one, by its name in the model tree (Exports.submodel).
func _export_submodels(input: Dictionary, exports: Exports) -> String:
	if str(input.get("format", "")) != "ldraw":
		return "submodels and submodel write LDraw files: give them with format ldraw."
	# Both asked, one was written and the other not said (sereview F7).
	if input.has("submodel") and bool(input.get("submodels", false)):
		return "Give submodel=NAME or submodels=true, not both: submodel writes that one, submodels every one in a .zip."
	var said: String = ""
	if input.has("submodel"):
		var paths: PackedStringArray = (app.get("_shell") as Shell).assemblies.paths()
		var asked: String = str(input["submodel"]).strip_edges()
		var path: String = submodel_named(asked, paths)
		if path.is_empty():
			var names := PackedStringArray()
			for each: String in paths:
				var name: String = Assemblies.label(each)
				if not names.has(name) and names.size() < 30:
					names.append(name)
			if names.is_empty():
				return "This model has no sub-models: format ldraw without submodel writes it whole."
			return "No sub-model is called %s. The model tree's: %s." % [asked.left(80),
				", ".join(names)]
		said = await exports.submodel(path)
	elif bool(input.get("submodels", false)):
		said = await exports.each_submodel()
	else:
		said = await (app.get("_bar") as ModelBar).export_now(exports.folder)
	return said.left(1).to_upper() + said.substr(1) + "." if not said.is_empty() else "Nothing written."


## The path in [param paths] (the model tree's) that [param asked] names: the
## path itself ("Ship#1/Wing#2"), the name its row shows ("Wing (copy 2)"),
## or its definition ("Wing", its first copy), whatever the case; "" for none.
static func submodel_named(asked: String, paths: PackedStringArray) -> String:
	var wanted: String = asked.strip_edges().to_lower()
	if wanted.is_empty():
		return ""
	for path: String in paths:
		if path.to_lower() == wanted:
			return path
	for path: String in paths:
		if Assemblies.label(path).to_lower() == wanted \
				or Assemblies.leaf(path).to_lower() == wanted:
			return path
	for path: String in paths:
		if Assemblies.definition(Assemblies.leaf(path)).to_lower() == wanted:
			return path
	return ""


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
				+ "them to choose Make, Brickify a 3D model…, then call brickify with neither "
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
			var why: String = str(fetched["error"])
			# Not "serve it on localhost": that is refused too.
			if why.contains("this computer"):
				return why + " A file on this computer goes in file=, by its path."
			# The site's words, in a browser: too large, or the site would not.
			if why.contains("your computer"):
				return why + (" The person brings it in with Make, Brickify a 3D model…; then brickify "
					+ "with neither url nor pick lays it.")
			return why
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
			+ "choose Make, Brickify a 3D model…, then call brickify with neither file nor url "
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


## How long a link fetched on the desktop is given ([method _fetch]).
const FETCH_SECONDS := 90.0
## And in a browser: the site gives a link 20 s, and its own start and the
## way back come on top ([method _fetch_through_site]).
const SITE_FETCH_SECONDS := 45.0


## The bytes at [param url], fetched as the app fetches pictures of a
## subject (ReferenceFinder), no more than [param most] of them: {"bytes"},
## or {"error"} saying why not. Only http and https, and not this computer
## or the network it is on: a session drives the app, not the person's
## other machines. In a browser, through the app's own site
## ([method _fetch_through_site]).
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
	if OS.has_feature("web"):
		return await _fetch_through_site(url, host, most)
	var got: Array = await PageFetch.ask(app, url, PackedStringArray(["User-Agent: " + ReferenceFinder.AGENT]),
		HTTPClient.METHOD_GET, "", FETCH_SECONDS, most)
	var result: int = int(got[0])
	var code: int = int(got[1])
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return {"error": "%s is larger than %s, more than can be brought in."
			% [url.get_file().left(80), String.humanize_size(most)]}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Could not fetch %s: %s." % [url.left(100), FetchWords.of(result, host,
			FETCH_SECONDS)]}
	if code != 200:
		return {"error": "%s answered %d, not the file." % [host, code]}
	return {"bytes": got[3] as PackedByteArray}


## [method _fetch] in a browser. The page may fetch from a few sites alone
## (its connect-src), and most sites send no CORS headers, so a link came
## back "error 4" from almost anywhere. The app's own site fetches it for
## whoever is signed in (api/_link.js: what it will fetch, from where, and
## at most 4 MB), and says why not in words.
func _fetch_through_site(url: String, host: String, most: int) -> Dictionary:
	var account: Account = app.get("_account")
	var token: String = await account.access_token() if account != null else ""
	if token.is_empty():
		return {"error": "Sign in to Brickworks to bring in a picture or a model from a link."}
	var got: Array = await PageFetch.ask(app, Deployment.api_base() + "/api/account?op=fetch",
		PackedStringArray(["authorization: Bearer " + token, "content-type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify({"url": url}), SITE_FETCH_SECONDS, most)
	var result: int = int(got[0])
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Could not fetch %s: %s." % [url.left(100), FetchWords.of(result,
			"Brickworks's site", SITE_FETCH_SECONDS)]}
	var body: PackedByteArray = got[3]
	if int(got[1]) == 200:
		return {"bytes": body}
	var json := JSON.new()
	var said: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null
	if said is Dictionary and (said as Dictionary).get("error") is String:
		return {"error": str(said["error"])}
	return {"error": "Brickworks's site could not fetch %s just now (it answered %d). Try again in a minute."
		% [host, int(got[1])]}


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
	# the library's, as Make, Printed versions… and a sticker in hand do.
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
	var lettered: String = ""
	if input.has("svg"):
		# Its words are drawn as outlines in the app's font (SvgText), and a
		# word that cannot be is refused: walk239's menu board printed
		# blank, said to be printed.
		var text: Dictionary = SvgText.outline(str(input["svg"]))
		var undrawn: PackedStringArray = text["undrawn"]
		if not undrawn.is_empty():
			return ("Not printed: some of the svg's text cannot be drawn here: %s. Draw those "
				+ "words as <path> outlines and print again.") % ", ".join(undrawn)
		picture = PictureFile.decode(str(input["svg"]).to_utf8_buffer(), "svg")
		if picture == null:
			return "That svg could not be drawn: give a whole <svg> with a viewBox."
		if not (text["words"] as PackedStringArray).is_empty():
			lettered = " Its text was drawn as outlines in the app's font: %s." % ", ".join(
				Array(text["words"]).map(func(one: String) -> String: return "\"%s\"" % one.left(60)))
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
			return str(fetched["error"]) + (" The person brings it in with Make, Print on a part…."
				if str(fetched["error"]).contains("your computer") else "")
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
	# Nothing to print is not printed: an svg whose shapes all fell away
	# came out a clear picture, and was said to be printed.
	if picture.is_invisible():
		return "Not printed: that picture is empty (every pixel clear), so nothing would show on the part."
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
	return "%s It is #%d, %s.%s" % [said, placed.id, placed.part_id, lettered]


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


# -- the weakest joints ---------------------------------------------------------------


## View, Stress's numbers, from the weighing it draws (Main.weigh_joints):
## walk180's session, asked what breaks first, rebuilt the tug in
## check_design four times over 7 minutes to weigh one joint (2026-10-23).
## compare_with_set (setcheck, APP_UX10 #4): the model checked against a real
## set's own model, as File, Compare, Compare with the set… lists it (SetCheck), in one
## call: the changes by the set's own steps, each with its sub-model and line,
## its number and the call that puts it back. Reads only; show=true opens it
## in the window too.
func _compare_with_set(input: Dictionary) -> String:
	var store: ModelStore = app.get("_store")
	var world: BrickWorld = app.get("_world")
	var library: PartLibrary = app.get("_library")
	if store == null or world == null or library == null:
		return "This app has no model to check."
	var checker: GDScript = Later.script(&"SetCheck")
	var asked: String = str(input.get("set", "")).strip_edges()
	if asked.is_empty():
		asked = checker.own_set(store)
	if asked.is_empty():
		return ("Which set? This model was not opened from one, so name it: set= its number, as "
			+ "on its box (7140 or 7140-1). gallery library=true finds the sets the library has; "
			+ "open_model library= opens one.")
	var got: Dictionary = await checker.run(asked, app.get("_model_library"), world, store, library)
	if got["check"] == null:
		return str(got["error"])
	var check: RefCounted = got["check"]
	if bool(input.get("show", false)):
		var shell: Shell = app.get("_shell")
		if shell != null:
			shell.compare.open_set(asked)
	return str(check.said(library, clampi(int(input.get("most", 60)), 1, 400)))


func _weakest_joints(input: Dictionary) -> String:
	if not app.has_method("weigh_joints"):
		return "This app cannot weigh its joints."
	var store: ModelStore = app.get("_store")
	var world: BrickWorld = app.get("_world")
	if world.brick_count() <= store.scenery.size():
		return "There is nothing on the baseplate to weigh."
	var generation: int = world.generation()
	if input.has("lift_by"):
		return await _lift_by(input, generation)
	var report: Stability.Report = await app.call("weigh_joints")
	if report == null:
		return "The parts' shapes were still coming in; ask again in a moment."
	if world.generation() != generation:
		return "Another model was opened while this one was weighed; ask again."
	var said: String = StressView.said(report, world, app.get("_library"), store.scenery,
		clampi(int(input.get("count", 8)), 1, 40), int(input.get("part", 0)))
	return said + await _strengthen_words(report, input)


## loadtest (APP_UX8 #13): the model lifted by part lift_by=, as Stress's Lift
## lifts it (StressView.lift_paced), so the two say the same.
func _lift_by(input: Dictionary, generation: int) -> String:
	var shell: Shell = app.get("_shell")
	var world: BrickWorld = app.get("_world")
	if shell == null or shell.stress == null:
		return "This app cannot lift a model."
	var lifted: RefCounted = await shell.stress.lift_paced(int(input.get("lift_by", 0)), true)
	if lifted == null:
		return "The parts' shapes were still coming in; ask again in a moment."
	if world.generation() != generation:
		return "Another model was opened while this one was lifted; ask again."
	return lifted.call("said", clampi(int(input.get("count", 8)), 1, 40))


# -- strengthen: each weak joint's fix, as a call -----------------------------------


## Each joint [param report] has past its working load or near it, with the
## fewest parts that make it hold, as View, Stress's Strengthen finds and
## puts them down (Strengthen), and the edit_model call that puts down the
## same parts: a session fixes a joint in one call, as the panel does in one
## press. mine=true, of the person's own parts (Parts, My bricks).
func _strengthen_words(report: Stability.Report, input: Dictionary) -> String:
	var shell: Shell = app.get("_shell")
	var panel: StressPanel = shell.stress.panel if shell != null and shell.stress != null else null
	var fixer: RefCounted = panel.fixer_now() if panel != null else null
	if fixer == null:
		return ""
	var store: ModelStore = app.get("_store")
	var world: BrickWorld = app.get("_world")
	var count: int = clampi(int(input.get("count", 8)), 1, 40)
	var part: int = int(input.get("part", 0))
	var wanted: Array = StressView.ranked(report, world, store.scenery, count).filter(
		func(one: StressView.Weak) -> bool:
			return one.margin < StressView.CLOSE and (part == 0 or one.id == part))
	# A model that tips over whole, which no joint's fix stands up: the foot
	# Stress offers for it (Strengthen.find_tip), or why there is none.
	var tips: bool = part == 0 and report.risks.any(func(risk: Stability.Risk) -> bool:
		return risk.kind == "tips")
	if wanted.is_empty() and not tips:
		return ""
	var theirs: Dictionary = panel.owned.call() if bool(input.get("mine", false)) else {}
	var lines := PackedStringArray(["Strengthen, as View, Stress offers it: for each joint past "
		+ "or near its working load, the fewest parts that make it hold (a plate across the "
		+ "seam, a brick under it, a second pin), and for a model that tips over whole, a foot "
		+ "from the floor under the side it tips toward; each checked for room and weighed with "
		+ "the model, and the edit_model call that puts it down as one undo step:"])
	if bool(input.get("mine", false)):
		lines.append("  From your bricks: %s." % ("each part one you own with one left over the "
			+ "model's own" if not theirs.is_empty() else "you have no collection yet (Parts, My "
			+ "bricks), so these are of any parts"))
	fixer.scenery = store.scenery
	fixer.owned = theirs
	var revision: int = world.revision
	if tips:
		var foot: RefCounted = await fixer.find_tip(report)
		if world.revision != revision:
			lines.append("  The model changed while its fixes were looked for; ask again.")
			return "\n" + "\n".join(lines)
		if foot == null:
			var why: String = str(fixer.get("tip_why"))
			lines.append("  The whole model tips over: %s." % (why.left(1).to_lower() + why.substr(1)))
		else:
			lines.append("  The whole model tips over: %s. %s.%s Call edit_model %s" % [foot.what,
				Later.script(&"Strengthen").held_words(foot), "" if theirs.is_empty() else (
					" All from your bricks." if foot.mine
					else " Not all from your bricks: you have none of one left."), _fix_call(foot)])
	var given: Dictionary = {}
	for one: StressView.Weak in wanted:
		var fix: RefCounted = await fixer.find(report, one)
		if world.revision != revision:
			lines.append("  The model changed while its fixes were looked for; ask again.")
			break
		if fix == null:
			lines.append("  #%d: no fix of up to three parts has room there: %s." % [one.id,
				"brace it by hand" if one.joint != null else "hold it with studs by hand"])
			continue
		var call: String = _fix_call(fix)
		if given.has(call):
			lines.append("  #%d: the same fix as #%d, which holds it too." % [one.id, given[call]])
			continue
		given[call] = one.id
		lines.append("  #%d: %s. %s.%s Call edit_model %s" % [one.id, fix.what,
			Later.script(&"Strengthen").held_words(fix), "" if theirs.is_empty() else (" All from your bricks."
				if fix.mine else " Not all from your bricks: you have none of one left."), call])
	return "\n" + "\n".join(lines)


## The edit_model input that puts [param fix]'s parts down where Strengthen
## would: each by its low corner in studs and plates, its face and its turn,
## as edit_model reads a part added (Assistant._square_transform).
func _fix_call(fix: RefCounted) -> String:
	if assistant == null:
		return "(no call: this app has no assistant to make it)"
	var library: PartLibrary = app.get("_library")
	var adds: Array = []
	for item: Dictionary in fix.parts:
		var part_id: String = str(item["part"])
		var at: Transform3D = item["at"]
		var basis: Basis = BrickLattice.snap_basis(at.basis)
		var corner: Vector3 = BrickLattice.to_ldu(BrickLattice.grid_cell(at.origin)
			+ assistant._corner_cell(library.mesh_for(part_id), part_id, basis))
		var face: String = BrickLattice.face_of(basis)
		var spec: Dictionary = {"part": part_id, "color": int(item["color"]),
			"x": _tidy_number(corner.x / Assistant.STUD), "y": _tidy_number(corner.y / Assistant.PLATE),
			"z": _tidy_number(corner.z / Assistant.STUD)}
		if face != "up":
			spec["face"] = face
		var rot: int = BrickLattice.turns_about(basis, face)
		if rot != 0:
			spec["rot"] = rot
		adds.append(spec)
	return JSON.stringify({"add": adds, "picture": false})


## A number as a call writes it: 3, not 3.0; 10.75 as it is.
static func _tidy_number(value: float) -> Variant:
	var snapped: float = snappedf(value, 0.01)
	return int(snapped) if is_equal_approx(snapped, roundf(snapped)) else snapped


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


# -- pointat (APP_UX8 #17): parts pointed out in a Build together session -------------

## point_at: [param input]'s part= or parts= pointed out to everyone in the
## session, as the person's Alt-W does (Together.point_at), named as their
## Claude.
func _point_at(input: Dictionary) -> String:
	var together: Node = app.get("_together_made")
	if together == null or not bool(together.get("live")):
		return ("The person is not in a Build together session, so there is nobody to point a "
			+ "part out to. Building together is the person's to start or join (File › Build "
			+ "together…), by a link they send to whoever they build with.")
	var asked: Array = []
	if input.has("part"):
		asked.append(input["part"])
	if input.get("parts") is Array:
		asked.append_array(input["parts"] as Array)
	if asked.is_empty():
		return "Say which part: part= its number from look_at_model, or parts= several."
	var bricks: Array = []
	var unknown := PackedStringArray()
	for given: Variant in asked:
		var number: int = int(given) if (given is int or given is float) else 0
		if _brick(number) == null or str(together.call("uid_of", number)).is_empty():
			unknown.append(str(given))
		elif not number in bricks:
			bricks.append(number)
	if bricks.is_empty():
		return ("No part %s in the model: the numbers are look_at_model's." % ", ".join(unknown))
	var trouble: String = together.call("point_at", bricks.slice(0, 50), true)
	if not trouble.is_empty():
		return trouble
	var library: PartLibrary = app.get("_library")
	var first: BrickWorld.Brick = _brick(int(bricks[0]))
	var info: PartLibrary.PartInfo = library.parts.get(first.part_id) if library != null else null
	var named: String = "part %d (%s %s)" % [int(bricks[0]),
		library.color(first.color_code).name if library != null else "colour %d" % first.color_code,
		Inventory._tidy(info.name) if info != null else first.part_id] if bricks.size() == 1 \
		else "%d parts" % mini(bricks.size(), 50)
	var here: String = str(together.call("others_here"))
	var said: String = ("Pointed out %s to %s for 5 seconds: outlined in the person's colour on every "
		+ "screen in the session, named as their Claude.") % [named, here] if not here.is_empty() \
		else ("Pointed out %s for 5 seconds, but nobody else in the session is here now: it is "
		+ "outlined on the person's screen alone.") % named
	if not unknown.is_empty():
		said += " No part %s in the model, left out." % ", ".join(unknown)
	return said


# -- rareswap (APP_UX9 #12): replace_parts rare=, the lots hard to buy swapped -----------

## replace_parts rare=true: the model's rare lots (RareSwap), each with its
## swap, swapped as one undo step as the parts list's rare row swaps them,
## or only the lots= named, or listed with preview=true. Said as the rare
## count before and after.
func _rare_swap(input: Dictionary, finder: RefCounted, put_back_first: int = 0) -> String:
	var library: PartLibrary = app.get("_library")
	var named: Dictionary = {}
	if input.has("lots"):
		for key: Variant in input.get("lots"):
			# The part before the slash tidied as find= tidies one ("3622.DAT"),
			# and as the library has it where it moved (rsreview F9).
			var said_key: String = str(key).strip_edges()
			var slash: int = said_key.rfind("/")
			var part: String = said_key.substr(0, slash if slash >= 0 else said_key.length()) \
				.strip_edges().to_lower().trim_suffix(".dat")
			var colour: String = said_key.substr(slash + 1).strip_edges() if slash >= 0 else ""
			named["%s/%s" % [part, colour]] = said_key
			if library.parts.has(part):
				named["%s/%s" % [library.resolve(part), colour]] = said_key
	var store: ModelStore = app.get("_store")
	var swapper: RefCounted = Later.script(&"RareSwap").new(library)
	var stock: Inventory = Inventory.of(app.get("_world"), library, store.scenery)
	if stock.pieces == 0:
		return "The model has no parts yet."
	var rare: Dictionary = await _rare_counted(swapper, stock, library)
	var lots: Array = rare["lots"]
	var said := PackedStringArray()
	said.append(_rare_heading(rare, stock))
	if lots.is_empty():
		return "\n".join(said)
	await swapper.call("offer_all", lots, finder)
	var known: Dictionary = {}
	for lot: RefCounted in lots:
		if named.has(lot.get("key")):
			known[named[lot.get("key")]] = true
		if not named.is_empty():
			lot.set("picked", named.has(lot.get("key")) and lot.call("offered"))
	var unknown: Array = []
	for key: String in named:
		if not known.has(named[key]) and not unknown.has(named[key]):
			unknown.append(named[key])
	for lot: RefCounted in lots:
		var tags := PackedStringArray()
		if lot.call("offered") and not lot.get("picked"):
			if lot.call("drops_print"):
				tags.append("kept: its print stays; name it in lots= to swap it for the plain part")
			elif not named.is_empty():
				tags.append("kept: not named in lots=")
			else:
				tags.append("kept: it would change how the model looks; name it in lots= to swap it")
		said.append("- %s [%s]%s" % [swapper.call("lot_words", lot), lot.get("key"),
			"" if tags.is_empty() else " (" + "; ".join(tags) + ")"])
	if not unknown.is_empty():
		said.append("No rare lot %s here: lots= names them as the list above does." % ", ".join(unknown))
	if bool(input.get("preview", false)):
		said.append("Nothing changed (preview): replace_parts rare=true swaps those that keep "
			+ "the look, lots= [...] only those named.")
		return "\n".join(said)
	var done: Dictionary = await swapper.call("swap", lots, finder)
	var put_back: bool = int(done.get("put_back", 0)) + put_back_first > 0
	if put_back:
		said.append(HAND_WORDS)
	if int(done["changed"]) == 0:
		# The hand put back is a change: "Nothing changed" would have the
		# session send it again (self_attack MCP).
		said.append("%s%s." % ["No lot was swapped" if put_back else "Nothing changed",
			": " + "; ".join(done["stayed"])
			if not (done["stayed"] as PackedStringArray).is_empty()
			else ": no lot named in lots= has a swap" if not named.is_empty()
			else ": no swap keeps the look as it is; name one in lots= to swap it"])
		return "\n".join(said)
	var after: Inventory = Inventory.of(app.get("_world"), library, store.scenery)
	var left: Dictionary = swapper.call("rare_of", after)
	said.append("%s, as one undo step%s. Rare lots now: %d of %d (were %d)." % [
		str(done["words"]).capitalize().left(1) + str(done["words"]).substr(1),
		"" if (done["stayed"] as PackedStringArray).is_empty()
			else "; stayed: " + "; ".join(done["stayed"]),
		(left["lots"] as Array).size(), after.lot_count(), lots.size()])
	return "\n".join(said)


## [param swapper]'s rare lots of [param stock] once every lot's counts are
## here: the web fetches a part's colours file the first time it is asked,
## so it is asked again as they come, for up to 20 s.
func _rare_counted(swapper: RefCounted, stock: Inventory, library: PartLibrary) -> Dictionary:
	var rare: Dictionary = swapper.call("rare_of", stock)
	var until: int = Time.get_ticks_msec() + 20000
	while int(rare["waiting"]) > 0 and Time.get_ticks_msec() < until:
		await (Engine.get_main_loop() as SceneTree).process_frame
		rare = swapper.call("rare_of", stock)
	return rare


## "Rare lots (each in 3 sets or fewer in its colour, by Rebrickable's set
## inventories): 4 of 119 lots, 14 pieces." with those it could not count.
func _rare_heading(rare: Dictionary, stock: Inventory) -> String:
	var lots: Array = rare["lots"]
	var pieces: int = 0
	for lot: RefCounted in lots:
		pieces += int(lot.get("count"))
	var said: String = ("Rare lots (each comes in its colour in 3 sets or fewer, by "
		+ "Rebrickable's set inventories): %d of %d lots, %d pieces." % [lots.size(),
		stock.lot_count(), pieces]) if not lots.is_empty() \
		else "No lot is rare: each comes in its colour in more than 3 sets, by Rebrickable's set inventories (%d lots)." % stock.lot_count()
	if int(rare["unknown"]) > 0:
		said += " %d more %s no set counts to judge by." % [int(rare["unknown"]),
			"has" if int(rare["unknown"]) == 1 else "have"]
	if int(rare["waiting"]) > 0:
		said += " %d could not be counted yet." % int(rare["waiting"])
	return said
# end rareswap


# -- ownswap (APP_UX10 #2): replace_parts mine=, a model rebuilt from what I own ------

## How many of a list an answer names before it counts the rest
## (self_attack: osreview L1 named 40 lots in 8,155 characters).
const OWN_LINES := 10
## Said where there is nothing of the person's to swap in.
const OWN_NONE_WORDS := ("mine=true, but the person's collection is empty, or they are not signed in: there is "
	+ "nothing of theirs to swap in. They add their sets and parts in Build, My collection. "
	+ "Nothing was changed.")
## Said where the part in the person's hand went back first.
const HAND_WORDS := "The part in the person's hand went back where it was first, as Escape puts it."


## replace_parts mine=true: the lots the person owns too few of (OwnSwap,
## as submit_design mine=true counts them), each with the swap from their own
## parts that keeps the look or none, swapped as one undo step as the parts
## list's Use what I own swaps them, or only the lots= named, or listed with
## preview=true. Said as the owned share before and after, and what is still
## missing. Every argument is checked before anything is put back or changed
## ([method _replace_refused]); a part put back first is said in every answer.
func _own_swap(input: Dictionary, finder: RefCounted, put_back_first: int = 0) -> String:
	var library: PartLibrary = app.get("_library")
	var named: Dictionary = {}
	if input.has("lots"):
		for key: Variant in input.get("lots"):
			var said_key: String = str(key).strip_edges()
			var slash: int = said_key.rfind("/")
			var part: String = said_key.substr(0, slash if slash >= 0 else said_key.length()) \
				.strip_edges().to_lower().trim_suffix(".dat")
			var colour: String = said_key.substr(slash + 1).strip_edges() if slash >= 0 else ""
			named["%s/%s" % [part, colour]] = said_key
			if library.parts.has(part):
				named["%s/%s" % [library.resolve(part), colour]] = said_key
	var shell: Shell = app.get("_shell")
	var mine: CollectionStore = shell.collection_store if shell != null else null
	if mine != null and mine.on_hand.is_empty() and not mine.collection.is_empty():
		await mine.refresh_pool()
	var hand: String = ("\n" + HAND_WORDS) if put_back_first > 0 else ""
	if mine == null or mine.on_hand.is_empty():
		return OWN_NONE_WORDS.trim_suffix(" Nothing was changed.") + hand \
			+ ("" if put_back_first > 0 else " Nothing was changed.")
	var store: ModelStore = app.get("_store")
	var world: BrickWorld = app.get("_world")
	if Inventory.of(world, library, store.scenery).pieces == 0:
		return "The model has no parts yet." + hand
	var swapper: RefCounted = Later.script(&"OwnSwap").new(library)
	var before: Dictionary = swapper.call("short_of", world, store.scenery, mine.on_hand)
	var lots: Array = before["lots"]
	var said := PackedStringArray()
	var short: int = 0
	for lot: RefCounted in lots:
		short += int(lot.call("short"))
	said.append(("Against the person's collection (mine=true, as submit_design mine=true and the bin's "
		+ "My bricks count it): %s.") % Later.script(&"OwnSwap").share_words(before))
	if lots.is_empty():
		said.append("Every piece is theirs: nothing to swap.")
		return "\n".join(said) + hand
	said.append("%s they own too few of, %s short in all:" % [Counted.of(lots.size(), "lot"),
		Counted.of(short, "piece")])
	await swapper.call("offer_all", lots, before["free"], finder)
	var known: Dictionary = {}
	for lot: RefCounted in lots:
		if named.has(lot.get("key")):
			known[named[lot.get("key")]] = true
		if not named.is_empty():
			lot.set("picked", named.has(lot.get("key")) and lot.call("offered"))
	var unknown: Array = []
	for key: String in named:
		if not known.has(named[key]) and not unknown.has(named[key]):
			unknown.append(named[key])
	var offered: int = 0
	for lot: RefCounted in lots:
		if lot.call("offered"):
			offered += 1
	var listed: int = 0
	for lot: RefCounted in lots:
		# The swaps first, then those with none, as many as an answer holds.
		if not lot.call("offered"):
			continue
		var tags := PackedStringArray()
		if not lot.get("picked"):
			tags.append("kept: its print stays; name it in lots= to swap it for the plain part"
				if lot.call("drops_print") else "kept: not named in lots=")
		if listed < OWN_LINES:
			said.append("- %s [%s]%s" % [swapper.call("lot_words", lot), lot.get("key"),
				"" if tags.is_empty() else " (" + "; ".join(tags) + ")"])
		listed += 1
	for lot: RefCounted in lots:
		if lot.call("offered"):
			continue
		if listed < OWN_LINES:
			said.append("- %s [%s]" % [swapper.call("lot_words", lot), lot.get("key")])
		listed += 1
	if listed > OWN_LINES:
		said.append("  and %d more lots." % (listed - OWN_LINES))
	said.append("%d of the %d have a swap from their own parts." % [offered, lots.size()])
	if not unknown.is_empty():
		said.append("No lot %s here that they own too few of: lots= names them as the list above does."
			% ", ".join(unknown.slice(0, 10)) + ("" if unknown.size() <= 10
			else " (and %d more)" % (unknown.size() - 10)))
	if bool(input.get("preview", false)):
		said.append("Nothing changed (preview): replace_parts mine=true swaps those that keep "
			+ "the look, lots= [...] only those named.")
		return "\n".join(said)
	var done: Dictionary = await swapper.call("swap", lots, finder)
	var put_back: bool = int(done.get("put_back", 0)) + put_back_first > 0
	if put_back:
		said.append(HAND_WORDS)
	if int(done["changed"]) == 0:
		# The hand put back is a change: "Nothing changed" would have the
		# session send it again (self_attack MCP).
		said.append("%s%s." % ["No lot was swapped" if put_back else "Nothing changed",
			": " + "; ".join(done["stayed"])
			if not (done["stayed"] as PackedStringArray).is_empty()
			else ": no lot named in lots= has a swap" if not named.is_empty()
			else ": none of the lots has a swap from their own parts"])
		return "\n".join(said)
	var after: Dictionary = swapper.call("short_of", world, store.scenery, mine.on_hand)
	said.append("%s, as one undo step%s. Now %s (was %d%%)." % [
		str(done["words"]).left(1).to_upper() + str(done["words"]).substr(1),
		"" if (done["stayed"] as PackedStringArray).is_empty()
			else "; stayed: " + "; ".join(done["stayed"]),
		Later.script(&"OwnSwap").share_words(after),
		int(floor(float(Later.script(&"OwnSwap").share(before)) * 100.0))])
	var missing: String = Later.script(&"OwnSwap").missing_words(after)
	if missing.is_empty():
		said.append("Every piece is now theirs.")
		return "\n".join(said)
	var still := PackedStringArray()
	for lot: RefCounted in after["lots"]:
		if still.size() >= OWN_LINES:
			break
		still.append("  %d × %s (%s) in %s" % [int(lot.call("short")), lot.get("name"), lot.get("part"),
			lot.get("colour_name")])
	said.append("Still missing: %s, each with how many:\n%s%s\nTell them what to get, "
		% [missing, "\n".join(still), "" if (after["lots"] as Array).size() <= OWN_LINES
			else "\n  and %d more lots." % ((after["lots"] as Array).size() - OWN_LINES)]
		+ "or change each to a part they own with edit_model; parts_list which=\"need\" lists what is short.")
	return "\n".join(said)
# end ownswap


# -- swapfind (APP_UX8 #9): Find and Replace into every sub-model ---------------------

static func _replace_parts_definition() -> Dictionary:
	var parts: Dictionary = {"type": "object", "additionalProperties": false, "properties": {
		"part": {"type": "string",
			"description": "a part's number as look_at_model and parts_list give it (\"3023b\"); a mould's number finds every letter of it (\"3023\" finds 3023a and 3023b)"},
		"color": {"type": "integer",
			"description": "an LDraw colour code: 0 Black, 72 Dark Bluish Grey, 71 Light Bluish Grey; or a direct colour as its number (0x2FF0000, 50266112); in replace=, never 16 or 24, which are no part's own colour"},
	}}
	return {
		"name": "replace_parts",
		"description": ("Find and replace parts across the whole model in one call, as the "
			+ "person's Edit › Find and replace… does: find= a part, a colour or a part in a "
			+ "colour; replace= another part, another colour or both, each part keeping what "
			+ "it is not given. where= \"all\" (the default) is every part of the model, inside "
			+ "every sub-model and every copy of one; \"submodel\" the sub-model the person is "
			+ "editing and every copy of it; \"selection\" the parts selected. A sub-model's "
			+ "copies are one definition, so a part replaced in one is replaced in every copy, "
			+ "and a copy placed by a mirror is given the new part's other hand. One call is "
			+ "one undo step, and the model saves as the window's own replace saves it. The "
			+ "answer lists where the part is (the model and each sub-model, with counts and "
			+ "copies) and every colour it is used in, flags a part used in more than one "
			+ "colour, and says where a new part will not sit as the old one did (another "
			+ "footprint, other connection points) or would hold onto nothing, and where it has "
			+ "no room and is left. A part in a copy changes with its twin in every other copy "
			+ "or not at all: where one copy has no room for the new part, or the part is locked "
			+ "in one, every copy keeps it, and the answer says so. replace= {\"part\"} is a "
			+ "number the library has (search_parts finds one), and the answer names the part "
			+ "it puts in. With no replace= or with preview=true it changes nothing and lists "
			+ "only. rare=true, in place of find= and replace=, lists the lots hard to buy (a "
			+ "part in a colour that comes in 3 sets or fewer, by Rebrickable's inventories) "
			+ "each with a swap that comes in 20 or more: the same shape in its colour (another "
			+ "mould, or a print's plain part) or the nearest colour of the same transparency "
			+ "and finish (ΔE), one colour for a colour's lots. It swaps, as one undo step, "
			+ "only those that keep the model's look, as the parts list's rare row picks them: "
			+ "the same shape in its colour, or a colour within ΔE 10 of the same finish; "
			+ "every other, a print's plain part among them, is listed as kept, with what it "
			+ "changes, and swaps only where lots= names it. lots= [\"3023b/379\", ...] swaps "
			+ "only those; with preview=true it lists and changes nothing. mine=true, in place "
			+ "of find= and replace=, rebuilds the model from the person's own collection (as "
			+ "the parts list's Use what I own does): each lot they own too few of, as "
			+ "submit_design mine=true counts it, is swapped, only its missing pieces, for a part "
			+ "or colour they have free that keeps the look (an equal part in its colour, or the "
			+ "same part in a colour within ΔE 10 of the same finish), two lots never taking the "
			+ "same pieces, or said to have none they own; a print's plain part only where lots= "
			+ "names it. The answer gives the owned share before and after and what is still "
			+ "missing. A part lifted in the person's hand goes back where it was first, as "
			+ "Escape puts it."),
		"input_schema": {"type": "object", "additionalProperties": false,
			"properties": {
				"find": parts,
				"replace": parts,
				"where": {"type": "string", "enum": ["all", "submodel", "selection"],
					"description": "where to look; \"all\" when not given"},
				"preview": {"type": "boolean",
					"description": "list what would change, and change nothing"},
				# rareswap (APP_UX9 #12)
				"rare": {"type": "boolean",
					"description": "true: the lots that come in 3 sets or fewer, each offered a common part or colour, those that keep the look swapped; no find= or replace= with it"},
				"lots": {"type": "array", "items": {"type": "string"},
					"description": "with rare=true or mine=true, only these lots, \"part/colour\" as its list names each (\"3794a/19\"), whatever their swap changes; a print named here swaps to its plain part"},
				# ownswap (APP_UX10 #2)
				"mine": {"type": "boolean",
					"description": "true: the lots the person owns too few of (their collection, as submit_design mine=true counts it), each swapped for a part or colour of their own that keeps the look, or said to have none; the owned share before and after and what is still missing said; no find= or replace= with it"},
			}},
	}


## How many parts in the person's hand went back where they were before this
## call's change was measured ([method put_back_first]), for its answer.
var _put_back_first: int = 0


## A replace_parts call that changes the model puts what the person lifted
## back where it was first, as Escape puts it, before CommandSocket measures
## the call's change: put back inside the call, the call's one step took
## the part for one the call put down, and its undo took the part away
## (rsfix, F5). A lift with a step of theirs over it stays, and the call
## refuses (FindReplace.HELD_WORDS).
func put_back_first(name: String, input: Dictionary) -> void:
	_put_back_first = 0
	if name != "replace_parts" or input.get("preview") == true:
		return
	if input.get("rare") != true and input.get("mine") != true and not (input.get("replace") is Dictionary
			and not (input["replace"] as Dictionary).is_empty()):
		return
	# A call it will refuse changes nothing, the hand included: every
	# argument is checked before anything is put back (osreview M2: lots="x"
	# put the part back, then said "Nothing was changed").
	if not _replace_refused(input).is_empty():
		return
	_put_back_first = maxi(int(Later.script(&"FindReplace").new(app).call("put_back_held")), 0)


## What replace_parts refuses in what it was given, before anything is put
## back or changed: "" when it takes it. rare=true and mine=true each take
## no find=, replace= or where=, and lots= a list of them; a plain replace
## its find= and replace= objects, a where= it knows, colours a part can
## be, a part the library has and, for where="selection", a selection.
func _replace_refused(input: Dictionary) -> String:
	var rare: bool = input.get("rare") == true
	var mine: bool = input.get("mine") == true
	if rare and mine:
		return ("rare=true and mine=true are two swaps: rare=true swaps the lots hard to buy for "
			+ "common ones, mine=true the lots the person owns too few of for their own parts. "
			+ "Give one. Nothing was changed.")
	if rare or mine:
		if input.has("find") or input.has("replace") or input.has("where"):
			return ("rare=true takes no find=, replace= or where=: it finds the lots hard to buy "
				+ "everywhere itself. Give lots= to swap only some.") if rare \
				else ("mine=true takes no find=, replace= or where=: it finds the lots the person owns "
				+ "too few of everywhere itself. Give lots= to swap only some. Nothing was changed.")
		if input.has("lots") and (not input.get("lots") is Array or (input.get("lots") as Array).is_empty()):
			return ("lots= is a list of lots as the rare list names them: lots= [\"3794a/19\"]." if rare
				else "lots= is a list of lots as mine=true's list names them: lots= [\"3001/4\"]. Nothing was changed.")
		if mine:
			var shell: Shell = app.get("_shell")
			var store: CollectionStore = shell.collection_store if shell != null else null
			if store == null or store.on_hand.is_empty() and store.collection.is_empty():
				return OWN_NONE_WORDS
		return ""
	if input.has("lots"):
		return ("lots= goes with rare=true or mine=true: replace_parts rare=true lots= [\"3794a/19\"] "
			+ "swaps only the rare lots named, mine=true lots= only those of the person's lots named. "
			+ "A plain replace takes find= and replace=.")
	for side: String in ["find", "replace"]:
		if input.has(side) and not input.get(side) is Dictionary:
			return "%s= is an object: %s= {\"part\": \"3023\"}, {\"color\": 72}, or both." % [side, side]
	var finder: RefCounted = Later.script(&"FindReplace").new(app)
	var asked: Dictionary = input.get("find", {}) if input.get("find") is Dictionary else {}
	var into: Dictionary = input.get("replace", {}) if input.get("replace") is Dictionary else {}
	var where: String = str(input.get("where", "all"))
	if not where in ["all", "submodel", "selection"]:
		return "where= is \"all\", \"submodel\" or \"selection\"."
	for side: Array in [["find", asked], ["replace", into]]:
		if int(finder.call("colour_of", (side[1] as Dictionary).get("color"))) == -2:
			return ("No colour %s in %s=: give an LDraw colour code (0 Black, 72 Dark Bluish "
				+ "Grey), or a direct colour as a file writes it (\"0x2FF0000\"), as %s= "
				+ "{\"color\": 72}.") % [(side[1] as Dictionary).get("color"), side[0], side[0]]
	if str(asked.get("part", "")).strip_edges().is_empty() and int(finder.call("colour_of", asked.get("color"))) == -1:
		return ("Say what to find: find= {\"part\": \"3023\"}, {\"color\": 0}, or both; or "
			+ "rare=true for the lots hard to buy.")
	var not_a_colour: String = Later.script(&"FindReplace").not_a_part_colour(
		int(finder.call("colour_of", into.get("color"))))
	if not not_a_colour.is_empty():
		return not_a_colour
	var part: String = str(into.get("part", "")).strip_edges()
	if not part.is_empty() and str(finder.call("known_part", part)).is_empty():
		return ("No part %s in the library to replace with: give its number as search_parts "
			+ "or look_at_model gives it, as replace= {\"part\": \"3023b\"}.") % part
	if where == "selection" and (app.get("_builder") as Builder).selection.is_empty():
		return "Nothing is selected: where=\"all\" looks in the whole model."
	return ""


## replace_parts: Find and Replace (FindReplace), as the window's bar does it.
## What it is given is held to the shapes its schema shows, and a refusal
## shows the shape to give (swreview F5, F7, F8): find= and replace=
## objects; a colour an LDraw code or a direct colour (0x2RRGGBB), and to
## give a part, none of 16 (a sub-model's placing colour) or 24 (an edge's);
## a part to put in by its number as the library has it, never a search's
## guess, and named in the answer (F4).
func _replace_parts(input: Dictionary) -> String:
	var finder: RefCounted = Later.script(&"FindReplace").new(app)
	var first: int = _put_back_first
	_put_back_first = 0
	var refused: String = _replace_refused(input)
	if not refused.is_empty():
		return refused
	# Only rare=true is the rare swap: a client that sends every boolean
	# sends rare=false with a plain find= and replace= (rsreview F4).
	if input.get("rare") == true:
		return await _rare_swap(input, finder, first)
	# ownswap: the same, only mine=true (a false one is as if not sent).
	if input.get("mine") == true:
		return await _own_swap(input, finder, first)
	var asked: Dictionary = input.get("find", {}) if input.get("find") is Dictionary else {}
	var into: Dictionary = input.get("replace", {}) if input.get("replace") is Dictionary else {}
	var where: String = str(input.get("where", "all"))
	var find: Dictionary = {"part": str(asked.get("part", "")).strip_edges(),
		"color": finder.call("colour_of", asked.get("color"))}
	var put: Dictionary = {"part": str(into.get("part", "")).strip_edges(),
		"color": finder.call("colour_of", into.get("color"))}
	var puts: String = ""
	if not str(put["part"]).is_empty():
		var known: String = finder.call("known_part", put["part"])
		put["part"] = known
		puts = "\nPuts in %s (%s)." % [finder.call("part_name", known), known]
	# A part lifted and in the person's hand, back where it was before the
	# find, so it is found and changed with the rest rather than lost (F5).
	var put_back: int = 0
	if (not str(put["part"]).is_empty() or int(put["color"]) >= 0) \
			and not bool(input.get("preview", false)):
		put_back = finder.call("put_back_held")
		if put_back < 0:
			return "Nothing changed: %s." % Later.script(&"FindReplace").HELD_WORDS
	put_back += first
	var found: Dictionary = finder.call("find", find, where)
	var listed: String = finder.call("listed", found)
	if (found["ids"] as Array).is_empty():
		return listed
	var changes: bool = not str(put["part"]).is_empty() or int(put["color"]) >= 0
	if not changes or bool(input.get("preview", false)):
		var ahead: String = ""
		if changes:
			ahead = await finder.call("ahead", found, put)
		return listed + puts + ("\n" + ahead if not ahead.is_empty() else "") \
			+ ("\nNothing changed (preview)." if changes else "\nGive replace= to change them.")
	var ahead: String = await finder.call("ahead", found, put)
	var done: Dictionary = finder.call("replace", found, put)
	var said: String = listed + puts + ("\n" + ahead if not ahead.is_empty() else "") \
		+ ("\nThe part in the person's hand went back where it was first, as Escape puts it."
			if put_back > 0 else "")
	var stayed: String = str(done.get("stayed", ""))
	if stayed.begins_with("All "):
		stayed = "a" + stayed.substr(1)
	if int(done["changed"]) == 0:
		return said + "\nNothing changed: %s." % (stayed if not stayed.is_empty()
			else "none had room for it")
	var copies: String = finder.call("copies_words", found)
	return said + "\nReplaced %d with %s %s, as one undo step%s.%s" % [int(done["changed"]),
		finder.call("into_words", put), finder.call("where_words", found),
		"" if copies.is_empty() else "; it " + copies + ", as an edit inside a sub-model does",
		"" if stayed.is_empty() else " %d stayed: %s." % [int(done["room"])
			+ int(done["locked"]), stayed]]
