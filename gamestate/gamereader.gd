class_name GameReader
extends Node

## Open a server to receive real-time game data (tcp://<host>:<port>) or a prerecorded game file.
static func open(path: String) -> GameReader:
	var stream: StreamPeer
	if path.begins_with("tcp://"):
		var srv: TCPServer    = TCPServer.new()
		var host_port: String = path.split("/")[2]
		var host: String      = host_port.split(":")[0]
		var port: int         = int(host_port.split(":")[1])
		srv.listen(port, host)
		print("Listening on " + host + ":" + str(port) + " for game data")
		stream = srv.take_connection()
	else: # Buffer the whole file in memory (for now)
		var file_contents: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if FileAccess.get_open_error() != Error.OK:
			print("Failed to open game file: " + path)
			return null
		var buf: StreamPeerBuffer = StreamPeerBuffer.new()
		var is_gzip: bool         = path.ends_with(".gz")
		if is_gzip:
			buf.data_array = file_contents.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		else:
			buf.data_array = file_contents
		stream = buf
	return GameReader.new(stream)


var _stream_peer: StreamPeer
var _stream_peer_eof: bool = false


## Create a game state reader from a raw stream (JSONL)
func _init(stream_peer: StreamPeer):
	self._stream_peer = stream_peer


## Parse the complete next round state, including moves from all bots
func parse_next_round() -> GameState:
	if self.cur_state == null:
		# Figure out how many players are there in the first round
		parse_next_state()
		# First state is a new round!
		return self.cur_state
		
	var num_updates_per_round: int = cur_state.players().size() + 1 # Pre-init state
	var _expected_round: int = cur_state.round()
	if _expected_round == 0:
		num_updates_per_round += 1
	for i in range(num_updates_per_round):
		if parse_next_state() == null:
			return null  # EOF
			
		if i == num_updates_per_round - 1: # Last player action should change the expected state
			break
		
		if self.cur_state.round() != _expected_round:
			print("[gamereader] Error: Unexpected round number: " + str(cur_state.round()) + " (expected " + str(_expected_round) + ")")
	
	_expected_round+=1
	if self.cur_state.round() != _expected_round:
		print("[gamereader] Error: (2) Unexpected round number : " + str(cur_state.round()) + " (expected " + str(_expected_round) + ")")
	
	return self.cur_state

## Returns the current state
var cur_state: GameState = null


## Parse the next state, updated after any bot makes a move in their turn (see parse_next_round)


func parse_next_state() -> GameState:
	var raw_state: Dictionary = _read_json_line()
	# print("Raw state: " + JSON.stringify(raw_state))
	if raw_state == { }:
		return null # EOF
	# print("Read state round: " + str(raw_state["round"]))
	cur_state = GameState.new(raw_state)
	return cur_state


## Read a json line from the internal stream, parsing it into a dictionary
func _read_json_line() -> Dictionary:
	if self._stream_peer_eof:
		return { }
	var line: String = ""
	while true:
		var byte: int = self._stream_peer.get_8()
		if byte == -1: # EOF
			self._stream_peer_eof = true
			break
		if byte == 10:
			break
		line += String(char(byte))
	return JSON.parse_string(line)
