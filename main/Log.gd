@tool

class_name SLog
extends "res://addons/LogDuck/LogDuck.gd"

# HACK that is also valid in the editor, for @tool!
class SLogImpl:  # Basic, no customization for in-editor logging!
	extends "res://addons/LogDuck/LogDuck.gd"
	func stack_frame(index : int = 3) -> Dictionary:
		return super.stack_frame(index + 1)
static func sd(msg):
	if Engine.is_editor_hint():
		var s := SLogImpl.new()
		s.d(msg)
		s.queue_free()
	else:
		Log.d(msg)
static func sw(msg):
	if Engine.is_editor_hint():
		var s := SLogImpl.new()
		s.w(msg)
		s.queue_free()
	else:
		Log.w(msg)
static func se(msg):
	if Engine.is_editor_hint():
		var s := SLogImpl.new()
		s.e(msg)
		s.queue_free()
	else:
		Log.e(msg)

# Customization when not running in the editor
func output_messages(
	level,
	msg_plain,
	msg_rich,
	full_stack_rich,
	stack_frame_rich,
	full_stack_plain,
	stack_frame_plain
):
	if OS.has_feature("web"): # Does not support rich messages
		msg_rich = msg_plain
		full_stack_rich = full_stack_plain
		stack_frame_rich = stack_frame_plain
	super.output_messages(level, msg_plain, msg_rich, full_stack_rich, stack_frame_rich, full_stack_plain, stack_frame_plain)
	if not Engine.is_editor_hint():
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			output_limbo(msg_rich)
		else:
			output_limbo.bind(msg_rich).call_deferred()

func output_limbo(msg_rich: String):
	# After printing to the text console as usual, also print to the embedded graphical console (F2)
	LimboConsole.debug(msg_rich)
	# XXX: Avoid too much text on the console lagging the app
	var cur_text := LimboConsole._output.text
	while cur_text.length() > 10 * 1024:
		var delete_to := cur_text.find("\n")
		if delete_to == -1:
			Log.w("Too much output in one line?!")
		else:
			cur_text = cur_text.substr(delete_to + 1)
	LimboConsole._output.text = cur_text
	
