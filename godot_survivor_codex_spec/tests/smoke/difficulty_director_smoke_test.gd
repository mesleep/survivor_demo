## P4-01/P4-02/P4-03 计时、分段难度和两种普通敌人烟雾检查。
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
	var run: RunDefinition = session.run_definition
	_expect(run != null and is_equal_approx(run.run_duration_seconds, 600.0), "单局时长不是 10 分钟。")
	_expect(run.stages.size() == 4, "默认流程不是四个难度阶段。")
	_expect(session.hud.time_label.text == "10:00", "HUD 初始时间不是 10:00。")

	session.advance_time(59.0)
	_expect(session.difficulty_director.current_stage_index == 0, "一分钟前未保持第一阶段。")
	var stage0_interval: float = session.enemy_spawner.spawn_timer.wait_time
	session.advance_time(1.0)
	_expect(session.difficulty_director.current_stage_index == 1, "1:00 未切换第二阶段。")
	_expect(session.enemy_spawner.spawn_timer.wait_time < stage0_interval, "第二阶段生成间隔未缩短。")

	session.advance_time(90.0)
	_expect(session.difficulty_director.current_stage_index == 2, "2:30 未切换第三阶段。")
	var stage2_pool: Array[EnemyDefinition] = session.enemy_spawner.get_runtime_enemy_pool()
	_expect(_pool_has_id(stage2_pool, &"enemy_basic") and _pool_has_id(stage2_pool, &"enemy_fast"), "2:30 的生成池未同时包含基础和快速敌人。")
	_expect(session.enemy_spawner.get_runtime_batch_size() == 3, "第三阶段同批生成数量不正确。")

	var basic: EnemyDefinition = load("res://data/enemies/enemy_basic.tres") as EnemyDefinition
	var fast: EnemyDefinition = load("res://data/enemies/enemy_fast.tres") as EnemyDefinition
	_expect(basic.scene != fast.scene, "两种普通敌人未使用独立场景配置。")
	_expect(fast.max_health < basic.max_health and fast.move_speed > basic.move_speed, "快速敌人没有低生命高速度的数据差异。")
	var runtime_enemy: EnemyActor = session.enemy_spawner.spawn_enemy(fast, Vector2(300.0, 0.0), true)
	_expect(runtime_enemy != null, "无法通过相同 EnemySpawner 创建快速敌人。")
	if runtime_enemy != null:
		var stage: DifficultyStage = run.stages[2]
		_expect(is_equal_approx(runtime_enemy.health_component.maximum_health, fast.max_health * stage.health_multiplier), "敌人生命倍率未应用到实例。")
		_expect(is_equal_approx(runtime_enemy.get_effective_move_speed(), fast.move_speed * stage.move_speed_multiplier), "敌人移速倍率未应用到实例。")
		_expect(is_equal_approx(runtime_enemy.contact_hitbox.damage_amount, fast.contact_damage * stage.damage_multiplier), "敌人伤害倍率未应用到实例。")
		_expect(is_equal_approx(fast.max_health, 6.0) and is_equal_approx(fast.move_speed, 145.0), "难度倍率回写了快速敌人 Resource。")

	paused = true
	var elapsed_before_pause: float = session.elapsed_seconds
	session.advance_time(30.0)
	_expect(is_equal_approx(session.elapsed_seconds, elapsed_before_pause), "暂停时权威计时仍在推进。")
	paused = false

	if not _failed:
		print("Difficulty director smoke test passed: timer, stages, enemy pool, and runtime multipliers are valid.")
	quit(1 if _failed else 0)


func _pool_has_id(pool: Array[EnemyDefinition], id: StringName) -> bool:
	for definition: EnemyDefinition in pool:
		if definition != null and definition.id == id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
