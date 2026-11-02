extends Camera3D

@export var target: Node3D # drag the Ship node here in the inspector
@export var distance := 8.0
@export var min_distance := 2.0
@export var max_distance := 40.0
@export var zoom_step := 1.0
@export var sensitivity := 0.005

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
		pitch = clamp(pitch - event.relative.y * sensitivity, -PI / 2 + 0.01, PI / 2 - 0.01)


func _physics_process(_delta: float) -> void:
	if not target:
		return

	var orbit := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	global_basis = orbit
	global_position = target.global_position + orbit * Vector3(0, 0, distance)
