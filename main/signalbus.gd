class_name SignalBusStatic
extends Node

## Each state update passes through three phases:
## - Init lets listeners initialize, which may drop a few frames.
## - Animate should be very cheap as all listeners will only start the animations for a fixed amount of time.
## - End just notifies that all animations should have ended by now.
## - End round is a special phase only sent when the round completes.
## - End game is a special phase only sent when the full game completes.
enum {GAME_STATE_PHASE_INIT, GAME_STATE_PHASE_ANIMATE, GAME_STATE_PHASE_END, GAME_STATE_PHASE_END_ROUND, GAME_STATE_PHASE_END_GAME}

## Signal emitted when a new game state is entered. They are emitted in the main thread to allow UI edits.
## This will be emitted at regular intervals as configured. Turn is reset to 0 for new games.
@warning_ignore("unused_signal")
signal game_state(state: GameState, turn: int, phase: int)

## Signal emitted when the terrain is loaded.
## This implies that the relevant global shader parameters are ready.
@warning_ignore("unused_signal")
signal island_global_shader_parameters_ready()
