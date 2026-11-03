## What the desktop updater trusts, and what this install is: the signed
## manifest read and checked, versions compared, and where an update would
## go (Updater does the fetching and the installing).
##
## The updater runs code it downloads, so it is the strictest edge in the
## app (docs/UPDATES.md). A release writes latest.json (tools/release.py):
## the manifest's JSON text exactly as signed, and its signatures, RSA over
## SHA-256 by a key whose private half is only on the machine that builds
## releases. The app knows two public halves, the key in use and a backup,
## so a lost key can be replaced by an app signed with the other. Nothing in
## the manifest is read until a signature over its exact bytes holds; then
## every address in it must be https on GitHub's hosts or brickworks.diy,
## and every file carries its size and SHA-256, which the download must
## match before it is unpacked.
class_name Updates
extends RefCounted

## The public halves of the keys latest.json is signed with, by id: the
## first 16 hex digits of the SHA-256 of the key's DER. tools/release.py
## signs with each key .env holds (UPDATE_SIGN_KEY, UPDATE_SIGN_KEY_BACKUP).
const KEYS: Dictionary = {
	"c5b33bfc36dce935": """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAmLNuBPHKMnOG4Ill8GTV
yo8UGO7qdMD3xUSIoB1dM0956CiIoeJK1Sh5TYji/7CZMsWyS6us4jl2S41aLUSe
c41ARZAOZFrknMphBI7XxOt0lS+7omVymPtMckZRMmGKDDcqP3Jd4HLUNi7YjKtU
vFVVRbGXYVsOOeNGBp4phtHcYqPuZ6F1M2JXG/vLbsyKbYphVfFaqndTlYIOi2nd
Mveg0IOF08XtPhVnigNzGnNNUQTtDoe5EyVjryGCnCL6JuTdb+H1DDn6qZOiD3HN
tputg0EKsSHFd/3BB/0dLi97ROwtsm2tad4KjMM0vfXgvXZrDpupZ6c4F6EiglJr
lD4Es9RfKum3IAXkPJoGX7HpE0E9fQpJ1SsFtNRmsWZPQmTq1GrTfy10RSJx6Zf0
y0/IyXjSaKGB3PJqi1d/YlS+KoWkLnQKX8cCQ7Rr9SCVY9UR92DW0AFke7yaEuLw
WEd2BV804KqQaQvUYgoTrJlCqzHjg9CabKmjxFXM1yJlAgMBAAE=
-----END PUBLIC KEY-----
""",
	"d41127750efef101": """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA0OA+fDrSskVWxpZZpN9z
fhu66nPy338xF9fuqlu8r4gy9de/rdxvBV5tKkh26EW6nDjGosIeiJTjqhoFnRMG
rwfU58XnZWjwpoSeKh3nVTHWaNbWY2emLI8CNFCm1dw05RMcgk3n7IzBQL4IR5q2
CNvnyY+u6BenKIPkCBoKKQNVcCWDmDoV/S6JJkvrNxTNYfsHpjlLwuoDcafGrslk
Y6Uwna6L/kKxl1aF4IjZmOo4WYqWjItsCk40F+v7ATlbR1twS3K0tOrJ9y7rkSKo
R3R6J4XyipoTYN3bOC09nSLvtIi/513VjkVJAtJKfZAT4IG/uXDue6KvlBHxN2UB
1w/bguF73c8PB+VE5gK0xK/ANGCpeF17aAPXqvJz5mnNmvorTyHi6VtStMWeRxk3
Jwr02a6y9WwpQnCTqTR1Wst4/e3bYVbKUNmocWZw8oSa2ameRrMjzBinJeMura1g
d98HLJNGHKPD+lVdKPr8VesT1qdY1mr4Lj99mZbaY6BrAgMBAAE=
-----END PUBLIC KEY-----
""",
}

## What the manifest says it is for: a manifest of anything else signed by
## the same key is not one of ours.
const PRODUCT := "brickworks-desktop"

## Where the releases are. The newest's latest.json is at latest/download/,
## and each release's own at download/<tag>/ (Reinstall).
const RELEASES := "https://github.com/Xaxis/brickworks-releases/releases/"

## Where a person downloads it by hand, when this copy cannot update itself.
const DOWNLOAD := "https://brickworks.diy/download"

## The hosts an address may name, a redirect included: GitHub's pages, its
## file stores (release downloads were sent to objects.githubusercontent.com
## and since 2025 to release-assets.githubusercontent.com), and the site.
const HOSTS: Array[String] = ["github.com", "objects.githubusercontent.com",
	"release-assets.githubusercontent.com", "brickworks.diy"]

## What a manifest may weigh: a few KB in fact.
const MANIFEST_MOST := 1 << 20

## For a probe: other keys in place of the release's (a probe makes its own
## and signs with it, and a package can never be given one).
static var keys_for_probe: Dictionary = {}


## The address latest.json is fetched from: the newest release's, or this
## version's own when [param version] is given. BRICKWORKS_UPDATE_URL, set by
## hand, puts a test server in place of GitHub's releases (tools/update_check.py).
static func manifest_url(version: String = "") -> String:
	var base: String = test_base()
	if base.is_empty():
		base = RELEASES
	return base + ("latest/download/latest.json" if version.is_empty()
		else "download/v%s/latest.json" % version)


## A test server's address, from BRICKWORKS_UPDATE_URL, or "". Ends with "/".
static func test_base() -> String:
	var base: String = OS.get_environment("BRICKWORKS_UPDATE_URL").strip_edges()
	if base.is_empty():
		return ""
	return base if base.ends_with("/") else base + "/"


## Why [param url] may not be fetched, or "" when it may: https only, on one
## of HOSTS. A test server named by hand is let in as well, and over plain
## HTTP only when it is this machine.
static func refuse_url(url: String) -> String:
	var parts: Dictionary = _split(url)
	if parts.is_empty():
		return "not an address: %s" % url
	var test: Dictionary = _split(test_base())
	if not test.is_empty() and parts["host"] == test["host"] and parts["port"] == test["port"] \
			and (parts["scheme"] == "https" or test["host"] in ["127.0.0.1", "localhost", "[::1]"]):
		return ""
	if parts["scheme"] != "https":
		return "refused plain HTTP: %s" % url
	if not str(parts["host"]) in HOSTS:
		return "refused an address off GitHub and brickworks.diy: %s" % url
	return ""


## {scheme, host, port} of an absolute http(s) address, or {}.
static func _split(url: String) -> Dictionary:
	var shaped: RegExMatch = RegEx.create_from_string(
		"^(https?)://([A-Za-z0-9.-]+|\\[[0-9A-Fa-f:]+\\])(?::(\\d{1,5}))?(/[^\\s]*)?$").search(url)
	if shaped == null:
		return {}
	var scheme: String = shaped.get_string(1).to_lower()
	var port: String = shaped.get_string(3)
	return {"scheme": scheme, "host": shaped.get_string(2).to_lower(),
		"port": port if not port.is_empty() else ("443" if scheme == "https" else "80")}


## Where a redirect's Location sends [param from]: an absolute address, or a
## path on the same host.
static func resolve(from: String, location: String) -> String:
	if location.begins_with("https://") or location.begins_with("http://"):
		return location
	var root: RegExMatch = RegEx.create_from_string("^(https?://[^/]+)").search(from)
	if root == null or not location.begins_with("/"):
		return ""
	return root.get_string(1) + location


## -1, 0 or 1 as version [param a] is older than, the same as or newer than
## [param b], by semantic versioning: 0.10.0 after 0.9.0, and 1.0.0-beta.2
## before 1.0.0. A version that is not one sorts before every version.
static func compare(a: String, b: String) -> int:
	var x: Array = _parsed(a)
	var y: Array = _parsed(b)
	if x.is_empty() or y.is_empty():
		return 0 if x.is_empty() == y.is_empty() else (-1 if x.is_empty() else 1)
	for n: int in 3:
		if int(x[n]) != int(y[n]):
			return 1 if int(x[n]) > int(y[n]) else -1
	var p: PackedStringArray = x[3]
	var q: PackedStringArray = y[3]
	# A release comes after its pre-releases.
	if p.is_empty() or q.is_empty():
		return 0 if p.is_empty() == q.is_empty() else (1 if p.is_empty() else -1)
	for n: int in mini(p.size(), q.size()):
		if p[n] == q[n]:
			continue
		var numeric: bool = p[n].is_valid_int() and q[n].is_valid_int()
		if numeric:
			return 1 if p[n].to_int() > q[n].to_int() else -1
		if p[n].is_valid_int() != q[n].is_valid_int():
			return -1 if p[n].is_valid_int() else 1
		return 1 if p[n] > q[n] else -1
	return 0 if p.size() == q.size() else (1 if p.size() > q.size() else -1)


static func is_version(text: String) -> bool:
	return not _parsed(text).is_empty()


## [major, minor, patch, pre-release parts], or [] when [param text] is not a version.
static func _parsed(text: String) -> Array:
	var found: RegExMatch = RegEx.create_from_string(
		"^(0|[1-9]\\d{0,8})\\.(0|[1-9]\\d{0,8})\\.(0|[1-9]\\d{0,8})(?:-([0-9A-Za-z.-]+))?$").search(text)
	if found == null:
		return []
	var pre: PackedStringArray = PackedStringArray()
	if not found.get_string(4).is_empty():
		pre = found.get_string(4).split(".")
	return [found.get_string(1).to_int(), found.get_string(2).to_int(),
		found.get_string(3).to_int(), pre]


## latest.json's [param bytes] read: {"manifest": what it says} once a
## signature over its exact words holds and every field is what it must be,
## or {"why": why not}. Nothing in it is believed before the signature is.
static func read(bytes: PackedByteArray) -> Dictionary:
	var outer: Variant = _parsed_json(bytes.get_string_from_utf8())
	if not outer is Dictionary:
		return {"why": "latest.json is not a manifest"}
	var signed: Variant = (outer as Dictionary).get("signed")
	var signatures: Variant = (outer as Dictionary).get("signatures")
	if not signed is String or not signatures is Array:
		return {"why": "latest.json is not a manifest"}
	if not verified((signed as String).to_utf8_buffer(), signatures as Array):
		return {"why": "refused: the manifest's signature does not hold"}
	var manifest: Variant = _parsed_json(signed as String)
	if not manifest is Dictionary:
		return {"why": "refused: the signed manifest does not parse"}
	var why: String = refuse_manifest(manifest as Dictionary)
	if not why.is_empty():
		return {"why": why}
	return {"manifest": manifest}


## [param text] as JSON, or null: a server's error page is no engine error.
static func _parsed_json(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


## Whether one of [param signatures] ({key, rsa_sha256}) is a known key's
## over [param data].
static func verified(data: PackedByteArray, signatures: Array) -> bool:
	var known: Dictionary = keys_for_probe if not keys_for_probe.is_empty() else KEYS
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	var hashed: PackedByteArray = digest.finish()
	var crypto := Crypto.new()
	for each: Variant in signatures:
		if not each is Dictionary:
			continue
		var id: String = str((each as Dictionary).get("key", ""))
		var said: String = str((each as Dictionary).get("rsa_sha256", ""))
		if not known.has(id) or said.is_empty():
			continue
		var key := CryptoKey.new()
		if key.load_from_string(str(known[id]), true) != OK:
			continue
		var signature: PackedByteArray = Marshalls.base64_to_raw(said)
		if not signature.is_empty() and crypto.verify(HashingContext.HASH_SHA256, hashed,
				signature, key):
			return true
	return false


## Why a signed [param manifest] is still refused, or "": what it is for, its
## version, and each file's system, kind, address, size and SHA-256.
static func refuse_manifest(manifest: Dictionary) -> String:
	if str(manifest.get("product", "")) != PRODUCT:
		return "refused: the manifest is not Brickworks'"
	if not is_version(str(manifest.get("version", ""))):
		return "refused: the manifest's version is not a version"
	var files: Variant = manifest.get("files")
	if not files is Array or (files as Array).is_empty():
		return "refused: the manifest lists no files"
	for each: Variant in files as Array:
		if not each is Dictionary:
			return "refused: a file in the manifest is not described"
		var item: Dictionary = each
		var size: Variant = item.get("size")
		if not (size is float or size is int) or float(size) < 1.0 or float(size) > 1e11 \
				or float(size) != floorf(float(size)):
			return "refused: %s has no size" % str(item.get("name", "a file"))
		if RegEx.create_from_string("^[0-9a-f]{64}$").search(str(item.get("sha256", ""))) == null:
			return "refused: %s has no SHA-256" % str(item.get("name", "a file"))
		if not str(item.get("name", "")).begins_with("Brickworks-"):
			return "refused: a file in the manifest is not Brickworks'"
		var why: String = refuse_url(str(item.get("url", "")))
		if not why.is_empty():
			return why
	return ""


## The file [param manifest] lists for system [param os] and package kind
## [param kind], or {}.
static func file_for(manifest: Dictionary, os: String, kind: String) -> Dictionary:
	for each: Variant in manifest.get("files", []):
		if each is Dictionary and str((each as Dictionary).get("os", "")) == os \
				and str((each as Dictionary).get("kind", "")) == kind:
			return each
	return {}


## The release notes' first words, for the notice: at most [param most]
## letters, cut at a word.
static func whats_new(manifest: Dictionary, most: int = 280) -> String:
	var notes: String = str(manifest.get("notes", "")).strip_edges()
	notes = RegEx.create_from_string("\\s+").sub(notes, " ", true)
	if notes.length() <= most:
		return notes
	var cut: int = notes.rfind(" ", most)
	return notes.left(cut if cut > most / 2 else most).strip_edges() + "…"


## The SHA-256 of the file at [param path], as hex, or "" when it cannot be
## read. Run off the main thread: a package is hundreds of megabytes.
static func sha256_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		var block: PackedByteArray = file.get_buffer(1 << 20)
		if block.is_empty():
			break
		digest.update(block)
	return digest.finish().hex_encode()


## What this copy of the app is, and where an update of it would go:
##   kind      "appimage", "tar.xz", "mac", "windows", or "" where it cannot
##             update itself (the web, a build run from source)
##   os, package   the manifest's system and kind of file for it
##   target    what is replaced: the AppImage, or the folder or .app
##   stage     the folder an update is unpacked in, beside the target so the
##             swap is a rename on one disk
##   launch    how to start it, the person's arguments after
##   about     how to ask a copy at the target which version it is
##   why_not   why it cannot update itself here, or ""
##   moves_to  on a Mac run from Downloads or a disk image (translocated):
##             the Applications folder it would be moved to
static func here() -> Dictionary:
	if OS.has_feature("web"):
		return {"kind": "", "why_not": "The web app is updated by the site"}
	if not OS.has_feature("template"):
		return {"kind": "", "why_not": "This is a development build: updates come with the downloaded app"}
	var exe: String = OS.get_executable_path()
	var found: Dictionary = {}
	if OS.get_name() == "Linux" or OS.get_name() == "FreeBSD":
		var image: String = OS.get_environment("APPIMAGE")
		if not image.is_empty():
			found = {"kind": "appimage", "os": "linux", "package": "AppImage", "target": image,
				"launch": [image], "about": [image]}
		else:
			var folder: String = exe.get_base_dir()
			found = {"kind": "tar.xz", "os": "linux", "package": "tar.xz", "target": folder,
				"launch": [exe], "about": [folder.path_join(exe.get_file())]}
	elif OS.get_name() == "macOS":
		# .../Brickworks.app/Contents/MacOS/Brickworks
		var app: String = exe.get_base_dir().get_base_dir().get_base_dir()
		if not app.ends_with(".app"):
			return {"kind": "", "why_not": "Brickworks is not in an app bundle here"}
		found = {"kind": "mac", "os": "macos", "package": "zip", "target": app,
			"launch": ["open", "-n", app, "--args"],
			"about": [app.path_join("Contents/MacOS").path_join(exe.get_file())]}
		# Run from Downloads or a disk image, macOS gives the app a read-only
		# copy of itself somewhere random (App Translocation): it can only be
		# updated once it is in Applications.
		if "/AppTranslocation/" in app or app.begins_with("/Volumes/"):
			var into: String = "/Applications"
			if not _writable(into):
				into = OS.get_environment("HOME").path_join("Applications")
			found["moves_to"] = into.path_join("Brickworks.app")
			found["target"] = found["moves_to"]
			found["launch"] = ["open", "-n", found["moves_to"], "--args"]
			found["about"] = [str(found["moves_to"]).path_join("Contents/MacOS").path_join(exe.get_file())]
	elif OS.get_name() == "Windows":
		var folder: String = exe.get_base_dir()
		found = {"kind": "windows", "os": "windows", "package": "zip", "target": folder,
			"launch": [exe], "about": [folder.path_join(exe.get_file().get_basename() + ".console.exe")]}
	else:
		return {"kind": "", "why_not": "Brickworks cannot update itself on %s" % OS.get_name()}
	var parent: String = str(found["target"]).get_base_dir()
	found["stage"] = parent.path_join(".brickworks-update")
	found["why_not"] = "" if _writable(parent) else (
		"Brickworks can't update itself in %s, where it is installed: download the new version from brickworks.diy/download" % parent)
	return found


## Whether a folder can be written in: a file made there and taken away.
static func _writable(folder: String) -> bool:
	if not DirAccess.dir_exists_absolute(folder):
		return false
	var probe: String = folder.path_join(".brickworks-write-%d" % OS.get_process_id())
	var file: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true
