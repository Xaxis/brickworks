## A long piece of work spread over frames, without being made slow by it.
##
## Work that walks a whole model — putting a design down, staging the copy
## a picture is taken of — is a slice at a time: it runs until its slice is
## spent, then gives the frame back so the page can draw and answer.
##
## A slice is 12 ms where frames come sixty a second, and grows to half a
## frame where frames are slow. In a browser drawing in software a frame is
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
const MOST_US := 100000

var _until: int = 0


func _init() -> void:
	_until = Time.get_ticks_usec() + _slice()


## Whether this slice is spent.
func due() -> bool:
	return Time.get_ticks_usec() > _until


## Give the frame back, and begin the next slice.
func next() -> void:
	await Engine.get_main_loop().process_frame
	_until = Time.get_ticks_usec() + _slice()


static func _slice() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var frame_us: int = int(tree.root.get_process_delta_time() * 1000000.0) \
		if tree != null else 0
	return clampi(frame_us / 2, LEAST_US, MOST_US)
