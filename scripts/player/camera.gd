extends Camera3D

@export var target: Node3D # drag the Ship node here in the inspector
@export var distance := 8.0
@export var min_distance := 2.0
@export var max_distance := 40.0
@export var zoom_step := 1.0
@export var sensitivity := 0.005
@export var key_rotate_speed := 2.0 # radians per second when using arrow keys

var yaw := 0.0
var pitch := -0.3 # negative = camera starts above, looking down


func _ready() -> void:
	top_level = true


func _unhandled_input(event: InputEvent) -> void:
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

	var orbit := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	global_basis = orbit
	global_position = target.global_position + orbit * Vector3(0, 0, distance)


func _apply_key_rotation(delta: float) -> void:
	var horizontal := int(Input.is_physical_key_pressed(KEY_LEFT)) - int(
		Input.is_physical_key_pressed(KEY_RIGHT)
	)
	var vertical := int(Input.is_physical_key_pressed(KEY_UP)) - int(
		Input.is_physical_key_pressed(KEY_DOWN)
	)
	yaw += horizontal * key_rotate_speed * delta
	pitch = wrapf(pitch + vertical * key_rotate_speed * delta, -PI, PI)
