extends Node3D

func _ready() -> void:
	# Start the game manager thread
	GameManager.start.call_deferred()
	# Use the global signal Event Bus to connect to some events
	SignalBus.game_state.connect(func(): $"LoadingLabel".queue_free(), CONNECT_ONE_SHOT)
