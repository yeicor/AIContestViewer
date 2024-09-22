class_name GameManager

static var _running            := false
static var game_manager_thread := Thread.new()


## Starts the game manager thread to read and publish game states
static func start() -> void:
	if _running:
		Log.e("Game manager thread already running!")
		return
	_running = true
	Log.d("Starting game manager thread...")
	assert(OS.has_feature("threads")) # Enable thread support for web!
	game_manager_thread.start(_thread)


static func stop() -> void:
	if not _running:
		Log.e("Game manager thread not running!")
		return
	Log.d("Stopping game manager thread...")
	# Wait for the game manager thread to finish
	game_manager_thread.wait_to_finish()
	Log.d("Game manager thread stopped.")
	_running = false


static func _thread():
	var reader := GameReader.open(Settings.game_path())
	while _running:
		# Read game state (complete round -- ignore intermediate states)
		var state := reader.parse_next_round()
		# Publish game state via a global signal.
		# Interested nodes can connect to this signal to receive game states.
		SignalBus.read_game_state.emit.bind(state).call_deferred()
