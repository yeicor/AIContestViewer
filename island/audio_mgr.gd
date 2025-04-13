extends Node3D

@onready var bg_music = $BackgroundMusic
@onready var podium_music = $PodiumMusic
@onready var lightning_effects = $LightningEffects
@onready var music_volume = Settings.audio_music_volume() * Settings.audio_master_volume()
@onready var effects_volume = Settings.audio_effects_volume() * Settings.audio_master_volume()

func _ready() -> void:
	bg_music.volume_linear = 0.0
	podium_music.volume_linear = 0.0
	# For lightning, speed up so that it takes as long as a single turn
	lightning_effects.volume_linear = effects_volume
	lightning_effects.pitch_scale = lightning_effects.stream.get_length() / Settings.common_turn_secs()
	if not SignalBus.game_state.is_connected(_on_game_state):
		SignalBus.game_state.connect(_on_game_state)

func _on_game_state(_state: GameState, turn: int, phase: int):
	var music_fade_time := Settings.common_end_round_secs() / 4
	if turn == 0 and phase == SignalBus.GAME_STATE_PHASE_ANIMATE:
		var tween := create_tween()
		tween.tween_callback(func(): bg_music.stream_paused = false)
		tween.tween_property(bg_music, "volume_linear", music_volume, music_fade_time)
	
	if phase == SignalBus.GAME_STATE_PHASE_END_ROUND:
		var tween := create_tween()
		tween.tween_property(bg_music, "volume_linear", 0.0, music_fade_time)
		podium_music.volume_linear = 0.0
		podium_music.stream_paused = false
		tween.parallel().tween_property(podium_music, "volume_linear", music_volume, music_fade_time)
		tween.tween_callback(func(): bg_music.stream_paused = true)
		tween.tween_interval(Settings.common_end_round_secs() - music_fade_time * 2)
		tween.tween_property(podium_music, "volume_linear", 0.0, music_fade_time)
		tween.tween_callback(func(): podium_music.stream_paused = true)


func _on_players_attack() -> void:
	lightning_effects.play()
