extends "res://addons/LogDuck/LogDuck.gd"
class_name SLog

# HACK that is also valid in the editor, for @tool!
class SLogImpl:  # Basic, no customization for in-editor logging!
	extends "res://addons/LogDuck/LogDuck.gd"
	func stack_frame(index : int = 3) -> Dictionary:
		return super.stack_frame(index + 1)
static func sd(msg):
	if Engine.is_editor_hint():
		SLogImpl.new().d(msg)
	else:
		Log.d(msg)
static func sw(msg):
	if Engine.is_editor_hint():
		SLogImpl.new().w(msg)
	else:
		Log.w(msg)
static func se(msg):
	if Engine.is_editor_hint():
		SLogImpl.new().e(msg)
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
	# After printing to the text console as usual, also print to the embedded graphical console (F2)
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		LimboConsole.debug(msg_rich)
	else:
		LimboConsole.debug.bind(msg_rich).call_deferred()
	# XXX: Avoid too much text on the console lagging the app
	var cur_text := LimboConsole._output.text
	while cur_text.length() > 10 * 1024:
		var delete_to := cur_text.find("\n")
		if delete_to == -1:
			Log.w("Too much output in one line?!")
		else:
			cur_text = cur_text.substr(delete_to + 1)
	LimboConsole._output.text = cur_text
