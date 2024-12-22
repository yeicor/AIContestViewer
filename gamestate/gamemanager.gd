class_name GameManager

static var _running            := false
static var _running_mutex := Mutex.new()
static var game_manager_thread := Thread.new()


## Starts the game manager thread to read and publish game states
static func start() -> void:
	_running_mutex.lock()
	if _running:
		Log.e("Game manager thread already running!")
		return
	_running = true
	_running_mutex.unlock()
	Log.d("Starting game manager thread...")
	assert(OS.has_feature("threads")) # Enable thread support for web!
	game_manager_thread.start(_thread)

## TODO: Pauses the emission of events until called again (semaphore behavior)
static func pause(_p: bool):
	pass

static func stop() -> void:
	_running_mutex.lock()
	if not _running:
		Log.e("Game manager thread not running!")
		return
	Log.d("Stopping game manager thread...")
	_running = false
	_running_mutex.unlock()
	# Wait for the game manager thread to finish
	game_manager_thread.wait_to_finish()
	Log.d("Game manager thread stopped.")


static func _thread():
	# TODO: Support multi-game setups (same or different islands). Accumulate points and reload Main!
	var reader := GameReader.open(Settings.game_path())
	var turn := 0
	while true:
		# Read game state (complete round -- ignore intermediate states)
		var state := reader.parse_next_round()
		# Publish game state via a global signal.
		# Interested nodes can connect to this signal to receive game states.
		SignalBus.game_state.emit.bind(state, turn, SignalBusStatic.GAME_STATE_PHASE_INIT).call_deferred()
		SignalBus.game_state.emit.bind(state, turn, SignalBusStatic.GAME_STATE_PHASE_ANIMATE).call_deferred()
		# Wait for the next turn to read and emit another game state
		var should_continue := _wait_next_turn_locked(Settings.common_turn_secs())
		# End animations and turn
		SignalBus.game_state.emit.bind(state, turn, SignalBusStatic.GAME_STATE_PHASE_END).call_deferred()
		turn += 1
		# Continue?
		if not should_continue:
			break

static var check_cancel_every_ms := 100
static func _wait_next_turn_locked(secs: float) -> bool:
	var start_time := Time.get_ticks_msec()
	var wait_time := int(secs * 1000)
	while Time.get_ticks_msec() - start_time < wait_time:
		OS.delay_msec(check_cancel_every_ms)
		_running_mutex.lock()
		if not _running:
			_running_mutex.unlock()
			break
		_running_mutex.unlock()
	_running_mutex.lock()
	var cont := _running
	_running_mutex.unlock()
	return cont
	
