extends Node
## Checks GitHub Releases for a newer version and tells the menu to show an Update button.
## When the app moves to Google Play, set STORE_URL to the Play listing and the button opens that instead.

signal update_available(version: String, url: String)

const RELEASES_API := "https://api.github.com/repos/oyekamal/ek-tap/releases/latest"
const STORE_URL := ""                  # e.g. "https://play.google.com/store/apps/details?id=com.oyekamal.ektap"
const CHECK_EVERY := 6 * 3600          # seconds between checks

var latest := ""                       # newer version found this session ("" = none)
var url := ""

func _ready() -> void:
	var last: int = Save.get_data("updater", "last_check", 0)
	var now := int(Time.get_unix_time_from_system())
	if now - last < CHECK_EVERY:
		_use_cached()
		return
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(_on_done.bind(http))
	if http.request(RELEASES_API, ["Accept: application/vnd.github+json", "User-Agent: ek-tap"]) != OK:
		http.queue_free()

func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))

func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return   # offline or rate-limited: try again next launch
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var tag: String = str(data.get("tag_name", "")).trim_prefix("v")
	var page: String = str(data.get("html_url", ""))
	for a in data.get("assets", []):
		if str(a.get("name", "")).ends_with(".apk"):
			page = str(a.get("browser_download_url", page))
	Save.set_data("updater", "last_check", int(Time.get_unix_time_from_system()))
	Save.set_data("updater", "tag", tag)
	Save.set_data("updater", "url", page)
	_use_cached()

func _use_cached() -> void:
	var tag: String = Save.get_data("updater", "tag", "")
	if tag != "" and is_newer(tag, current_version()):
		latest = tag
		url = STORE_URL if STORE_URL != "" else str(Save.get_data("updater", "url", ""))
		update_available.emit(latest, url)

func open() -> void:
	if url != "":
		OS.shell_open(url)

## "1.10.0" > "1.9.2"; missing parts count as 0.
static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
