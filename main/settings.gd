@tool
extends Node
class_name Setting

static var _instance: Setting       = null
static var _game_reader: GameReader = null
const _project_settings_root: String = "ai_contest_viewer"
var _invalid_env_regex: RegEx        = _invalid_env_regex_fn()
# Internals of the loader
var _loaded: bool             = false
var _all_settings: Dictionary = {}


func _init() -> void:
	assert(_instance == null, "Only 1 settings instance at a time!")
	_instance = self
	# HACK: Allow special env overrides before ini (like changing the file path)
	_load_custom_settings_env()
	_load_custom_settings_web()
	# Load all custom settings...
	_load_custom_settings_ini()
	# Reload overrides giving more priority to env and web...
	_load_custom_settings_env()
	_load_custom_settings_web()
	_loaded = true
	if _val("settings/print_custom", true):
		print(" === LOADED SETTINGS ===")
		var all_keys = _all_settings_info.keys()
		all_keys.sort()
		for setting_name: String in all_keys:
			print(" - " + setting_name + " = " + str(_val(setting_name)))
		print(" === END OF LOADED SETTINGS ===")


func _load_parse_and_set(setting_name: String, raw: String, from: String):
	var setting = _all_settings_info[setting_name]
	var val     = _parse_string(raw, setting)
	if _val("settings/print_custom", true):
		print("[settings > " + from + "] Custom setting: " + setting_name + " -> " + str(val))
	_all_settings[setting_name] = val


func _load_custom_settings_env() -> void:
	# Fill project config from environment variables
	if _val("settings/print_custom", true):
		print("[settings] Loading setting overrides from environment variables")
	for setting_name: String in _all_settings.keys():
		# Replace all invalid characters in the environment variable name regex
		var env_name: String = _invalid_env_regex.sub(setting_name, "_", true)
		if OS.has_environment(env_name):
			_load_parse_and_set(setting_name, OS.get_environment(env_name), "env")


func _load_custom_settings_web() -> void:
	# Fill project config from query parameters on web export
	if OS.has_feature("web"):
		if _val("settings/print_custom", true):
			print("[settings] Loading setting overrides from query parameters")
		var queryParams = JSON.parse_string(JavaScriptBridge.eval("JSON.stringify(new URLSearchParams(window.location.search))"))
		for setting_name: String in _all_settings.keys():
			var query_name: String = _invalid_env_regex.sub(setting_name, "_", true)
			if queryParams.has(query_name):
				_load_parse_and_set(setting_name, queryParams[query_name], "web")


func _load_custom_settings_ini() -> void: # Will enter first in the scene tree (but after all _init() functions)
	# Fill project config from config.ini file
	var settings_path   = _val("settings/path", true)
	var create_defaults = _val("settings/create_defaults", true)
	create_defaults = create_defaults if create_defaults != null else OS.has_feature("standalone")

	var config: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		if _val("settings/print_custom", true):
			print("[settings] Loading setting overrides from " + str(settings_path))
		config.load(settings_path)

	for setting_name: String in _all_settings_info.keys():
		var section: String = setting_name.substr(0, setting_name.rfind("/"))
		var key: String     = setting_name.substr(setting_name.rfind("/") + 1)
		if config.has_section_key(section, key):
			var val_str = str(config.get_value(section, key))
			_load_parse_and_set(setting_name, val_str, "ini")

	# Save the default settings file if it doesn't exist and the user wants it
	if create_defaults and not FileAccess.file_exists(settings_path):
		print("[settings] Saving all settings to " + ProjectSettings.globalize_path(settings_path))
		FileAccess.open(settings_path, FileAccess.WRITE).store_string(generate_ini(true))


func generate_ini(skip_check: bool = false) -> String:
	# Custom exporter to add documentation
	var exported_ini: String = ""
	var last_section: String = ""
	var all_keys             = _all_settings_info.keys()
	all_keys.sort()
	for setting_name: String in all_keys:
		var setting         = _all_settings_info[setting_name]
		var section: String = setting_name.substr(0, setting_name.rfind("/"))
		var key: String     = setting_name.substr(setting_name.rfind("/") + 1)
		if section != last_section:
			if last_section != "":
				exported_ini += "\n\n"
			exported_ini += "[" + section + "]\n"
			last_section = section
		exported_ini += "; " + setting["info"] + " (default: " + str(setting["default"]) + ")\n"
		exported_ini += key + "=\"" + str(_val(setting_name, skip_check)) + "\"\n"

	return exported_ini


func _parse_string(_value: String, setting: Dictionary) -> Variant:
	if _value == "<null>":
		return null
	match setting["type"]:
		TYPE_BOOL:
			return _value.to_lower() == "true"
		TYPE_INT:
			return int(_value)
		TYPE_FLOAT:
			return float(_value)
		TYPE_STRING:
			return _value
		TYPE_VECTOR2:
			var split: PackedStringArray = _value.split(",")
			return Vector2(float(split[0]), float(split[1]))
		TYPE_VECTOR3:
			var split: PackedStringArray = _value.split(",")
			return Vector3(float(split[0]), float(split[1]), float(split[2]))
		TYPE_COLOR:
			var split: PackedStringArray = _value.split(",")
			return Color(float(split[0]), float(split[1]), float(split[2]), float(split[3]))
		_:
			print("[warning] Unsupported type for setting " + setting["name"] + ": " + str(setting["type"]))
			return _value


func _invalid_env_regex_fn() -> RegEx:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex


## Retrieves the value of a previously defined setting.
func _val(path: String, skip_check: bool = false) -> Variant:
	assert(_loaded or skip_check, "Settings must be loaded before they can be accessed.")
	return _all_settings.get(path, _all_settings_info[path]["default"])



## Supports @tool by using default values if no instance is available
static func _s_val(path: String) -> Variant:
	if _instance != null && _instance._loaded:
		return _instance._val(path)
	else:
		return _all_settings_info[path]["default"]

# ========== ALL SETTINGS ==========

static var _all_settings_info: Dictionary = \
	{
		"settings/path": {
			"default": "user://settings.ini",
			"type": TYPE_STRING,
			"info": "The path to the settings file.",
		},
		"settings/create_defaults": {
			"default": null,
			"type": TYPE_BOOL,
			"info": "Whether to create the default settings file if it does not exist (default is false in editor, true in export).",
		},
		"settings/print_custom": {
			"default": true,
			"type": TYPE_BOOL,
			"info": "Whether to print out all custom settings that are loaded.",
		},
		"common/seed": {
			"default": 42,
			"type": TYPE_INT,
			"info": "The seed to generate the same island, camera paths, etc.",
		},
		"game/path": {
			"default": "res://testdata/game.jsonl.gz",
			"type": TYPE_STRING,
			"info": "The game path to load. It may be a tcp:// for a tcp server or simply a Godot data path.",
		},
		"terrain/cell_side": {
			"default": 10.0,
			"type": TYPE_FLOAT,
			"info": "The side of a cell in the terrain grid, in meters. Will scale/redistribute vegetations, players, etc.",
		},
		"terrain/max_steepness": {
			"default": 1.0,
			"type": TYPE_FLOAT,
			"info": "The maximum steepness of the terrain use 1.0 for 45 degrees (+ noise)",
		},
		"terrain/vertex_count": {
			"default": 1000 * (100 if OS.has_feature("pc") else 1),
			"type": TYPE_INT,
			"info": "The number of vertices to use when generating the terrain (can affect performance and initial load time).",
		},
		"terrain/cell_border": {
			"default": 0.01,
			"type": TYPE_FLOAT,
			"info": "How wide to draw the border of the cells, in percentage of the cell side.",
		},
		"ocean/vertex_count": {
			"default": 1000 * (100 if OS.has_feature("pc") else 1),
			"type": TYPE_INT,
			"info": "The number of vertices to use when generating the ocean, a value > 0 enables waves."
		},
	}


# ========== ALL SETTINGS ACCESSORS ==========
static func common_seed() -> int: return _s_val("common/seed")


static func game_path() -> String: return _s_val("game/path")


static func game_reader() -> GameReader:
	if _game_reader == null:
		_game_reader = GameReader.open(_s_val("game/path"))
	return _game_reader



static func terrain_cell_side() -> float: return _s_val("terrain/cell_side")

static func terrain_max_steepness() -> float: return _s_val("terrain/max_steepness")

static func terrain_vertex_count() -> int: return _s_val("terrain/vertex_count")

static func terrain_cell_border() -> float: return _s_val("terrain/cell_border")

static func ocean_vertex_count() -> int: return _s_val("ocean/vertex_count")
