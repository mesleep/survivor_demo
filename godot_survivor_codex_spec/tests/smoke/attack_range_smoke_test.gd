## 角色与武器攻击范围组合烟雾检查。
##
## 验证角色基础范围和武器射程分别形成上限，实际自动索敌使用两者较小值。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _fire_count: int = 0


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
	var controller: WeaponController = player.weapon_controllers[0]
	controller.set_process(false)
	controller.weapon_fired.connect(_on_weapon_fired)
	var shared_character: CharacterDefinition = game_session.player_definition
	var shared_weapon: WeaponDefinition = controller.definition
	_expect(is_equal_approx(shared_character.base_attack_range, 1000.0), "默认角色基础攻击范围不正确。")
	_expect(is_equal_approx(player.get_attack_range(), 1000.0), "玩家未从角色配置读取基础攻击范围。")
	_expect(is_equal_approx(controller.get_effective_target_range(), 900.0), "默认有效范围未受武器射程限制。")

	var short_range_character: CharacterDefinition = shared_character.duplicate(true) as CharacterDefinition
	short_range_character.base_attack_range = 320.0
	player.initialize(short_range_character)
	_expect(is_equal_approx(controller.get_effective_target_range(), 320.0), "角色较短时未限制武器有效范围。")
	await _expect_automatic_range(game_session, controller, 350.0, 250.0, "角色范围")

	var long_range_character: CharacterDefinition = shared_character.duplicate(true) as CharacterDefinition
	long_range_character.base_attack_range = 1000.0
	player.initialize(long_range_character)
	var short_range_weapon: WeaponDefinition = shared_weapon.duplicate(true) as WeaponDefinition
	short_range_weapon.target_range = 180.0
	controller.initialize(short_range_weapon, player, game_session.projectiles)
	controller.set_targeting_service(game_session.targeting_service)
	controller.set_process(false)
	_expect(is_equal_approx(controller.get_effective_target_range(), 180.0), "武器较短时未限制有效范围。")
	await _expect_automatic_range(game_session, controller, 200.0, 150.0, "武器射程")

	_expect(is_equal_approx(shared_character.base_attack_range, 1000.0), "范围测试回写了共享角色 Resource。")
	_expect(is_equal_approx(shared_weapon.target_range, 900.0), "范围测试回写了共享武器 Resource。")
	if not _failed:
		print("Attack range smoke test passed: character and weapon limits are combined without Resource mutation.")
	quit(1 if _failed else 0)


func _expect_automatic_range(
		game_session: GameSession,
		controller: WeaponController,
		outside_distance: float,
		inside_distance: float,
		label: String
) -> void:
	_clear_enemies(game_session)
	await process_frame
	var definition: EnemyDefinition = game_session.enemy_spawn_settings.enemy_definition
	var outside_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(
		definition,
		game_session.player.global_position + Vector2(outside_distance, 0.0)
	)
	_stop_enemy(outside_enemy)
	game_session.targeting_service.refresh_candidates()
	controller.reset_runtime_state()
	var fire_count_before: int = _fire_count
	controller.set_process(true)
	await process_frame
	controller.set_process(false)
	_expect(_fire_count == fire_count_before, "%s 外的敌人仍触发自动攻击。" % label)

	var inside_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(
		definition,
		game_session.player.global_position + Vector2(inside_distance, 0.0)
	)
	_stop_enemy(inside_enemy)
	game_session.targeting_service.refresh_candidates()
	controller.reset_runtime_state()
	controller.set_process(true)
	await process_frame
	controller.set_process(false)
	_expect(_fire_count == fire_count_before + 1, "%s 内的敌人未触发自动攻击。" % label)


func _clear_enemies(game_session: GameSession) -> void:
	for child: Node in game_session.enemies.get_children():
		child.queue_free()


func _stop_enemy(enemy: EnemyActor) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.velocity = Vector2.ZERO
	enemy.set_physics_process(false)


func _on_weapon_fired(_weapon_id: StringName) -> void:
	_fire_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
