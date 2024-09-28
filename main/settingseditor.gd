@tool
extends EditorScript
class_name SettingsEditor

# Called when the script is executed (using File -> Run in Script Editor).
# Updates all available global shader parameters based on the current settings metadata.
func _run() -> void:
	print("[settings-editor] Clearing all previously added global shader parameters (setting_ prefix)...")
	var cfg = Settings.project_godot()
	if cfg.has_section("shader_globals"):
		for prev_setting: String in cfg.get_section_keys("shader_globals"):
			if prev_setting.begins_with("setting_"):
				cfg.erase_section_key("shader_globals", prev_setting)
				
	print("[settings-editor] Adding all supported settings as global shader parameters...")
	for setting_name in Settings._all_settings_info.keys():
		var setting_info      =  Settings._all_settings_info[setting_name]
		var setting_name_safe := Settings.setting_global_shader_name(setting_name)
		var shader_type       =  null
		match(setting_info.type):
			TYPE_BOOL:
				shader_type = "bool"
			TYPE_INT:
				shader_type = "int"
			TYPE_FLOAT:
				shader_type = "float"
			-RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D:
				shader_type = "sampler2D"
			TYPE_STRING:
				shader_type = null  # Strings not allowed in shaders...
			_:
				SLog.sd("[ERROR] Unsupported setting type mapping to shader: " + str(setting_info.type))
				shader_type = null
		if shader_type != null:
			SLog.sd("- Saving " + setting_name_safe)
			cfg.set_value("shader_globals", setting_name_safe, {
				"type": shader_type,
				"value": Settings._s_val(setting_name)
			})
	
	assert(cfg.save("res://project.godot") == OK)
	SLog.sd("[settings-editor] Modified project.godot to include the latest shader_globals, you should reload the project now")
