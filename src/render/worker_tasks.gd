## Work on the engine's worker threads, let go of before the app is gone.
##
## The engine keeps a task, and the GDScript function it runs with all it
## captured, until somebody waits for it. Work waited for over frames, so the
## page keeps drawing, was not when the app quit in between: a model of 600
## parts or more is weighed on a worker after every change (Main._weigh), and
## quitting while that ran left its task to the engine, which freed it after
## GDScript had gone and dumped core on the way out (SIGSEGV, then SIGABRT):
## after every big file opened just before quitting, and whatever the app had
## left to do as it closed went with it (2026-10-16).
##
## So the app's tasks start and end here, and any still out when the scene
## tree goes (the window closed, File, Quit, Ctrl+Q, any quit()) are waited
## for then, while their scripts can still be freed. One still running is
## waited for to its end, as the engine waits for it anyway. What a task
## reads must outlive it: a node that frees what its task uses lets the task
## end first (BrickifyDialog._exit_tree).
##
##   var task: int = WorkerTasks.add(func() -> void: ..., false, "weigh the model")
##   while not WorkerThreadPool.is_task_completed(task):
##       await get_tree().process_frame
##   WorkerTasks.collect(task)
class_name WorkerTasks
extends RefCounted

## Tasks added and not collected yet: id -> true.
static var _out: Dictionary = {}
static var _lock := Mutex.new()
static var _watching: bool = false
## Kinds of work [method first_here] has run: kind -> true.
static var _run_here: Dictionary = {}
static var _first_lock := Mutex.new()


## Run [param work] here and now, on this thread, if nothing of [param kind]
## has run yet in this run of the app, and say whether it did. Work that is
## about to run on several workers at once asks first, and starts the rest
## on workers after.
##
## The engine crashes when two threads run a GDScript operator for its first
## time at once. Godot 4.7.2 keeps, in the function's own bytecode, what an
## operator on a value of no fixed type turned out to take (an untyped
## Array's element, an object compared with null), and writes it there the
## first time the operator runs: the operand types first, the function that
## does it last (modules/gdscript/gdscript_vm.cpp:805-809). A thread at the
## same operator in between reads the types, takes the function, finds
## nothing and calls address 0. The app was gone the moment it started with
## parts kept from files (CustomParts.load_all), every worker building one
## at the same line of PartForge at once; the worker's GDScript backtrace
## ended at the operator, its C++ one at the signal, and the crash handler,
## running on the worker, said the root node cannot be told from it
## (crashfind, 2026-10-17). An operator that has run once on one thread is
## never written again, so what this runs first is safe on any number after.
static func first_here(kind: String, work: Callable) -> bool:
	_first_lock.lock()
	var first: bool = not _run_here.has(kind)
	if first:
		# Held while it runs: a second thread asking waits until it is done.
		work.call()
		_run_here[kind] = true
	_first_lock.unlock()
	return first


## [method WorkerThreadPool.add_task], kept until [method collect].
static func add(work: Callable, high_priority: bool = false, description: String = "") -> int:
	var task: int = WorkerThreadPool.add_task(work, high_priority, description)
	_lock.lock()
	_out[task] = true
	_lock.unlock()
	_watch()
	return task


## Wait for [param task] to end, and let the engine let go of it. Nothing
## when it has been already.
static func collect(task: int) -> void:
	_lock.lock()
	var out: bool = _out.erase(task)
	_lock.unlock()
	if out:
		WorkerThreadPool.wait_for_task_completion(task)


## Every task not collected yet, collected.
static func collect_all() -> void:
	_lock.lock()
	var tasks: Array = _out.keys()
	_lock.unlock()
	for task: int in tasks:
		collect(task)


## How many tasks are out.
static func out() -> int:
	_lock.lock()
	var count: int = _out.size()
	_lock.unlock()
	return count


## As the tree goes, before anything in it is freed.
static func _watch() -> void:
	if _watching or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	tree.root.tree_exiting.connect(WorkerTasks.collect_all)
	_watching = true
