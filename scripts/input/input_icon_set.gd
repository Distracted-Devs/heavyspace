class_name InputIconSet
extends Resource

@export_dir var controller_folder := "res://resources/input_icons/xbox/default/"
@export_dir var keyboard_folder := (
	"res://resources/input_icons/keyboard_mouse/dark/"
)
@export var buttons: Dictionary[int, String] = {
	JOY_BUTTON_A: "a_color",
	JOY_BUTTON_B: "b_color",
	JOY_BUTTON_X: "x_color",
	JOY_BUTTON_Y: "y_color",
	JOY_BUTTON_BACK: "view",
	JOY_BUTTON_START: "menu",
	JOY_BUTTON_LEFT_STICK: "left_stick_click",
	JOY_BUTTON_RIGHT_STICK: "right_stick_click",
	JOY_BUTTON_LEFT_SHOULDER: "lb",
	JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left",
	JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}
@export var left_stick := "l"
@export var right_stick := "r"
@export var left_trigger := "lt"
@export var right_trigger := "rt"


func path(icon_name: String, device: DeviceTracker.Device) -> String:
	var folder := (
		controller_folder
		if device == DeviceTracker.Device.CONTROLLER
		else keyboard_folder
	)
	return folder.path_join(icon_name + ".png")
