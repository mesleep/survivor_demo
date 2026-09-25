## 十分钟终局与后期升级权重专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var system: UpgradeSystem = session.upgrade_system
	var base: UpgradeDefinition = load("res://data/upgrades/staff_base.tres") as UpgradeDefinition
	var generic: UpgradeDefinition = load("res://data/upgrades/damage_up.tres") as UpgradeDefinition
	var generic_other: UpgradeDefinition = load("res://data/upgrades/fire_rate_up.tres") as UpgradeDefinition
	var ascension: UpgradeDefinition = load("res://data/upgrades/staff_flame.tres") as UpgradeDefinition

	_expect(is_equal_approx(session.run_definition.run_duration_seconds, 600.0), "终局应设为十分钟。")
	_expect(session.hud.time_label.text == "10:00", "开局倒计时应显示 10:00。")
	system.upgrade_pool = [base, generic, generic_other, ascension]
	system.set_run_progress_ratio(0.49)
	_expect(is_equal_approx(system._effective_weight(base), 3.0), "前期基础卡权重不应受后期规则影响。")
	for seed_value: int in range(20):
		system.set_random_seed(seed_value)
		system.request_choices(1)
		_expect(system.get_current_choices().has(base), "前期基础成长应保底。")

	system.set_run_progress_ratio(0.5)
	_expect(is_equal_approx(system._effective_weight(base), 0.75), "后期基础卡权重未降低。")
	_expect(is_equal_approx(system._effective_weight(generic), 0.5), "后期通用卡权重未降低。")
	var late_base_draws: int = 0
	for seed_value: int in range(100):
		system.set_random_seed(seed_value)
		system.request_choices(1)
		if system.get_current_choices().has(base):
			late_base_draws += 1
	_expect(late_base_draws > 20 and late_base_draws < 90, "后期基础成长应降低频率但保留升级路径。")

	for _level: int in range(EquipmentProgress.MAX_BASE_LEVEL - 1):
		player.add_equipment_base_level(&"staff")
	_expect(is_equal_approx(system._effective_weight(ascension), 20.0), "后期质变权重未提高。")
	for seed_value: int in range(20):
		system.set_random_seed(seed_value)
		system.request_choices(3)
		_expect(system.get_current_choices().has(ascension), "后期已解锁质变必须出现在选项中。")

	session.advance_time(599.0)
	_expect(not session.boss_has_spawned, "十分钟前不应出现 Boss。")
	session.advance_time(1.0)
	_expect(session.boss_has_spawned and is_instance_valid(session.boss), "十分钟时应出现 Boss。")
	main_node.queue_free()
	await process_frame
	if not _failed:
		print("Ten-minute flow smoke test passed: timer, late weights, ascension and boss timing.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
