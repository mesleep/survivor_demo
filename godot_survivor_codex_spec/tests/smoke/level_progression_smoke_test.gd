## P3-01 等级、经验阈值与连续升级烟雾检查。
extends SceneTree

const PLAYER_DEFINITION_PATH := "res://data/characters/player_default.tres"

var _failed: bool = false
var _level_signal_count: int = 0
var _progress_signal_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: CharacterDefinition = load(PLAYER_DEFINITION_PATH) as CharacterDefinition
	_expect(definition != null and definition.scene != null, "无法加载默认玩家配置。")
	if definition == null or definition.scene == null:
		quit(1)
		return

	var player: PlayerActor = definition.scene.instantiate() as PlayerActor
	root.add_child(player)
	player.initialize(definition)
	player.set_physics_process(false)
	player.leveled_up.connect(_on_leveled_up)
	player.level_progress_changed.connect(_on_progress_changed)

	_expect(player.get_current_level() == 1, "玩家初始等级不是 1。")
	_expect(player.get_required_experience() == 8, "一级经验阈值不符合 5 + level * 3。")
	player.add_experience(7)
	_expect(player.get_current_level() == 1 and player.get_current_level_experience() == 7, "阈值前经验进度不正确。")

	player.add_experience(20)
	_expect(player.get_current_experience() == 27, "本局累计经验未保留。")
	_expect(player.get_current_level() == 3, "一次大量经验未连续提升两个等级。")
	_expect(player.get_current_level_experience() == 8, "连续升级后的剩余经验不正确。")
	_expect(player.get_required_experience() == 14, "三级经验阈值不正确。")
	_expect(player.get_pending_upgrade_count() == 2, "连续升级未记录两次待选择升级。")
	_expect(_level_signal_count == 2 and _progress_signal_count == 2, "等级或经验进度信号次数不正确。")
	_expect(player.consume_pending_upgrade() and player.consume_pending_upgrade(), "待升级次数无法逐次消费。")
	_expect(not player.consume_pending_upgrade(), "待升级次数被消费为负数。")

	player.initialize(definition)
	_expect(player.get_current_level() == 1 and player.get_current_experience() == 0, "重新初始化未清空等级经验。")
	_expect(player.get_pending_upgrade_count() == 0, "重新初始化未清空待升级次数。")

	if not _failed:
		print("Level progression smoke test passed: thresholds, overflow, signals, and reset are valid.")
	quit(1 if _failed else 0)


func _on_leveled_up(_new_level: int, _pending_count: int) -> void:
	_level_signal_count += 1


func _on_progress_changed(_level: int, _current: int, _required: int) -> void:
	_progress_signal_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
