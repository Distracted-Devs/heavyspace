class_name Contract

const SETTING_ENABLED := "heavy_space/contracts/enabled"
const SETTING_BREAK_ON_VIOLATION := "heavy_space/contracts/break_on_violation"
const ERROR_PREFIX := "[Contract]"

static var enabled: bool = (
	OS.is_debug_build() and ProjectSettings.get_setting(SETTING_ENABLED, true)
)
static var break_on_violation: bool = ProjectSettings.get_setting(
	SETTING_BREAK_ON_VIOLATION,
	true,
)


static func require(condition: bool, message: String) -> bool:
	return _check(condition, "Pre-condition", message)


static func ensure(condition: bool, message: String) -> bool:
	return _check(condition, "Post-condition", message)


static func invariant(condition: bool, message: String) -> bool:
	return _check(condition, "Invariant", message)


static func _check(condition: bool, kind: String, message: String) -> bool:
	if not enabled or condition:
		return true

	push_error("%s %s broken: %s" % [ERROR_PREFIX, kind, message])
	if break_on_violation and EngineDebugger.is_active():
		# The debugger stops here; step up the call stack to find the API
		# that broke its contract.
		breakpoint
	return false
