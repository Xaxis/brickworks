## How the desktop app draws: in its full mode (Forward+, on Vulkan, Metal
## or Direct3D 12), or in its simpler one (Compatibility, on OpenGL), which
## is what every browser gets.
##
## Graphics that cannot run the full mode start the simpler one by
## themselves, before the full one can fail. A Mac's launcher asks Metal
## what the GPU is (tools/release/package/launcher.c): Apple's paravirtual
## one, every macOS VM on an Intel host, closed the app inside Vulkan with
## nothing said, which no fallback of Godot's can catch, and it says why in
## BRICKWORKS_GRAPHICS. Windows and Linux fall back in Godot itself where
## Vulkan, and on Windows Direct3D 12, will not start.
##
## Said once (to_say), and in Settings, Graphics, where a person chooses
## either for themselves: kept in graphics.cfg in the app's own folder,
## which Godot reads as it starts (project.godot,
## application/config/project_settings_override), and the launcher too, so
## the choice outlives an update.
class_name GraphicsMode
extends RefCounted

const WHERE := "user://graphics.cfg"
## Settings, Graphics, in its order.
const CHOICES: Array[String] = ["automatic", "full", "simpler"]
const _METHODS: Dictionary = {"full": "forward_plus", "simpler": "gl_compatibility"}


## Whether this window draws in the simpler mode. The web always does, and
## there it is the browser's mode, not a lesser one: only the desktop's is.
static func simpler() -> bool:
	return not OS.has_feature("web") \
		and RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Chosen in this run where nothing is written (ShellPrefs.keeps): a probe's.
static var _chosen_here: String = ""


## What the person chose in Settings, Graphics: "automatic" until they do.
static func chosen() -> String:
	if not _chosen_here.is_empty():
		return _chosen_here
	var file := ConfigFile.new()
	if file.load(WHERE) != OK:
		return "automatic"
	var method: String = str(file.get_value("rendering", "renderer/rendering_method", ""))
	for choice: String in _METHODS:
		if _METHODS[choice] == method:
			return choice
	return "automatic"


## Settings, Graphics: [param choice] from the next start on. Automatic
## leaves no file, so Godot and the launcher choose as for anyone.
static func choose(choice: String) -> void:
	_chosen_here = choice
	if not ShellPrefs.keeps():
		return
	if choice == "automatic":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WHERE))
		return
	var file := ConfigFile.new()
	file.set_value("", "config_version", 5)
	file.set_value("rendering", "renderer/rendering_method", _METHODS[choice])
	file.save(WHERE)


## What the launcher found, when it chose the simpler mode for this Mac:
## "Apple Paravirtual device, 1024 MB". Elsewhere, "".
static func why() -> String:
	return OS.get_environment("BRICKWORKS_GRAPHICS")


## The line said once where the app started in its simpler mode by itself,
## and "" when it is not to be said: in the full mode, chosen by the person,
## or said before (ShellPrefs, said_simpler_graphics). In English, as the
## label it goes in translates it.
static func to_say() -> String:
	if not simpler() or chosen() != "automatic" or bool(ShellPrefs.value("said_simpler_graphics")):
		return ""
	ShellPrefs.put("said_simpler_graphics", true)
	if OS.get_name() == "macOS":
		return "This Mac's graphics run Brickworks in its simpler mode."
	return "This computer's graphics run Brickworks in its simpler mode."


## For the log, at every start: which mode, and why.
static func describe() -> String:
	var mode: String = "simpler" if simpler() else "full"
	var because: String = chosen() if chosen() != "automatic" else (
		"automatic" + (": " + why() if not why().is_empty() else ""))
	return "graphics: %s mode (%s), %s on %s" % [mode, because,
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()]
