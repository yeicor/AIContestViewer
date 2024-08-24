extends Node

## Signal emitted when a new round is parsed from the external game data source.
## Note that states may be read much faster than the game progresses (due to animations, etc).
@warning_ignore("unused_signal")
signal read_game_state(state: GameState)

## Signal emitted when a new game state is entered. Contrary to read_game_state,
## this signal is emitted when all scene nodes should animate towards the new state.
@warning_ignore("unused_signal")
signal game_state(state: GameState)

## Signal emitted when the terrain is loaded. This implies that the relevant global shader parameters are ready.
@warning_ignore("unused_signal")
signal island_global_shader_parameters_ready()
