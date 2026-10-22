## A long piece of work spread over frames, without being made slow by it.
##
## Work that walks a whole model — putting a design down, staging the copy
## a picture is taken of — is a slice at a time: it runs until its slice is
## spent, then gives the frame back so the page can draw and answer.
##
## A slice is 12 ms where frames come sixty a second, and grows to half a
## frame, up to 50 ms, where frames are slow. In a browser drawing in software a frame is
## more than a second, and giving one back forty times over made putting
## the owner's 4,242-part Falcon Heavy down take most of a minute: Claude's
## call ran out of time before the tab answered it.
##
##   var pace := FramePace.new()
##   for ...:
##       ...
##       if pace.due():
##           await pace.next()
class_name FramePace
extends RefCounted

const LEAST_US := 12000
const MOST_US := 50000
## Out of view, a slice is this long whatever the frames. Nobody is there to
## feel the page pause, and a tab out of view is given a frame only 33 ms
## after the last has run (ClaudeConnector._watch_the_page), so half-frame
## slices left a design going down at about half speed while Claude waited.
const UNWATCHED_US := 200000

## Whether nobody can see the app. Main says so.
static var unwatched: bool = false

var _until: int = 0
## The least a slice is: [constant LEAST_US] unless asked for more.
var _least: int = LEAST_US


## [param least_us]: slices of at least this long, for work that draws
## nothing while it goes on (a model being laid, ModelStore._open_into), where
## each frame given back costs as much again as a short slice.
func _init(least_us: int = LEAST_US) -> void:
	_least = least_us
	_until = Time.get_ticks_usec() + _slice(_least)


## Whether this slice is spent.
func due() -> bool:
	return Time.get_ticks_usec() > _until


## Give the frame back, and begin the next slice.
func next() -> void:
	# Work going on, though it may draw nothing until it is done: frames
	# at full rate, not the slower ones of a model standing still.
	IdleDraw.keep_awake()
	await Engine.get_main_loop().process_frame
	_until = Time.get_ticks_usec() + _slice(_least)


static func _slice(least: int = LEAST_US) -> int:
	if unwatched:
		return maxi(UNWATCHED_US, least)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var frame_us: int = int(tree.root.get_process_delta_time() * 1000000.0) \
		if tree != null else 0
	return clampi(frame_us / 2, least, maxi(MOST_US, least))
