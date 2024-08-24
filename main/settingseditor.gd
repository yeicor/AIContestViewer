@tool
extends EditorScript
class_name SettingsEditor

static func __safe_name_re() -> RegEx:
	var m_safe_name_re = RegEx.new()
	assert(m_safe_name_re.compile("[^a-zA-Z0-9_]") == OK)
	return m_safe_name_re

static var _safe_name_re := __safe_name_re()


static func setting_global_shader_name(setting_name: String) -> String:
	return "setting_" + _safe_name_re.sub(setting_name, "_")

static func __cfg() -> ConfigFile:
	# HACK: In order to ensure persistence, the project.godot file must be edited directly
	var m_cfg = ConfigFile.new()
	assert(m_cfg.load("res://project.godot") == OK)
	return m_cfg

static var _cfg = __cfg()
static func setting_global_shader_set(setting_name: String):
	var safe_name := setting_global_shader_name(setting_name)
	if _cfg.has_section_key("shader_globals", safe_name):
		RenderingServer.global_shader_parameter_set(safe_name, Settings._s_val(setting_name))


# Called when the script is executed (using File -> Run in Script Editor).
# Updates all available global shader parameters based on the current settings metadata.
func _run() -> void:
	print("[settings-editor] Clearing all previously added global shader parameters (setting_ prefix)...")
	if _cfg.has_section("shader_globals"):
		for prev_setting: String in _cfg.get_section_keys("shader_globals"):
			if prev_setting.begins_with("setting_"):
				_cfg.erase_section_key("shader_globals", prev_setting)
				
	print("[settings-editor] Adding all supported settings as global shader parameters...")
	for setting_name in Settings._all_settings_info.keys():
		var setting_info      =  Settings._all_settings_info[setting_name]
		var setting_name_safe := setting_global_shader_name(setting_name)
		var shader_type       =  null
		match(setting_info.type):
			TYPE_BOOL:
				shader_type = "bool"
			TYPE_INT:
				shader_type = "int"
			TYPE_FLOAT:
				shader_type = "float"
			TYPE_STRING:
				shader_type = null  # Strings not allowed in shaders...
			_:
				print("[ERROR] Unsupported setting type mapping to shader: ", setting_info.type)
				shader_type = null
		if shader_type != null:
			_cfg.set_value("shader_globals", setting_name_safe, {
				"type": shader_type,
				"value": Settings._s_val(setting_name)
			})
	
	assert(_cfg.save("res://project.godot") == OK)
	print("[settings-editor] Modified project.godot to include the latest shader_globals, you should reload the project now")
