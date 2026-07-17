## P1-04 敌人生成器烟雾检查。
##
## 启动真实主场景，验证屏幕外环带生成、1 秒间隔、数量上限，
## 以及玩家离树后停止生成。测试不修改共享 EnemySpawnSettings。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const EXPECTED_INTERVAL_SECONDS := 1.0
const EXPECTED_MAX_ENEMIES := 30
const POSITION_TOLERANCE := 5.0

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	_expect(main_scene != null, "无法加载主场景。")
	if main_scene == null:
		quit(1)
		return

	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var game_session: GameSession = main_node.get_node_or_null("GameSession") as GameSession
	_expect(game_session != null, "主场景缺少 GameSession。")
	if game_session == null:
		quit(1)
		return

	var spawner: EnemySpawner = game_session.enemy_spawner
	var settings: EnemySpawnSettings = game_session.enemy_spawn_settings
	_expect(spawner != null, "GameSession 缺少 EnemySpawner。")
	_expect(settings != null, "GameSession 缺少 EnemySpawnSettings。")
	if spawner == null or settings == null:
		quit(1)
		return
	_expect(is_equal_approx(settings.spawn_interval_seconds, EXPECTED_INTERVAL_SECONDS), "生成间隔不是 1 秒。")
	_expect(settings.max_alive_enemies == EXPECTED_MAX_ENEMIES, "最大敌人数配置不正确。")

	spawner.stop()
	for child: Node in game_session.enemies.get_children():
		child.queue_free()
	await process_frame

	var ring_enemy: EnemyActor = spawner.spawn_once()
	_expect(is_instance_valid(ring_enemy), "EnemySpawner 未生成环带敌人。")
	if is_instance_valid(ring_enemy):
		var spawn_position: Vector2 = ring_enemy.global_position
		var distance_to_player: float = spawn_position.distance_to(game_session.player.global_position)
		var viewport_size: Vector2 = game_session.player.get_viewport_rect().size / game_session.player.camera.zoom
		var visible_rect := Rect2(
			game_session.player.camera.get_screen_center_position() - viewport_size * 0.5,
			viewport_size
		).grow(settings.offscreen_margin)
		var usable_arena: Rect2 = game_session.arena.get_bounds().grow(-48.0)
		_expect(not visible_rect.has_point(spawn_position), "敌人生成在摄像机可见区域内。")
		_expect(usable_arena.has_point(spawn_position), "敌人生成在场地边界外。")
		_expect(
			distance_to_player + POSITION_TOLERANCE >= settings.min_spawn_distance
				and distance_to_player - POSITION_TOLERANCE <= settings.max_spawn_distance,
			"敌人生成位置不在配置的环带内。"
		)

	for child: Node in game_session.enemies.get_children():
		child.queue_free()
	await process_frame
	spawner.initialize(settings, game_session.player, game_session.enemies, game_session.arena.get_bounds())
	var initial_count: int = spawner.get_enemy_count()
	await create_timer(2.2).timeout
	var timed_count: int = spawner.get_enemy_count()
	_expect(initial_count == 1, "EnemySpawner 初始化时未立即生成首个敌人。")
	_expect(timed_count >= 3 and timed_count <= 4, "EnemySpawner 未按约 1 秒间隔持续生成。")

	spawner.stop()
	for index: int in range(EXPECTED_MAX_ENEMIES + 5):
		spawner.spawn_enemy(
			settings.enemy_definition,
			Vector2(-1100.0 + float(index) * 8.0, -600.0)
		)
	_expect(spawner.get_enemy_count() == EXPECTED_MAX_ENEMIES, "EnemySpawner 未将敌人数限制在配置上限。")
	_expect(
		spawner.spawn_enemy(settings.enemy_definition, Vector2(-900.0, -500.0)) == null,
		"达到最大敌人数后仍可继续生成。"
	)

	spawner.initialize(settings, game_session.player, game_session.enemies, game_session.arena.get_bounds())
	game_session.player.queue_free()
	await process_frame
	_expect(spawner.spawn_timer.is_stopped(), "玩家离开场景树后 EnemySpawner 未停止。")

	if not _failed:
		print("Enemy spawner smoke test passed: ring, interval, cap, and shutdown are valid.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
