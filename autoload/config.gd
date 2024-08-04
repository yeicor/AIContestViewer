extends Node
class_name ConfigClass

# Autoloaded as "Config"

var _cfg = ConfigFile.new()


func _init():
	var config_ini = _cfg.load("user://config.ini")
	if config_ini != OK:
		print("You can set custom configuration by creating a " + OS.get_user_data_dir() + "/config.ini file")

## The seed with which to generate the terrain, vegetation, camera paths, podium location, etc.
func game_seed() -> int:
	return int(_get_env_or_config("common", "seed", "42"))

const DEFAULT_GAME_PATH: String = "res://testdata/game.jsonl.gz"

## Which game to load. It may be tcp:// for a tcp server or simply a Godot data path.
func game_path() -> String:
	return _get_env_or_config("game", "path", DEFAULT_GAME_PATH)

## The shared game reader to avoid duplicate reads (which are unavailable for tcp). 
var _game_reader: GameReader = null
func game_reader() -> GameReader:
	if _game_reader == null:
		_game_reader = GameReader.open(game_path())
	return _game_reader


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
