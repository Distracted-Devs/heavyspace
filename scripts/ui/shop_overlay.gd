class_name ShopOverlay
extends CanvasLayer

signal launched

@export_group("Components")
@export var warp_controller: WarpController
@export var run_starter: RunStarter

@export_group("Shop")
@export var reload_on_launch := true

var progression: Progression
var is_open := false
var buttons: Array[Button] = []

@onready var bank_label: Label = %BankLabel
@onready var upgrade_list: Container = %Upgrades
@onready var launch_button: Button = %LaunchButton


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	if progression == null:
		progression = RunProgress.progression


func _ready() -> void:
	visible = false
	if not Contract.require(
		warp_controller != null and run_starter != null,
		"warp_controller and run_starter must be set",
	):
		return
	for upgrade in run_starter.upgrades:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(progression.buy.bind(upgrade))
		upgrade_list.add_child(button)
		buttons.append(button)
	launch_button.pressed.connect(launch)
	warp_controller.warp_finished.connect(open)
	progression.changed.connect(_refresh)


func open() -> void:
	if not Contract.require(not is_open, "the shop must not already be open"):
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	launch_button.grab_focus()


func launch() -> void:
	if not Contract.require(is_open, "the shop must be open"):
		return
	is_open = false
	get_tree().paused = false
	launched.emit()
	if reload_on_launch:
		get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action("pause") or event.is_action("restart"):
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not is_open:
		return
	bank_label.text = "Banked mass: %.1f" % progression.bank
	var upgrades := run_starter.upgrades
	for index in buttons.size():
		var upgrade := upgrades[index]
		var level := progression.level_of(upgrade)
		var button := buttons[index]
		button.text = _button_text(upgrade, level)
		button.disabled = not progression.can_afford(upgrade)
		if button.disabled and button.has_focus():
			launch_button.grab_focus()
	Contract.invariant(
		_buttons_match(),
		"each upgrade button must be disabled exactly when unaffordable",
	)


func _button_text(upgrade: Upgrade, level: int) -> String:
	if upgrade.is_maxed(level):
		return "%s   Lv %d (x%.2f)   MAX" % [
			upgrade.display_name,
			level,
			upgrade.multiplier(level),
		]
	return "%s   Lv %d (x%.2f → x%.2f)   cost %.0f" % [
		upgrade.display_name,
		level,
		upgrade.multiplier(level),
		upgrade.multiplier(level + 1),
		upgrade.cost(level),
	]


func _buttons_match() -> bool:
	var upgrades := run_starter.upgrades
	if buttons.size() != upgrades.size():
		return false
	for index in buttons.size():
		var affordable := progression.can_afford(upgrades[index])
		if buttons[index].disabled == affordable:
			return false
	return true
