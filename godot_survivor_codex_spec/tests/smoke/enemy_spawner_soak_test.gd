## P1-04 敌人生成器两分钟稳定性检查。
##
## 以真实时间运行主场景 120 秒，每 30 秒检查敌人数未超过上限。
## 该测试仅提高玩家本局生命以隔离 P2 接触伤害，不修改共享 Resource。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const SAMPLE_INTERVAL_SECONDS := 30.0
const SAMPLE_COUNT := 4
const SOAK_PLAYER_HEALTH := 1000000.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		push_error("无法加载主场景。")
		quit(1)
		return

	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var game_session: GameSession = main_node.get_node_or_null("GameSession") as GameSession
	if game_session == null:
		push_error("主场景缺少 GameSession。")
		quit(1)
		return
	game_session.player.health_component.initialize(SOAK_PLAYER_HEALTH)
	# P1-04 专项固定验证基础生成器配置，阶段四动态难度由独立测试覆盖。
	game_session.is_run_active = false
	for controller: WeaponController in game_session.player.weapon_controllers:
		controller.set_process(false)

	var maximum: int = game_session.enemy_spawn_settings.max_alive_enemies
	for sample: int in range(1, SAMPLE_COUNT + 1):
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		var enemy_count: int = game_session.enemy_spawner.get_enemy_count()
		if enemy_count > maximum:
			push_error("敌人数超过上限：%d > %d" % [enemy_count, maximum])
			quit(1)
			return
		print("Spawner soak progress: %d seconds, %d enemies." % [sample * 30, enemy_count])

	if game_session.enemy_spawner.get_enemy_count() != maximum:
		push_error("两分钟后敌人数未稳定在配置上限。")
		quit(1)
		return

	print("Enemy spawner soak test passed: 120 seconds without cap overflow or blocking errors.")
	quit(0)
