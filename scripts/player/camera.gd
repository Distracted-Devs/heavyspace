extends Camera3D

@export var target: Node3D # drag the Ship node here in the inspector
@export var distance := 8.0
@export var min_distance := 2.0
@export var max_distance := 40.0
@export var zoom_step := 1.0
@export var sensitivity := 0.005
@export var key_rotate_speed := 2.0 # radians per second (arrow keys / right stick)

var yaw := 0.0
var pitch := -0.3 # negative = camera starts above, looking down
var follow_axes := Vector3.ZERO
var follow_weight := Vector3.ZERO
var follow_lerp_speed := 4.0


func _ready() -> void:
	top_level = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				follow_axes.x = 1.0 - follow_axes.x
			KEY_2:
				follow_axes.y = 1.0 - follow_axes.y
			KEY_3:
				follow_axes.z = 1.0 - follow_axes.z

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed \
						else Input.MOUSE_MODE_VISIBLE
			MOUSE_BUTTON_WHEEL_UP:
				distance = max(min_distance, distance - zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = min(max_distance, distance + zoom_step)

	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		var new_pitch: float = pitch - event.relative.y * sensitivity

		if absf(pitch) < PI / 2:
			new_pitch = clamp(new_pitch, -PI / 2 + 0.01, PI / 2 - 0.01)
		pitch = wrapf(new_pitch, -PI, PI)


func _physics_process(delta: float) -> void:
	if not target:
		return

	_apply_key_rotation(delta)

	follow_weight = follow_weight.lerp(follow_axes, 1.0 - exp(-follow_lerp_speed * delta))
	var follow := Basis.from_euler(target.global_basis.get_euler() * follow_weight)
	var orbit := follow * Basis.from_euler(Vector3(pitch, yaw, 0.0))
	global_basis = orbit
	global_position = target.global_position + orbit * Vector3(0, 0, distance)


func _apply_key_rotation(delta: float) -> void:
	# Arrow keys or the controller's right stick (analog).
	var horizontal := clampf(
		int(Input.is_physical_key_pressed(KEY_LEFT)) - int(Input.is_physical_key_pressed(KEY_RIGHT))
		+ Input.get_axis(&"camera_right", &"camera_left"),
		-1.0, 1.0,
	)
	var vertical := clampf(
		int(Input.is_physical_key_pressed(KEY_UP)) - int(Input.is_physical_key_pressed(KEY_DOWN))
		+ Input.get_axis(&"camera_down", &"camera_up"),
		-1.0, 1.0,
	)
	yaw += horizontal * key_rotate_speed * delta
	pitch = wrapf(pitch + vertical * key_rotate_speed * delta, -PI, PI)
