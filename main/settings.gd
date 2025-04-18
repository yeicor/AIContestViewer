@tool
extends Node
class_name Settings

static var _instance: Settings       = null
const _project_settings_root: String = "ai_contest_viewer"
static var _invalid_env_regex: RegEx = _invalid_env_regex_fn()
# Internals of the loader
var _loaded: bool             = false
var _all_settings: Dictionary = {} # Keys are paths, and values are raw setting values

func _ready():
	# Print all settings if required
	if _val("settings/print", true):
		SLog.sd(" === LOADED SETTINGS ===")
		var all_keys = _all_settings_info.keys()
		all_keys.sort()
		for setting_name: String in all_keys:
			SLog.sd(setting_name + " = " + str(_val(setting_name)))
		SLog.sd(" === END OF LOADED SETTINGS ===")

func _load_parse_and_set(setting_name: String, raw: String, from: String):
	var setting = _all_settings_info[setting_name]
	var val     = _parse_string(raw, setting, setting_name)
	if _val("settings/print", true):
		print("[before-logging] (SettingsAutoloaded) [" + from + "] Custom setting: " + setting_name + " -> " + str(val))
	_all_settings[setting_name] = val


func _load_custom_settings_env() -> void:
	# Fill project config from environment variables
	if _val("settings/print", true):
		print("[before-logging] (SettingsAutoloaded) Loading setting overrides from environment variables...")
	for setting_name: String in _all_settings_info.keys():
		# Replace all invalid characters in the environment variable name regex
		var env_name: String = _invalid_env_regex.sub(setting_name, "_", true)
		if OS.has_environment(env_name):
			_load_parse_and_set(setting_name, OS.get_environment(env_name), "env")


func _load_custom_settings_web() -> void:
	# Fill project config from query parameters on web export
	if OS.has_feature("web"):
		if _val("settings/print", true):
			print("[before-logging] (SettingsAutoloaded) Loading setting overrides from query parameters...")
		for setting_name: String in _all_settings_info.keys():
			var query_name: String = _invalid_env_regex.sub(setting_name, "_", true)
			var query_value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('"+query_name+"')")
			if query_value != null:
				_load_parse_and_set(setting_name, query_value, "web")


func _load_custom_settings_ini() -> void: # Will enter first in the scene tree (but after all _init() functions)
	# Fill project config from config.ini file
	var settings_path   = _val("settings/path", true)
	var create_defaults = _val("settings/create_defaults", true)

	if _val("settings/print", true):
		print("[before-logging] (SettingsAutoloaded) Loading setting overrides from ini file (", settings_path, ")...")

	var config: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		if _val("settings/print", true):
			print("[before-logging] (SettingsAutoloaded) Loading setting overrides from " + str(settings_path))
		config.load(settings_path)

	for setting_name: String in _all_settings_info.keys():
		var section: String = setting_name.substr(0, setting_name.rfind("/"))
		var key: String     = setting_name.substr(setting_name.rfind("/") + 1)
		if config.has_section_key(section, key):
			var val_str = str(config.get_value(section, key))
			_load_parse_and_set(setting_name, val_str, "ini")

	# Save the default settings file if it doesn't exist and the user wants it
	if create_defaults and not FileAccess.file_exists(settings_path):
		print("[before-logging] (SettingsAutoloaded) Saving all settings to " + ProjectSettings.globalize_path(settings_path))
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


func _parse_string(_value: String, setting: Dictionary, setting_name: String = "unknown") -> Variant:
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
			print("[before-logging?] (SettingsAutoloaded) Unsupported type for setting " + setting_name + ": " + str(setting["type"]))
			return _value


static func _invalid_env_regex_fn() -> RegEx:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex


## Retrieves the value of a previously defined setting.
func _val(path: String, skip_check: bool = false) -> Variant:
	assert(_loaded or skip_check, "Settings must be loaded before they can be accessed.")
	return _all_settings.get(path, _all_settings_info[path]["default"])


## Supports @tool by using default values if no instance is available
static func _s_val(path: String, skip_check: bool = false) -> Variant:
	if _instance != null:
		return _instance._val(path, skip_check)
	else: # Also apply proper presets in the case of the static editor-only version.
		var preset = _apply_presets(path)
		if preset != null:
			return preset
		else:
			return _all_settings_info[path]["default"]


## Applies the preset quality to the individual settings, returning the new value (or default if not affected)
static func _apply_presets(path: String) -> Variant:
	match path:
		"terrain/vertex_count":
			return int(10000.0 * 10.0 ** preset_quality_linear(true))
		"terrain/no_textures":
			return preset_quality_linear(true) < 0
		"ocean/vertex_count":
			return int(10000.0 * 10.0 ** preset_quality_linear(true))
		"ocean/screen_and_depth":
			#if OS.is_debug_build(): return false
			return preset_quality_linear(true) > 0 and not OS.has_feature("web") # Web crashes for now
		"common/props_multiplier":
			#if OS.is_debug_build(): return 0.0 # Faster development iterations
			if preset_quality_linear(true) == -2: return 0.0 # Force disable all props on lowest
			return 10.0 ** (preset_quality_quadratic(true) * 0.25) # (0.1 -> 0.0), 0.56, 1, 1.78, 10
		"common/stochastic_textures":
			return preset_quality_linear(true) >= 2 # They really affect performance :/
		"audio/master_volume":
			@warning_ignore("incompatible_ternary")
			return 0.0 if OS.is_debug_build() else null  # Disable while editing
		_:
			return null


static func setting_global_shader_name(setting_name: String, prefix: String = "setting_") -> String:
	return prefix + _invalid_env_regex.sub(setting_name, "_", true)


static var _project_godot: ConfigFile


static func project_godot() -> ConfigFile:
	# HACK: In order to ensure persistence, the project.godot file must be edited directly
	if _project_godot == null and FileAccess.file_exists("res://project.godot"):
		_project_godot = ConfigFile.new()
		var res := _project_godot.load("res://project.godot")
		assert(res == OK)
	return _project_godot


func setting_global_shader_set(setting_name: String):
	var safe_name := setting_global_shader_name(setting_name)
	if project_godot() != null and project_godot().has_section_key("shader_globals", safe_name):
		RenderingServer.global_shader_parameter_set(safe_name, Settings._s_val(setting_name, true))


## Returns a string that can be used with a c-like preprocessor to define all current settings. Useful for shaders!
static func as_defines() -> String:
	var all_keys = _all_settings_info.keys()
	all_keys.sort()
	var defines: String = ""
	for setting_name: String in all_keys:
		var safe_name := setting_global_shader_name(setting_name, "s_")
		match _all_settings_info[setting_name]["type"]:
			TYPE_BOOL:
				defines += "#define " + safe_name + " " + str(_s_val(setting_name)).to_lower() + "\n"
			TYPE_INT:
				defines += "#define " + safe_name + " " + str(_s_val(setting_name)) + "\n"
			TYPE_FLOAT:
				defines += "#define " + safe_name + " " + str(_s_val(setting_name)) + "\n"
			TYPE_STRING:
				defines += "#define " + safe_name + " \"" + str(_s_val(setting_name)).replace("\"", "\\\"") + "\"\n"
			TYPE_VECTOR2:
				defines += "#define " + safe_name + " vec2(" + str(_s_val(setting_name).x) + ", " + str(_s_val(setting_name).y) + ")\n"
			TYPE_VECTOR3:
				defines += "#define " + safe_name + " vec3(" + str(_s_val(setting_name).x) + ", " + str(_s_val(setting_name).y) + ", " + str(_s_val(setting_name).z) + ")\n"
			TYPE_COLOR:
				defines += "#define " + safe_name + " vec4(" + str(_s_val(setting_name).r) + ", " + str(_s_val(setting_name).g) + ", " + str(_s_val(setting_name).b) + ", " + str(_s_val(setting_name).a) + ")\n"	
			-RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D:
				pass # Not supported, but no need to print anything
			_:
				print("[before-logging?] (SettingsAutoloaded) Unsupported type for setting " + setting_name + ": " + str(_all_settings_info[setting_name]["type"]))
	# Also publish the rendering_method as a define to help work around incompatibilities
	defines += "#define rendering_method \"" + RenderingServer.get_current_rendering_method() + "\"\n"
	return defines

# ========== ALL SETTINGS ==========

static var _all_settings_info: Dictionary = \
	{
		"settings/path": {
			"default": "user://settings.ini",
			"type": TYPE_STRING,
			"info": "The path to the settings file.",
		},
		"settings/create_defaults": {
			"default": false, # Harder to reset on some platforms, invoke only manually
			"type": TYPE_BOOL,
			"info": "Whether to create the default settings file if it does not exist.",
		},
		"settings/print": {
			"default": true,
			"type": TYPE_BOOL,
			"info": "Whether to print out all loaded settings, helping the user to customize them.",
		},
		"common/seed": {
			"default": 42,
			"type": TYPE_INT,
			"info": "The seed to generate the same island, camera paths, etc.",
		},
		"common/turn_secs": {
			"default": 0.25,
			"type": TYPE_FLOAT,
			"info": "The time to spend animating each turn of the game, in seconds.",
		},
		"common/start_round_secs": {
			"default": 1.5,
			"type": TYPE_FLOAT,
			"info": "The time to spend animating the starting turn of each round, in seconds.",
		},
		"common/end_round_secs": {
			"default": 7.0,
			"type": TYPE_FLOAT,
			"info": "The time to spend animating the ending turn of each round, in seconds.",
		},
		"common/end_game_turn_secs": {
			"default": -1.0,
			"type": TYPE_FLOAT,
			"info": "After the last round is complete and this timer ends, the visualizer closes. Set to a negative value to disable.",
		},
		"common/turn_max": {
			"default": -1,
			"type": TYPE_INT,
			"info": "The number of turns after which each round is force-finished. Set to -1 to disable.",
		},
		"common/start_paused": {
			"default": false,
			"type": TYPE_BOOL,
			"info": "Start the game paused. Press P, Space or click the turn indicator to unpause.",
		},
		"common/props_multiplier": {
			"default": 1.0,
			"type": TYPE_FLOAT,
			"info": "A multiplier to apply before adding decorative props (grass, trees, rocks, ships, etc.) to the scene.",
		},
		"common/stochastic_textures": {
			"default": true,
			"type": TYPE_BOOL,
			"info": "Enable to hide obvious tiling when repeating textures (terrain, ocean...), at the cost of some performance.",
		},
		"common/variable_rate_shading": {
			"default": true,
			"type": TYPE_BOOL,
			"info": "Enable to gain performance at the cost of rendering shaders at a lower resolution outside the center of the game content.",
		},
		"common/rendering_scale": {
			"default": -1.0,
			"type": TYPE_FLOAT,
			"info": "Allows to render the whole scene at a lower resolution than native and upscaling it for performance, or at a higher resolution than native and downscaling it for quality. Set it to -1.0 for dynamic changes!",
		},
		"common/rendering_scale_mode": {
			"default": "FSR",
			"type": TYPE_STRING,
			"info": "Choices: Bilinear, FSR, FSR2. Allows rendering at a lower resolution without losing too much quality.",
		},
		"game/paths": {
			"default": "res://testdata/small_round1.jsonl.gz;res://testdata/small_round2.jsonl.gz;res://testdata/small_round3.jsonl.gz",
			#"default": "res://testdata/medium.jsonl.gz",
			#"default": "res://testdata/large.gz",
			"type": TYPE_STRING,
			"info": "The ;-separated game paths to load. It may start with tcp:// for a server or it may be a Godot file path.",
		},
		"preset/quality": {
			"default": "medium" if OS.has_feature("pc") else "low" if OS.has_feature("mobile") else "lowest",
			"type": TYPE_STRING,
			"info": "The quality preset to use " + str(_preset_quality_values) + ". Overrides some settings BEFORE loading other custom overrides.",
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
			"default": 10000, # A quality preset will always override this
			"type": TYPE_INT,
			"info": "The number of vertices to use when generating the terrain (can affect performance and initial load time).",
		},
		"terrain/no_textures": {
			"default": false, # A quality preset will always override this
			"type": TYPE_BOOL,
			"info": "Whether to use textures or just simple colors to paint the terrain.",
		},
		"terrain/cell_border": {
			"default": 0.01,
			"type": TYPE_FLOAT,
			"info": "How wide to draw the border of the cells, in percentage of the cell side.",
		},
		"island/water_level_distance": {
			"default": "",
			"type": -RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,
			"info": "Internal texture representing distance to the water level for the shaders.",
		},
		"island/water_level_at": {
			"default": 0.44,
			"type": TYPE_FLOAT,
			"info": "Internal value representing the water level for the shaders (see island/water_level_distance).",
		},
		"island/water_level_step": {
			"default": 0.1,
			"type": TYPE_FLOAT,
			"info": "Internal value representing the step between water levels for the shaders (see island/water_level_distance).",
		},
		"island/heightmap": {
			"default": "",
			"type": -RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,
			"info": "Internal texture representing heightmap of the generated terrain for the shaders.",
		},
		"island/energymap": {
			"default": "",
			"type": -RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,
			"info": "Internal texture representing energy of each cell to use in shaders.",
		},
		"player/scale": {
			"default": 4.0, 
			"type": TYPE_FLOAT,
			"info": "The scale for all players and related structures."
		},
		"ocean/vertex_count": {
			"default": 10000, # A quality preset will always override this
			"type": TYPE_INT,
			"info": "The number of vertices to use when generating the ocean, a value > 0 enables waves."
		},
		"ocean/screen_and_depth": {
			"default": true, # A quality preset will always override this
			"type": TYPE_BOOL,
			"info": "Allow access to the special screen and depth textures for a better ocean (crashes on web)",
		},
		"camera/mode": {
			"default": "auto",
			"type": TYPE_STRING,
			"info": "The camera mode, which can be 'auto' or 'manual'",
		},
		"camera/auto/pitch": {
			"default": -50.0,
			"type": TYPE_FLOAT,
			"info": "The pitch angle of the camera, in degrees. 0 is horizontal and -90 is vertical.",
		},
		"camera/auto/rot_speed": {
			"default": 0.05,
			"type": TYPE_FLOAT,
			"info": "The rotation speed of the camera, in radians per second.",
		},
		"camera/auto/include_owned": {
			"default": true,
			"type": TYPE_BOOL,
			"info": "Whether the auto camera also includes owned lighthouses on the frame at all times or just players.",
		},
		"audio/master_volume": {
			"default": 1.0,
			"type": TYPE_FLOAT,
			"info": "Volume control for all game audio.",
		},
		"audio/music_volume": {
			"default": 1.0,
			"type": TYPE_FLOAT,
			"info": "Volume control for background music.",
		},
		"audio/effects_volume": {
			"default": 1.0,
			"type": TYPE_FLOAT,
			"info": "Volume control for sound effects.",
		},
	}


# INIT AFTER ALL VARIABLES ARE INITIALIZED

func _init() -> void: # This runs before any _init() of the main scene (autoloaded)
	assert(_instance == null, "Only 1 settings instance at a time!")
	_instance = self

	# HACK: Allow special env overrides before ini (like changing the settings file path or the presets)
	_load_custom_settings_web()
	_load_custom_settings_env()
	_load_custom_settings_ini()

	# Apply presets before the final pass to override some settings...
	if _val("settings/print", true):
		var preset_info := "("
		for setting_name: String in _all_settings_info.keys():
			if setting_name.begins_with("preset/"):
				preset_info += setting_name.trim_prefix("preset/")
				preset_info += ": " + _val(setting_name, true)
		preset_info += ")"
		print("[before-logging] (SettingsAutoloaded) Applying presets... " + preset_info)
	for setting_name: String in _all_settings_info.keys():
		var mod_preset = _apply_presets(setting_name)
		if mod_preset != null:
			_all_settings[setting_name] = mod_preset

	# Reload overrides after presets are applied, and giving more priority to env and web...
	_load_custom_settings_ini()
	_load_custom_settings_env()
	_load_custom_settings_web()

	# Override all global parameters as required
	if _val("settings/print", true):
		print("[before-logging] (SettingsAutoloaded) Publishing global shader parameters...")
	for setting_name: String in _all_settings_info.keys():
		setting_global_shader_set(setting_name)

	_loaded = true
	
	# Set global seed for unreachable internal randf calls (best effort!)
	seed(common_seed())

# ========== ALL SETTINGS ACCESSORS ==========
static func common_seed() -> int: return _s_val("common/seed")


static func common_turn_secs() -> float: return _s_val("common/turn_secs")
static func common_turn_secs_multiplier() -> float: return common_turn_secs() / 0.5
static func common_start_round_secs() -> float: return _s_val("common/start_round_secs")
static func common_end_round_secs() -> float: return _s_val("common/end_round_secs")
static func common_end_game_turn_secs() -> float: return _s_val("common/end_game_turn_secs")
static func common_turn_max() -> int: return _s_val("common/turn_max")


static func common_start_paused() -> bool: return _s_val("common/start_paused")


static func common_props_multiplier() -> float: return _s_val("common/props_multiplier")

static func common_variable_rate_shading() -> bool: return _s_val("common/variable_rate_shading")
static func common_rendering_scale() -> float: return _s_val("common/rendering_scale")
static func common_rendering_scale_mode() -> String: return _s_val("common/rendering_scale_mode")

static func game_paths() -> PackedStringArray: return _s_val("game/paths").split(";", false)


static var _preset_quality_values: Array = ["lowest", "low", "medium", "high", "highest"]


static func preset_quality(skip_check: bool = false) -> String:
	var preset = _s_val("preset/quality", skip_check)
	assert(_preset_quality_values.has(preset), "Invalid quality preset: " + preset)
	return preset


@warning_ignore("integer_division") static func preset_quality_linear(skip_check: bool = false) -> int: return _preset_quality_values.find(preset_quality(skip_check)) - _preset_quality_values.size() / 2


static func preset_quality_quadratic(skip_check: bool = false) -> int: return preset_quality_linear(skip_check) ** 2 * sign(preset_quality_linear(skip_check))


static func terrain_cell_side() -> float: return _s_val("terrain/cell_side")


static func terrain_cell_side_mult() -> float: return _s_val("terrain/cell_side") / _all_settings_info["terrain/cell_side"]["default"]


static func terrain_max_steepness() -> float: return _s_val("terrain/max_steepness")


static func terrain_vertex_count() -> int: return _s_val("terrain/vertex_count")


static func island_water_level_distance_set(texture: Texture2D) -> void:
	assert(_instance != null)
	_instance._all_settings["island/water_level_distance"] = texture
	RenderingServer.global_shader_parameter_set("setting_island_water_level_distance", texture)
	_island_water_level_distance_image_cache = null


static func island_water_level_distance() -> Texture2D: return _s_val("island/water_level_distance")
static var _island_water_level_distance_image_cache: Image = null
static func island_water_level_distance_image() -> Image: 
	if _island_water_level_distance_image_cache == null:
		_island_water_level_distance_image_cache = island_water_level_distance().get_image()
	return _island_water_level_distance_image_cache



static func island_water_level_at_set(value: float) -> void:
	assert(_instance != null)
	_instance._all_settings["island/water_level_at"] = value
	RenderingServer.global_shader_parameter_set("setting_island_water_level_at", value)


static func island_water_level_at() -> float: return _s_val("island/water_level_at")


static func island_water_level_step_set(value: float) -> void:
	assert(_instance != null)
	_instance._all_settings["island/water_level_step"] = value
	RenderingServer.global_shader_parameter_set("setting_island_water_level_step", value)


static func island_water_level_step() -> float: return _s_val("island/water_level_step")


static func island_heightmap_set(value: Texture2D) -> void:
	assert(_instance != null)
	_instance._all_settings["island/heightmap"] = value
	RenderingServer.global_shader_parameter_set("setting_island_heightmap", value)
	_island_heightmap_cache = null


static func island_heightmap() -> Texture2D: return _s_val("island/heightmap")
static var _island_heightmap_cache: Image = null
static func island_heightmap_image() -> Image: 
	if _island_heightmap_cache == null:
		_island_heightmap_cache = island_heightmap().get_image()
	return _island_heightmap_cache


static func island_energymap_set(value: Texture2D) -> void:
	assert(_instance != null)
	_instance._all_settings["island/energymap"] = value
	RenderingServer.global_shader_parameter_set("setting_island_energymap", value)
	_island_energymap_cache = null


static func island_energymap() -> Texture2D: return _s_val("island/energymap")
static var _island_energymap_cache: Image = null
static func island_energymap_image() -> Image: 
	if _island_energymap_cache == null:
		_island_energymap_cache = island_energymap().get_image()
	return _island_energymap_cache


static func player_scale() -> float: return _s_val("player/scale")


static func ocean_vertex_count() -> int: return _s_val("ocean/vertex_count")


static func ocean_screen_and_depth() -> bool: return _s_val("ocean/screen_and_depth")

enum {CAMERA_MODE_MANUAL, CAMERA_MODE_AUTO}

static func camera_mode() -> int: 
	if _s_val("camera/mode") == "auto":
		return CAMERA_MODE_AUTO
	else:
		return CAMERA_MODE_MANUAL

static func camera_mode_auto() -> bool: return camera_mode() == CAMERA_MODE_AUTO

static func camera_auto_pitch() -> float: return _s_val("camera/auto/pitch")

static func camera_auto_rot_speed() -> float: return _s_val("camera/auto/rot_speed")

static func camera_auto_include_owned() -> bool: return _s_val("camera/auto/include_owned")

static func audio_master_volume() -> float: return _s_val("audio/master_volume")
static func audio_music_volume() -> float: return _s_val("audio/music_volume")
static func audio_effects_volume() -> float: return _s_val("audio/effects_volume")
