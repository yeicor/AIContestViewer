class_name RTSCamera
extends Camera3D

@export_group("Movement")
@export var move_speed := 10.0
@export var sprint_speed := 20.0

@export_group("Rotation")
@export var orbit_speed := 0.3
@export var rotation_speed := 3
@export var rotation_sprint_speed := 6
@export var default_rotation_x := -35.0
@export var rotation_clamping := Vector2(-80, -35)

@export_group("Pan")
@export var pan_speed := 0.3
@export var pan_on_screen_edge := true
## Margin in pixels from the edges of the screen before start panning
@export var screen_edge_pan_margin: int = 20 

@export_group("Zoom")
## Zoom forward and backward in the camera view (true) or move the camera up and down (false)
@export var zoom_forward_backward := true
@export var zoom_to_mouse := true
@export var zoom_speed := 0.4
@export var zoom_smoothness := 10.0 # 0.1 when not multiplied by delta, 10 when multiplied by delta
## Backward and forward zoom max forwards clamp value
@export var max_zoom_forward := 0.83
## Backward and forward zoom max backwards clamp value
@export var max_zoom_backward := 20.0
## Up and down zoom min clamp value
@export var min_zoom_height := 1.0
## Up and down zoom max clamp value
@export var max_zoom_height := 10.0

@export_group("Input Actions")
@export var move_forward_action := "move_forward"
@export var move_backward_action := "move_backward"
@export var move_left_action := "move_left"
@export var move_right_action := "move_right"
@export var rotate_left_action := "rotate_left"
@export var rotate_right_action := "rotate_right"
@export var sprint_action := "sprint"

var _is_moving := false
var _drag_start_world_position : Vector3
var _is_rotating := false
var _is_panning := false
var _movement_direction := Vector3.ZERO
# Target up and down zoom
var _target_zoom : float
# Target position for backward and forward zooming
var _target_zoom_position := Vector3.ZERO  
var _is_zooming := false
var _is_edge_panning := false


func _ready():
	rotation_degrees.x = default_rotation_x
	_target_zoom = position.y
	_target_zoom_position = position


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if not _is_moving and Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_MIDDLE):
			if _is_panning:
				var current_world_position = _custom_project_position(event.position)
				var drag_vector = _drag_start_world_position - current_world_position
				drag_vector.y = 0  # Keep movement flat on the XZ plane

				# When dragging, directly update the position instead of smoothing it to avoid a "bouncing effect"
				# which can be distracting, especially on lower FPS rates
				position += drag_vector * pan_speed

		if _is_rotating and not _is_zooming: # buggy rotation + smooth zooming for now
			var mouse_delta = event.relative

			# Instead of just rotating the camera in-place, we rotate the camera around the target position
			# to create a proper orbit effect. In order to do this, we need to remember the target position
			# and calculate the new target position based on the current zoom level
			var target_position = position + global_transform.basis.z * _target_zoom
			print("_target_zoom  ", _target_zoom)

			# Calculate Y (yaw) and X (pitch)
			var new_rotation_y = deg_to_rad(-mouse_delta.x * orbit_speed)
			var new_rotation_x = deg_to_rad(-mouse_delta.y * orbit_speed)

			# Apply the Y rotation directly (side orbiting)
			rotate_y(new_rotation_y)

			# Calculate the new X rotation and clamp it to avoid upside down camera
			var new_rotation = rotation_degrees
			new_rotation.x = clamp(rotation_degrees.x + rad_to_deg(new_rotation_x), rotation_clamping.x, rotation_clamping.y)
			rotation_degrees.x = new_rotation.x

			# Instead of just rotating the camera in-place, we rotate the camera around the target position
			# to create a proper orbit effect
			var now_target_position = position + global_transform.basis.z * _target_zoom
			var offset = now_target_position - target_position
			position += offset

	if event is InputEventMouseButton:
		if event.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			_is_rotating = event.pressed

		if event.button_index == MouseButton.MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_drag_start_world_position = _custom_project_position(event.position)
				_is_panning = true
			else:
				_is_panning = false
				
		if zoom_to_mouse and zoom_forward_backward:
			if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP or event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				if not _is_zooming:
					_target_zoom_position = position

				# Get the world position under the mouse
				var mouse_world_pos = _custom_project_position(get_viewport().get_mouse_position())		
				# Move the zoom target towards the mouse position
				var zoom_direction = (mouse_world_pos - _target_zoom_position).normalized() * zoom_speed					
				if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
					zoom_direction = -zoom_direction
					
				_target_zoom_position += zoom_direction
				_is_zooming = true
		else:
			if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
				if zoom_forward_backward:
					if not _is_zooming:
						_target_zoom_position = position
					_target_zoom_position -= global_transform.basis.z * zoom_speed
					_is_zooming = true
				else:
					_target_zoom -= zoom_speed
					_target_zoom = max(_target_zoom, min_zoom_height)

			if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				if zoom_forward_backward:
					if not _is_zooming:
						_target_zoom_position = position
					_target_zoom_position += global_transform.basis.z * zoom_speed
					_is_zooming = true
				else:
					_target_zoom += zoom_speed
					_target_zoom = min(_target_zoom, max_zoom_height)

	if not _is_panning and event is InputEventKey:
		if event.pressed or not event.pressed:
			_update_movement_direction()


func _process(delta):
	if zoom_forward_backward:
		if _is_moving or _is_panning:
			_is_zooming = false			
		if _is_zooming and position.distance_to(_target_zoom_position) <= 0.1:
			_is_zooming = false		
		if _is_zooming:
			_target_zoom_position.y = clamp(_target_zoom_position.y, max_zoom_forward, max_zoom_backward)
			position = position.lerp(_target_zoom_position, zoom_smoothness * delta)
	else:
		# Smooth zooming up and down
		position.y = lerp(position.y, _target_zoom, zoom_smoothness * delta)
	
	if _movement_direction != Vector3.ZERO:
		var speed = move_speed
		if Input.is_action_pressed(sprint_action):
			speed = sprint_speed
			
		_movement_direction.y = 0  # Keep movement flat on the XZ plane
		position += _movement_direction.normalized() * speed * delta	

	if not _is_panning:
		_handle_rotation(delta)	
		
		if not _is_moving and not _is_rotating and pan_on_screen_edge:
			_is_handle_screen_edge_panning()
			
		if _is_rotating and _is_edge_panning:
			_movement_direction = Vector3.ZERO
			_is_edge_panning = false


## Update the movement direction based on the current input
func _update_movement_direction():
	_movement_direction = Vector3.ZERO
	_is_moving = false
	
	if Input.is_action_pressed(move_forward_action):
		_is_moving = true
		_movement_direction -= global_transform.basis.z
	if Input.is_action_pressed(move_backward_action):
		_movement_direction += global_transform.basis.z
		_is_moving = true
	if Input.is_action_pressed(move_left_action):
		_movement_direction -= global_transform.basis.x
		_is_moving = true
	if Input.is_action_pressed(move_right_action):
		_movement_direction += global_transform.basis.x
		_is_moving = true


## Convert screen position to world position on the XZ plane (y=0)
func _custom_project_position(screen_position: Vector2) -> Vector3:
	var from = project_ray_origin(screen_position)
	var to = from + project_ray_normal(screen_position) * 1000
	var plane = Plane(Vector3(0, 1, 0), 0)  # XZ plane at y = 0
	var intersection = plane.intersects_segment(from, to)
	return intersection if intersection else from


## Rotate camera central axis
func _handle_rotation(delta: float) -> void:
	var _rotation_vector := Vector3.ZERO
	
	if Input.is_action_pressed(rotate_left_action):
		_rotation_vector.y = 1
	if Input.is_action_pressed(rotate_right_action):
		_rotation_vector.y = -1
		
	var speed = rotation_speed	
	if Input.is_action_pressed(sprint_action):
		speed = rotation_sprint_speed
		
	set_rotation(get_rotation() + (_rotation_vector * speed * delta))


## Pan camera when the cursor is at the edges of the screen
func _is_handle_screen_edge_panning():
	_movement_direction = Vector3.ZERO

	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_position = get_viewport().get_mouse_position()
	
	var margin_1 = mouse_position.x <= screen_edge_pan_margin or mouse_position.x >= viewport_size.x - screen_edge_pan_margin
	var margin_2 = mouse_position.y <= screen_edge_pan_margin or mouse_position.y >= viewport_size.y - screen_edge_pan_margin

	# Check if the mouse is within the edge margin
	if margin_1 or margin_2:
		_is_edge_panning = true
		
		# Calculate the direction relative to the center of the screen
		var screen_center = viewport_size / 2
		var direction_vector = (mouse_position - screen_center).normalized()

		# Move in the direction of the mouse position relative to the center
		_movement_direction += global_transform.basis.x * direction_vector.x
		_movement_direction += global_transform.basis.z * direction_vector.y
	else:
		_is_edge_panning = false

