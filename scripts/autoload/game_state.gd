extends Node
## Global game flow, autoloaded as `GameState`.
##
## `in_menu` starts true when the game launches and turns false once the
## player presses Play and the camera has flown into place. It lives in an
## autoload, so reloading the scene (restart) keeps it false: the main menu
## only comes back after quitting and relaunching the game.

## Emitted once the transition is finished and the controls are live.
signal game_started

var in_menu := true
var _starting := false


## True while the camera is flying from the menu view to the game view.
func is_starting() -> bool:
	return _starting


## Called by the menu when the player presses Play.
func request_play() -> void:
	if not in_menu or _starting:
		return
	_starting = true


## Called by the camera once it has reached its gameplay position.
func finish_start() -> void:
	if not in_menu:
		return
	_starting = false
	in_menu = false
	game_started.emit()
