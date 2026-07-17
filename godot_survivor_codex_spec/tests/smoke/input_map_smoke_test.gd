## P1-01 输入映射烟雾检查。
##
## 直接从 ProjectSettings 加载 InputMap，验证每个移动动作同时具有
## WASD 物理键和对应方向键。失败时以非零状态码退出。
extends SceneTree

const PHYSICAL_KEYS: Dictionary[StringName, int] = {
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
}

const DIRECTION_KEYS: Dictionary[StringName, int] = {
	&"move_up": KEY_UP,
	&"move_down": KEY_DOWN,
	&"move_left": KEY_LEFT,
	&"move_right": KEY_RIGHT,
}


func _initialize() -> void:
	var failed: bool = false

	for action: StringName in PHYSICAL_KEYS:
		if not InputMap.has_action(action):
			push_error("缺少输入动作：%s" % action)
			failed = true
			continue

		var has_physical_key: bool = false
		var has_direction_key: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is not InputEventKey:
				continue

			var key_event: InputEventKey = event as InputEventKey
			has_physical_key = has_physical_key or key_event.physical_keycode == PHYSICAL_KEYS[action]
			has_direction_key = has_direction_key or key_event.keycode == DIRECTION_KEYS[action]

		if not has_physical_key or not has_direction_key:
			push_error("输入动作绑定不完整：%s" % action)
			failed = true

	if not failed:
		print("InputMap smoke test passed: WASD and arrow keys are configured.")

	quit(1 if failed else 0)
