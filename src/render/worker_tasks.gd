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
