extends Camera3D

@export var target: Node3D # drag the Ship node here in the inspector
@export var distance := 8.0
@export var min_distance := 2.0
@export var max_distance := 40.0
@export var zoom_step := 1.0
@export var sensitivity := 0.005
@export var key_rotate_speed := 2.0 # radians per second (arrow keys / right stick)
## Extra distance added while the player's locked-orbit boost is firing.
@export var boost_zoom_out := 6.0
## How quickly the camera eases in/out of the boost zoom.
@export var boost_zoom_speed := 3.0

@export_group("Main menu")
## Distance from the ship while the title screen is up.
@export var menu_distance := 14.0
## How far round to the ship's side the menu camera sits (0 = straight behind).
@export_range(0.0, 90.0) var menu_side_angle_deg := 35.0
## Height above the ship of the menu camera.
@export var menu_height := 2.0
## The menu camera aims this far past the ship, towards the planet and sun,
## so the ship sits off-centre and both bodies stay in frame.
@export var menu_look_ahead := 30.0
## Gentle idle sway of the menu camera (degrees, cycles per second).
@export var menu_sway_deg := 4.0
@export var menu_sway_hz := 0.08
## Seconds the camera takes to fly from the menu view to the gameplay view.
@export var menu_transition_time := 2.0

var yaw := 0.0
var pitch := -0.3 # negative = camera starts above, looking down
var follow_axes := Vector3.ZERO
var follow_weight := Vector3.ZERO
var follow_lerp_speed := 4.0
var _boost_zoom := 0.0
var _menu_time := 0.0
## 0 = menu view, 1 = gameplay view.
var _menu_blend := 0.0


func _ready() -> void:
	top_level = true


func _unhandled_input(event: InputEvent) -> void:
	if GameState.in_menu:
		return
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

	if GameState.in_menu:
		_update_menu_camera(delta)
		return

	_apply_key_rotation(delta)
	global_transform = _game_pose(delta)


## Where the camera sits during normal play (follows the ship, orbit controls).
func _game_pose(delta: float) -> Transform3D:
	follow_weight = follow_weight.lerp(follow_axes, 1.0 - exp(-follow_lerp_speed * delta))
	var follow := Basis.from_euler(target.global_basis.get_euler() * follow_weight)
	var orbit := follow * Basis.from_euler(Vector3(pitch, yaw, 0.0))

	var player := get_parent() as Player
	var boosting := player != null and player.is_orbit_boosting()
	_boost_zoom = lerpf(_boost_zoom, boost_zoom_out if boosting else 0.0,
			1.0 - exp(-boost_zoom_speed * delta))
	return Transform3D(
		orbit * ScreenShakeHandler.get_rotation_basis(),
		target.global_position + orbit * Vector3(0, 0, distance + _boost_zoom),
	)


# --- Main menu -----------------------------------------------------------------


## Title-screen view, then a smooth fly-in to the gameplay view once Play is
## pressed. Hands control over (GameState.finish_start) when it arrives.
func _update_menu_camera(delta: float) -> void:
	_menu_time += delta
	var menu := _menu_pose()
	if not GameState.is_starting():
		global_transform = menu
		return

	_menu_blend = minf(_menu_blend + delta / maxf(menu_transition_time, 0.001), 1.0)
	var game := _game_pose(delta)
	var t := smoothstep(0.0, 1.0, _menu_blend)
	var rot := menu.basis.get_rotation_quaternion().slerp(
			game.basis.orthonormalized().get_rotation_quaternion(), t)
	global_transform = Transform3D(Basis(rot), menu.origin.lerp(game.origin, t))
	if _menu_blend >= 1.0:
		GameState.finish_start()


## Looks past the ship, from a bit to its side, towards the point between the
## nearest planet and the sun so all three are on screen.
func _menu_pose() -> Transform3D:
	var ship_pos := target.global_position
	var look_dir := -target.global_basis.z
	var towards := Vector3.ZERO
	var planet := _nearest_body(ship_pos)
	if planet:
		towards += (planet.global_position - ship_pos).normalized()
	var sun := _find_sun()
	if sun:
		towards += sun.direction
	if not towards.is_zero_approx():
		look_dir = towards.normalized()

	var up := target.global_basis.y
	if absf(look_dir.dot(up)) > 0.95:
		up = target.global_basis.x
	var side := look_dir.cross(up).normalized()
	up = side.cross(look_dir).normalized()

	var sway := deg_to_rad(menu_sway_deg) * sin(_menu_time * TAU * menu_sway_hz)
	var offset_dir := (-look_dir).rotated(up, deg_to_rad(menu_side_angle_deg) + sway)
	var pos := ship_pos + offset_dir * menu_distance + up * menu_height
	var aim := ship_pos + look_dir * menu_look_ahead
	return Transform3D(Basis.looking_at(aim - pos, up), pos)


func _nearest_body(from: Vector3) -> Node3D:
	var best: Node3D
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(&"bodies"):
		var body := node as Node3D
		if body == null:
			continue
		var d := from.distance_squared_to(body.global_position)
		if d < best_dist:
			best = body
			best_dist = d
	return best


func _find_sun() -> Sun:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "Node3D", true, false):
		if node is Sun:
			return node
	return null


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
