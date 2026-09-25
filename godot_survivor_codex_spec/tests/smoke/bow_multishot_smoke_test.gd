## T13：长弓多重射击（多轮发射）与轮次/穿透独立专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const BASE_PATH := "res://data/upgrades/bow_base.tres"
const MULTISHOT_PATH := "res://data/upgrades/bow_multishot.tres"
const ROUNDS_PATH := "res://data/upgrades/bow_multishot_rounds.tres"
const PIERCE_PATH := "res://data/upgrades/bow_multishot_pierce.tres"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_multishot_volleys()
	await _test_rounds_and_pierce_separate()
	await _test_reset_cancels_extra_volleys()
	if not _failed:
		print("Bow multishot smoke test passed: volleys, rounds, pierce and reset are valid.")
	quit(1 if _failed else 0)


func _test_multishot_volleys() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	_expect(player.try_acquire_weapon(bow), "应能获取长弓。")
	var bow_controller: WeaponController = _find_controller(player, &"bow")
	_expect(bow_controller != null, "未找到长弓控制器。")
	if bow_controller == null:
		await _free_node(main_node)
		return
	_disable_auto_fire(player)
	_enable_ascension(player, bow_controller)

	var multishot: UpgradeDefinition = load(MULTISHOT_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(multishot), "应能选择多重射击。")
	_expect(bow_controller.get_effective_volley_count() == 2, "多重射击后应为 2 轮。")

	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(600.0, 0.0))
	_expect(enemy != null, "未能生成测试敌人。")
	if enemy == null:
		await _free_node(main_node)
		return
	_expect(bow_controller.request_fire(enemy), "长弓应能发射。")
	_expect(session.projectiles.get_child_count() == 1, "请求发射后应先有 1 支箭。")
	_expect(not bow_controller.can_fire(), "发射后应立即进入冷却（冷却只计算一次）。")
	await create_timer(0.35).timeout
	_expect(session.projectiles.get_child_count() == 2, "间隔后应出现第二轮箭。")
	await _free_node(main_node)


func _test_rounds_and_pierce_separate() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	player.try_acquire_weapon(bow)
	var bow_controller: WeaponController = _find_controller(player, &"bow")
	_disable_auto_fire(player)
	_enable_ascension(player, bow_controller)
	_expect(player.apply_upgrade(load(MULTISHOT_PATH) as UpgradeDefinition), "应能选择多重射击。")

	var rounds: UpgradeDefinition = load(ROUNDS_PATH) as UpgradeDefinition
	for _index: int in range(rounds.max_stacks):
		_expect(player.apply_upgrade(rounds), "轮次升级应成功。")
	_expect(bow_controller.get_effective_volley_count() == 4, "轮次升级后应为 4 轮。")
	_expect(bow_controller.get_effective_projectile_count() == 1, "轮次升级不应改变弹数。")

	var pierce: UpgradeDefinition = load(PIERCE_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(pierce), "穿透升级应成功。")
	_expect(bow_controller.get_effective_volley_count() == 4, "穿透升级不应改变轮次。")

	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(600.0, 0.0))
	if enemy != null:
		bow_controller.request_fire(enemy)
		var arrow: ProjectileBase = _first_projectile(session)
		_expect(arrow != null and arrow.get_remaining_pierces() >= 1, "穿透升级未作用到箭矢。")
	await _free_node(main_node)


func _test_reset_cancels_extra_volleys() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	player.try_acquire_weapon(bow)
	var bow_controller: WeaponController = _find_controller(player, &"bow")
	_disable_auto_fire(player)
	_enable_ascension(player, bow_controller)
	player.apply_upgrade(load(MULTISHOT_PATH) as UpgradeDefinition)

	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(600.0, 0.0))
	if enemy != null:
		bow_controller.request_fire(enemy)
		bow_controller.reset_runtime_state()
		await create_timer(0.35).timeout
		_expect(session.projectiles.get_child_count() == 1, "重置后不应再追加轮次。")
	await _free_node(main_node)


func _enable_ascension(player: PlayerActor, controller: WeaponController) -> void:
	var base: UpgradeDefinition = load(BASE_PATH) as UpgradeDefinition
	for _index: int in range(base.max_stacks):
		player.apply_upgrade(base)
	_expect(controller != null and player.get_progress(&"bow").is_base_maxed(), "长弓应达到质变门槛。")


func _disable_auto_fire(player: PlayerActor) -> void:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)


func _first_projectile(session: GameSession) -> ProjectileBase:
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase:
			return child as ProjectileBase
	return null


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _spawn_dummy(session: GameSession, position: Vector2) -> EnemyActor:
	var definition := EnemyDefinition.new()
	definition.id = &"test_dummy"
	definition.display_name = "Dummy"
	definition.scene = load(ENEMY_SCENE_PATH) as PackedScene
	definition.max_health = 500.0
	definition.contact_damage = 0.0
	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(definition, position, true)
	if enemy != null:
		enemy.set_physics_process(false)
	return enemy


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
