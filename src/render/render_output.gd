## Where a render goes: a download in a browser; on the desktop, a file in
## Downloads, and for a turntable its frames in a folder, an animated WebP
## beside them and, where ffmpeg is installed, an MP4.
##
## Encoding is done on a worker where there are workers: a 4K PNG is a
## second or two of a browser's one thread otherwise, and the page would
## stop answering at the very end of a render that took care not to.
class_name RenderOutput
extends RefCounted

## Where desktop files go; Downloads when empty. A probe points it at its own.
var folder: String = ""
## What was written or downloaded, for the person and for a check.
var said: PackedStringArray = PackedStringArray()
var paths: PackedStringArray = PackedStringArray()
var last_bytes: int = 0

var _webp: AnimatedWebP
var _frames_dir: String = ""
var _frame_size: Vector2i = Vector2i.ZERO
var _base: String = ""
var _settings: RenderSettings


## Where files go on the desktop.
func where() -> String:
	return folder if not folder.is_empty() else Download.downloads()


## A file name from a model's name: its last part only, so no title can
## put a file outside the folder.
static func file_name(model: String, suffix: String, extension: String) -> String:
	var base: String = model.replace("\\", "/").get_file().to_snake_case()
	if base.is_empty():
		base = "model"
	return "%s%s.%s" % [base, suffix, extension]


## Keep a picture as a PNG, encoded on a worker. Returns the line to show.
func keep_picture(image: Image, model: String) -> String:
	var bytes: Array = [PackedByteArray()]
	var name: String = file_name(model, "_render", "png")
	var work := func() -> void: bytes[0] = image.save_png_to_buffer()
	if OS.has_feature("nothreads"):
		work.call()
		return give(bytes[0], name, "image/png")
	var task: int = WorkerTasks.add(work, false, "encode a render")
	_keeping = [task, bytes, name]
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerTasks.collect(task)
	_keeping = []
	return give(bytes[0], name, "image/png")


## A picture being encoded: [task, [bytes], file name], or empty.
var _keeping: Array = []
## ffmpeg making the MP4, while it is: its process and the file.
var _mp4_pid: int = 0
var _mp4_out: String = ""


## Whether a picture or a turntable is still being written.
func writing() -> bool:
	return not _keeping.is_empty() or not _pending.is_empty() or _mp4_pid > 0


## As the app closes, with a render still being written: what is done is
## written now, here, and what cannot be is said. Its coroutines go with the
## scene tree and never come back to write what their workers made, and a
## picture encoded as the window closed was lost without a word. Returns
## the lines to say.
func close_now() -> PackedStringArray:
	var lines := PackedStringArray()
	if not _keeping.is_empty():
		WorkerTasks.collect(int(_keeping[0]))
		lines.append(give((_keeping[1] as Array)[0], str(_keeping[2]), "image/png"))
		_keeping = []
	if _webp != null:
		for waiting: Array in _pending:
			WorkerTasks.collect(int(waiting[0]))
			_keep_frame(int(waiting[2]), waiting[1])
		_pending.clear()
		if _mp4_pid > 0 and OS.is_process_running(_mp4_pid):
			lines.append("ffmpeg is still making %s and finishes it on its own" % _mp4_out)
		elif _mp4_pid == 0 and _webp.frame_count() > 0:
			lines.append("the turntable was not finished: %d frames kept%s, no WebP or MP4"
				% [_webp.frame_count(), " in %s" % _frames_dir if not _frames_dir.is_empty() else ""])
	return lines


## Hand bytes to the person: downloaded in a browser, written on the desktop.
func give(bytes: PackedByteArray, name: String, mime: String) -> String:
	last_bytes = bytes.size()
	var line: String
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, name, mime)
		line = "downloaded %s" % name
		paths.append(name)
	else:
		var path: String = where().path_join(name)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			line = "could not write %s" % path
		else:
			file.store_buffer(bytes)
			file.close()
			line = "wrote %s" % path
			paths.append(path)
	said.append(line)
	return line


## Begin a turntable for [param model] — or, called "_animation", any run
## of frames kept the same way.
func begin_turntable(model: String, settings: RenderSettings,
		suffix: String = "_turntable") -> void:
	_settings = settings
	_base = file_name(model, suffix, "x").get_basename()
	_webp = AnimatedWebP.new(settings.fps)
	_webp.with_alpha(settings.transparent)
	_frame_size = Vector2i.ZERO
	_frames_dir = ""
	if not OS.has_feature("web"):
		_frames_dir = where().path_join(_base)
		DirAccess.make_dir_recursive_absolute(_frames_dir)


## One frame of it: into the WebP, and on the desktop a PNG in the folder.
## Encoded on a worker while the next frame is drawn: waited for, a 720p
## WebP encode in a browser was most of each frame's time, and a turntable
## of 36 took minutes. At most a few wait, so a long one holds few frames.
func add_frame(n: int, image: Image) -> void:
	_frame_size = Vector2i(image.get_width(), image.get_height())
	var encoded: Array = [PackedByteArray(), PackedByteArray()]
	var desktop: bool = not _frames_dir.is_empty()
	var work := func() -> void:
		encoded[0] = image.save_webp_to_buffer(true, 0.9)
		if desktop:
			encoded[1] = image.save_png_to_buffer()
	if OS.has_feature("nothreads"):
		work.call()
		_keep_frame(n, encoded)
		return
	_pending.append([WorkerTasks.add(work, false, "encode a turntable frame"),
		encoded, n])
	await _drain(MOST_PENDING)


const MOST_PENDING := 3
## [task, encoded, frame number], oldest first.
var _pending: Array = []


func _drain(keep: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while _pending.size() > keep:
		var oldest: Array = _pending[0]
		while not WorkerThreadPool.is_task_completed(int(oldest[0])):
			await tree.process_frame
		WorkerTasks.collect(int(oldest[0]))
		_pending.pop_front()
		_keep_frame(int(oldest[2]), oldest[1])


func _keep_frame(n: int, encoded: Array) -> void:
	_webp.add_encoded(encoded[0], _frame_size)
	if not _frames_dir.is_empty():
		var path: String = _frames_dir.path_join("frame_%04d.png" % (n + 1))
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(encoded[1])
			file.close()


## Wait for every frame still being encoded; a cancelled turntable must
## not leave work behind.
func settle() -> void:
	await _drain(0)


func frames_added() -> int:
	return _webp.frame_count() if _webp != null else 0


## The WebP, and on the desktop the MP4 if ffmpeg is here. Returns the
## lines to show.
func finish_turntable() -> PackedStringArray:
	await _drain(0)
	var lines := PackedStringArray()
	if _webp == null or _webp.frame_count() == 0:
		return lines
	lines.append(give(_webp.bytes(), _base + ".webp", "image/webp"))
	if not _frames_dir.is_empty():
		lines.append("frames in %s" % _frames_dir)
		var made: String = await _mp4()
		if not made.is_empty():
			lines.append(made)
	return lines


## ffmpeg, if it is installed: on the PATH, or where Homebrew and the
## usual packages put it (an app started from the Dock has no shell PATH).
static func ffmpeg() -> String:
	if OS.has_feature("web"):
		return ""
	for candidate: String in ["ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg",
			"/usr/bin/ffmpeg"]:
		var output: Array = []
		if OS.execute(candidate, ["-hide_banner", "-version"], output, true) == 0:
			return candidate
	return ""


func _mp4() -> String:
	var tool: String = ffmpeg()
	if tool.is_empty():
		return "no MP4: ffmpeg is not installed"
	var out: String = where().path_join(_base + ".mp4")
	var colour: Color = _settings.backdrop if _settings != null else Color.WHITE
	var size: Vector2i = _frame_size
	# An MP4 has no alpha: a transparent turntable goes on its backdrop
	# colour, and both sides even, which H.264's colour format needs.
	var arguments: PackedStringArray = ["-y", "-hide_banner", "-loglevel", "error",
		"-framerate", str(_settings.fps if _settings != null else 24),
		"-i", _frames_dir.path_join("frame_%04d.png"),
		"-f", "lavfi", "-i", "color=c=0x%s:s=%dx%d" % [colour.to_html(false), size.x, size.y],
		"-filter_complex",
		"[1][0]overlay=shortest=1,pad=ceil(iw/2)*2:ceil(ih/2)*2,format=yuv420p",
		"-c:v", "libx264", "-crf", "18", "-movflags", "+faststart", out]
	var pid: int = OS.create_process(tool, arguments)
	if pid <= 0:
		return "no MP4: ffmpeg would not start"
	_mp4_pid = pid
	_mp4_out = out
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while OS.is_process_running(pid):
		await tree.process_frame
	_mp4_pid = 0
	var written: FileAccess = FileAccess.open(out, FileAccess.READ)
	var length: int = written.get_length() if written != null else 0
	if written != null:
		written.close()
	if length == 0:
		return "no MP4: ffmpeg did not write one"
	paths.append(out)
	return "wrote %s" % out
