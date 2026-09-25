## P2-03 自动武器集成烟雾检查。
##
## 验证默认武器自动请求最近敌人、射程和无目标过滤、约一秒冷却及多控制器组合。
extends SceneTree

const MAIN_SCENE_PATH := "res://tests/fixtures/legacy_main.tscn"

var _failed: bool = false
var _fire_request_count: int = 0
var _last_target: Node2D


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
	game_session.enemy_spawner.stop()

	var player: PlayerActor = game_session.player
	_expect(player.weapon_controllers.size() == 1, "默认玩家未创建一个 WeaponController。")
	if player.weapon_controllers.size() != 1:
		quit(1)
		return
	var controller: WeaponController = player.weapon_controllers[0]
	_expect(controller.definition == player.definition.starting_weapons[0], "WeaponController 未使用角色起始武器配置。")
	_expect(controller.owner_actor == player, "WeaponController 未获得玩家引用。")
	_expect(controller.projectile_parent == game_session.projectiles, "WeaponController 未获得子弹容器引用。")
	_expect(controller.targeting_service == game_session.targeting_service, "WeaponController 未获得索敌服务引用。")
	controller.set_process(false)
	controller.reset_runtime_state()
	controller.fire_requested.connect(_on_fire_requested)

	_clear_enemies(game_session)
	await process_frame
	game_session.targeting_service.refresh_candidates()
	controller.set_process(true)
	await process_frame
	controller.set_process(false)
	_expect(_fire_request_count == 0, "无敌人时自动武器仍产生发射请求。")

	var definition: EnemyDefinition = game_session.enemy_spawn_settings.enemy_definition
	var far_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(definition, Vector2(1000.0, 0.0))
	_expect(far_enemy != null, "无法创建射程验收敌人。")
	if far_enemy == null:
		quit(1)
		return
	_stop_enemy(far_enemy)
	game_session.targeting_service.refresh_candidates()
	controller.reset_runtime_state()
	controller.set_process(true)
	await process_frame
	controller.set_process(false)
	_expect(_fire_request_count == 0, "超出武器射程的敌人仍触发发射。")

	var middle_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(definition, Vector2(240.0, 0.0))
	var near_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(definition, Vector2(120.0, 0.0))
	_expect(middle_enemy != null and near_enemy != null, "无法创建最近目标验收敌人。")
	if middle_enemy == null or near_enemy == null:
		quit(1)
		return
	_stop_enemy(middle_enemy)
	_stop_enemy(near_enemy)
	game_session.targeting_service.refresh_candidates()
	controller.reset_runtime_state()
	controller.set_process(true)
	await process_frame
	_expect(_fire_request_count == 1, "默认武器未自动产生一次发射请求。")
	_expect(_last_target == near_enemy, "默认武器未请求攻击最近敌人。")

	await create_timer(0.4).timeout
	_expect(_fire_request_count == 1, "默认武器在一秒冷却内重复请求发射。")
	await create_timer(0.7).timeout
	controller.set_process(false)
	_expect(_fire_request_count == 2, "默认武器未在约一秒后再次请求发射。")
	var shared_definition: WeaponDefinition = player.definition.starting_weapons[0]
	var duplicate_definitions: Array[WeaponDefinition] = [shared_definition, shared_definition]
	player.configure_weapons(duplicate_definitions, game_session.projectiles, game_session.targeting_service)
	_expect(player.weapon_controllers.size() == 2, "PlayerActor 不支持组合多个 WeaponController。")
	if player.weapon_controllers.size() == 2:
		for weapon_controller: WeaponController in player.weapon_controllers:
			weapon_controller.set_process(false)
		player.weapon_controllers[0].apply_runtime_modifier(WeaponRuntimeModifier.new(0.5, 1, 1.0))
		_expect(player.weapon_controllers[0].get_effective_projectile_count() == 2, "首个控制器运行时状态未生效。")
		_expect(player.weapon_controllers[1].get_effective_projectile_count() == 1, "多个控制器错误共享了运行时状态。")
	_expect(shared_definition.projectile_count == 1, "多控制器运行时状态回写了共享 Resource。")

	if not _failed:
		print("Automatic weapon smoke test passed: nearest, range, cooldown, and multi-controller state are valid.")
	quit(1 if _failed else 0)


func _clear_enemies(game_session: GameSession) -> void:
	for child: Node in game_session.enemies.get_children():
		child.queue_free()


func _stop_enemy(enemy: EnemyActor) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.set_physics_process(false)


func _on_fire_requested(
		_definition: WeaponDefinition,
		_owner_actor: ActorBase,
		target: Node2D,
		_projectile_parent: Node,
		_projectile_count: int,
		_damage_multiplier: float
) -> void:
	_fire_request_count += 1
	_last_target = target


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
