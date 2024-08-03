class_name GameReader
extends Node

## Open a server to receive real-time game data (tcp://<host>:<port>/) or a prerecorded game file.
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
var _last_round: int       = -1


## Create a game state reader from a raw stream (JSONL)
func _init(_stream_peer: StreamPeer):
	self._stream_peer = _stream_peer
	print("Game stream ready to decode!")


## Parse the complete next round state, including moves from all bots
func parse_next_round() -> GameState:
	while true:
		var state: GameState = parse_next_state()
		if state == null:
			break # EOF
		if state.round() != self._last_round:
			self._last_round = state.round()
			return state
	return null


## Parse the next state, updated after any bot makes a move in their turn (see parse_next_round)
func parse_next_state() -> GameState:
	var raw_state: Dictionary = _read_json_line()
	print("Raw state: " + JSON.stringify(raw_state))
	if raw_state == { }:
		return null # EOF
	return GameState.new(raw_state)


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
