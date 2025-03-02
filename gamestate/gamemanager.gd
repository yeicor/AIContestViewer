class_name GameManager

### How many listeners are blocking the game manager, or -1 when stopped
static var _running_pauses := -1
static var _running_mutex := Mutex.new()
static var game_manager_thread := Thread.new()

static var stopped: bool:
	get(): return _running_pauses < 0
	set(x): _running_pauses = -1 if (x) else 0
static var runnable: bool:
	get(): return _running_pauses == 0
static var paused: bool:
	get(): return _running_pauses > 0

## Starts the game manager thread to read and publish game states
static func start(game_paths: PackedStringArray) -> void:
	_running_mutex.lock()
	if not stopped:
		Log.e("Game manager thread already running!")
		return
	stopped = false
	_running_mutex.unlock()
	Log.d("Starting game manager thread...")
	assert(OS.has_feature("threads")) # Enable thread support for web!
	game_manager_thread.start(_thread.bind(game_paths))

static func _pause(p: bool):
	_running_mutex.lock()
	if not stopped:
		_running_pauses += 1 if (p) else -1
	else:
		Log.e("Game manager thread already stopped! Can't pause/resume.")
	if stopped:
		Log.e("Resumed too many times, ignoring it...")
		stopped = false
	_running_mutex.unlock()


## Pauses the emission of events until resume is called for each pause call
static func pause(): _pause(true)
## Resumes the emission of events (waits for all pauses to clear)
static func resume(): _pause(false)

static func stop() -> void:
	Log.d("Locking running mutex to stop")
	_running_mutex.lock()
	if _running_pauses < 0:
		Log.e("Game manager thread not running!")
		return
	Log.d("Stopping game manager thread...")
	_running_pauses = -1
	_running_mutex.unlock()
	# Removed to avoid deadlock, and it doesn't really matter as there is only one game manager
	#Log.d("Waiting for the game manager thread to finish.")
	#game_manager_thread.wait_to_finish()


static func _thread(game_paths: PackedStringArray):
	var should_continue := true
	var end_sem := Semaphore.new()
	end_sem.post()
	for game_path in game_paths:
		var reader := GameReader.open(game_path)
		var turn := 0
		var old_state: GameState = null
		while should_continue:
			# Read game state asynchronously (complete round -- ignore intermediate states)
			var state := reader.parse_next_round()
			end_sem.wait() # Wait for the previous main call to end
			if old_state != null: old_state.free_recursive() # This state won't be used anymore
			# Publish game state via a global signal.
			old_state = state
			_emit_and_wait_phases_main_thread.bind(old_state, turn, end_sem).call_deferred()
			should_continue = await _wait_unpaused_secs(0, true) # Never awaits thanks to sleep
			turn += 1
		if not should_continue:
			break
	end_sem.queue_free()

static func _emit_and_wait_phases_main_thread(state: GameState, turn: int, end_sem: Semaphore):
	# Interested nodes can connect to this signal to receive game states.
	var prev_phase_time := Time.get_ticks_msec()
	if is_instance_valid(SignalBus):
		SignalBus.game_state.emit(state, turn, SignalBusStatic.GAME_STATE_PHASE_INIT)
	if await _wait_unpaused_secs(0, false):
		var phase_delta_time := Time.get_ticks_msec() - prev_phase_time
		if phase_delta_time > 20:
			Log.d("Publishing state for turn", turn, "phase", SignalBusStatic.GAME_STATE_PHASE_INIT, "took too long:", phase_delta_time, "ms")
		prev_phase_time = Time.get_ticks_msec()
		if is_instance_valid(SignalBus):
			SignalBus.game_state.emit(state, turn, SignalBusStatic.GAME_STATE_PHASE_ANIMATE)
		if await _wait_unpaused_secs(int(Settings.common_turn_secs() * 1000), false):
			phase_delta_time = Time.get_ticks_msec() - prev_phase_time
			if phase_delta_time > int(Settings.common_turn_secs() * 1500):
				Log.d("Publishing state for turn", turn, "phase", SignalBusStatic.GAME_STATE_PHASE_ANIMATE, "took too long:", phase_delta_time, "ms")
			prev_phase_time = Time.get_ticks_msec()
			if is_instance_valid(SignalBus):
				SignalBus.game_state.emit(state, turn, SignalBusStatic.GAME_STATE_PHASE_END)
			await _wait_unpaused_secs(0, false)
			phase_delta_time = Time.get_ticks_msec() - prev_phase_time
			if phase_delta_time > 20:
				Log.d("Publishing state for turn", turn, "phase", SignalBusStatic.GAME_STATE_PHASE_END, "took too long:", phase_delta_time, "ms")
			prev_phase_time = Time.get_ticks_msec()
	end_sem.post()
	

static var _sleep_ms := 100
static var _sleep_sec := float(_sleep_ms) / 1000.0
## This may actually wait for slighly longer, but will always pause until resumed
static func _wait_unpaused_secs(remaining_wait_time: int, blocking_ok: bool) -> bool:
	var waiting_time_counts: bool
	var was_stopped = false
	while remaining_wait_time >= 0: # == 0 to detect pauses
		var _loop_start_time = Time.get_ticks_msec()
		
		if not blocking_ok:
			while not _running_mutex.try_lock():
				await SignalBus.get_tree().create_timer(_sleep_sec / 4).timeout
		else: # Blocking is not ok
			_running_mutex.lock() 
		if stopped:
			was_stopped = true
			_running_mutex.unlock()
			break
		waiting_time_counts = runnable
		_running_mutex.unlock()
		
		if remaining_wait_time == 0 and waiting_time_counts: # Only one unpaused iteration
			remaining_wait_time -= 1
		else:
			var will_sleep_for_ms := maxi(mini(_sleep_ms, remaining_wait_time - (Time.get_ticks_msec() - _loop_start_time)), 10)
			if blocking_ok:
				OS.delay_msec(will_sleep_for_ms)
			else:
				await SignalBus.get_tree().create_timer(float(will_sleep_for_ms) / float(1000)).timeout
			if waiting_time_counts:
				remaining_wait_time -= Time.get_ticks_msec() - _loop_start_time
			
	return not was_stopped
	
