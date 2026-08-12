## P2-02 索敌服务烟雾检查。
##
## 验证最近目标、范围限制、固定间隔刷新，以及死亡和离树目标的即时过滤。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _refresh_count: int = 0


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

	var service: TargetingService = game_session.targeting_service
	var spawner: EnemySpawner = game_session.enemy_spawner
	_expect(service != null, "GameSession 缺少 TargetingService。")
	_expect(spawner != null, "GameSession 缺少 EnemySpawner。")
	if service == null or spawner == null:
		quit(1)
		return

	spawner.stop()
	service.stop()
	for controller: WeaponController in game_session.player.weapon_controllers:
		controller.set_process(false)
	for child: Node in game_session.enemies.get_children():
		child.queue_free()
	await process_frame

	var definition: EnemyDefinition = game_session.enemy_spawn_settings.enemy_definition
	var near_enemy: EnemyActor = spawner.spawn_enemy(definition, Vector2(100.0, 0.0))
	var middle_enemy: EnemyActor = spawner.spawn_enemy(definition, Vector2(220.0, 0.0))
	var far_enemy: EnemyActor = spawner.spawn_enemy(definition, Vector2(520.0, 0.0))
	_expect(near_enemy != null and middle_enemy != null and far_enemy != null, "无法创建索敌验收敌人。")
	if near_enemy == null or middle_enemy == null or far_enemy == null:
		quit(1)
		return
	_stop_enemy(near_enemy)
	_stop_enemy(middle_enemy)
	_stop_enemy(far_enemy)

	service.candidates_refreshed.connect(_on_candidates_refreshed)
	service.initialize(game_session.enemies)
	_expect(service.get_candidate_count() == 3, "TargetingService 首次刷新未缓存全部有效敌人。")
	_expect(service.get_nearest_target(Vector2.ZERO, 300.0) == near_enemy, "TargetingService 未返回范围内最近敌人。")
	_expect(service.get_nearest_target(Vector2.ZERO, 50.0) == null, "TargetingService 返回了范围外目标。")
	_expect(service.get_nearest_target(Vector2.ZERO, 300.0, &"player") == null, "TargetingService 未按阵营过滤目标。")

	var new_nearest_enemy: EnemyActor = spawner.spawn_enemy(definition, Vector2(60.0, 0.0))
	_expect(new_nearest_enemy != null, "无法创建固定间隔刷新验收敌人。")
	if new_nearest_enemy == null:
		quit(1)
		return
	_stop_enemy(new_nearest_enemy)
	_expect(service.get_nearest_target(Vector2.ZERO, 300.0) == near_enemy, "TargetingService 在刷新间隔前意外遍历了新节点。")

	var refresh_count_before_wait: int = _refresh_count
	await create_timer(service.refresh_interval_seconds + 0.05).timeout
	_expect(_refresh_count > refresh_count_before_wait, "TargetingService 未按固定间隔刷新候选。")
	_expect(service.get_candidate_count() == 4, "TargetingService 定时刷新未发现新增敌人。")
	_expect(service.get_nearest_target(Vector2.ZERO, 300.0) == new_nearest_enemy, "TargetingService 定时刷新后未更新最近目标。")

	new_nearest_enemy.free_on_death = false
	new_nearest_enemy.apply_damage(DamageEvent.new(new_nearest_enemy.health_component.maximum_health, game_session.player))
	_expect(service.get_nearest_target(Vector2.ZERO, 300.0) == near_enemy, "TargetingService 返回了刷新间隔内已死亡的目标。")

	near_enemy.queue_free()
	await process_frame
	_expect(service.get_nearest_target(Vector2.ZERO, 300.0) == middle_enemy, "TargetingService 返回了已离树目标。")
	_expect(service.get_nearest_target(Vector2.ZERO, 200.0) == null, "TargetingService 的范围边界过滤不正确。")

	service.stop()
	_expect(service.get_candidate_count() == 0, "TargetingService.stop() 未清空候选引用。")
	_expect(service.refresh_timer.is_stopped(), "TargetingService.stop() 未停止刷新 Timer。")

	var temporary_parent := Node.new()
	root.add_child(temporary_parent)
	service.initialize(temporary_parent)
	temporary_parent.queue_free()
	await process_frame
	_expect(service.candidate_parent == null, "候选容器离树后 TargetingService 仍保留引用。")
	_expect(service.refresh_timer.is_stopped(), "候选容器离树后 TargetingService 仍在刷新。")
	# 等待致命伤害音效结束，保证无头测试退出前释放音频播放句柄。
	await create_timer(DamageFeedbackComponent.HIT_SOUND_DURATION_SECONDS + 0.02).timeout

	if not _failed:
		print("Targeting service smoke test passed: nearest, range, interval, and invalid filtering are valid.")
	quit(1 if _failed else 0)


func _stop_enemy(enemy: EnemyActor) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.set_physics_process(false)


func _on_candidates_refreshed(_count: int) -> void:
	_refresh_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
