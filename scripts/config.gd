extends Node

# Autoloaded as "Config"

var _cfg = ConfigFile.new()


func _init():
	var config_ini = _cfg.load("user://config.ini")
	if config_ini != OK:
		print("You can set custom configuration by creating a " + OS.get_user_data_dir() + "/config.ini file")


## Which game to load. It may be tcp:// for a tcp server or simply a Godot data path.
func game_path() -> String:
	return _get_env_or_config("game", "path", "res://testdata/game.jsonl.gz")


### Maximum number of rounds that the game will reach (may be inaccurate, causing UI jumps).
#func game_rounds() -> int:
#	return int(_get_env_or_config("game", "rounds", "500"))
#
#
### How many seconds to spend animation each round.
### Should be >= engine_time for smooth animations, or <= engine_time for real-time updates
#func game_round_time() -> float:
#	return float(_get_env_or_config("game", "round_time", "0.1"))


func _get_env_or_config(section: String, key: String, default: Variant = null) -> String:
	var env: String = OS.get_environment(section + "_" + key)
	if env != "":
		return env
	return _cfg.get_value(section, key, default)
