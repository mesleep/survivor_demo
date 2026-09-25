## T14：长弓万箭齐发（每轮弹数）与弓分支互斥专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const BASE_PATH := "res://data/upgrades/bow_base.tres"
const MULTISHOT_PATH := "res://data/upgrades/bow_multishot.tres"
const VOLLEY_PATH := "res://data/upgrades/bow_volley.tres"
const VOLLEY_COUNT_PATH := "res://data/upgrades/bow_volley_count.tres"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_volley_branch()
	await _test_branch_mutex()
	if not _failed:
		print("Bow volley smoke test passed: per-round count, spread and branch mutex are valid.")
	quit(1 if _failed else 0)


func _test_volley_branch() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	player.try_acquire_weapon(bow)
	var controller: WeaponController = _find_controller(player, &"bow")
	_disable_auto_fire(player)
	_max_base(player, controller)

	var volley: UpgradeDefinition = load(VOLLEY_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(volley), "应能选择万箭齐发。")
	_expect(controller.get_effective_projectile_count() == 2, "万箭齐发后每轮应为 2 支。")
	_expect(controller.get_effective_volley_count() == 1, "万箭齐发不应改变轮数。")

	var count_up: UpgradeDefinition = load(VOLLEY_COUNT_PATH) as UpgradeDefinition
	for _index: int in range(count_up.max_stacks):
		player.apply_upgrade(count_up)
	_expect(controller.get_effective_projectile_count() == 4, "箭雨满级后每轮应为 4 支。")
	_expect(controller.get_effective_volley_count() == 1, "箭雨不应改变轮数。")

	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(600.0, 0.0))
	if enemy != null:
		_expect(controller.request_fire(enemy), "长弓应能发射。")
		var directions: Array[Vector2] = []
		for child: Node in session.projectiles.get_children():
			if child is ProjectileBase:
				directions.append((child as ProjectileBase).direction)
		_expect(directions.size() == 4, "一次万箭应生成 4 支箭。")
		var unique: Dictionary[Vector2, bool] = {}
		for direction: Vector2 in directions:
			unique[direction] = true
		_expect(unique.size() == directions.size(), "多支箭方向重叠。")
	await _free_node(main_node)


func _test_branch_mutex() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	player.try_acquire_weapon(bow)
	var controller: WeaponController = _find_controller(player, &"bow")
	_disable_auto_fire(player)
	_max_base(player, controller)

	var upgrade_system := UpgradeSystem.new()
	upgrade_system.initialize(player)
	player.apply_upgrade(load(MULTISHOT_PATH) as UpgradeDefinition)
	_expect(not upgrade_system.can_offer(load(VOLLEY_PATH) as UpgradeDefinition), "已选多重后万箭不应可出。")
	upgrade_system.free()
	await _free_node(main_node)


func _max_base(player: PlayerActor, controller: WeaponController) -> void:
	var base: UpgradeDefinition = load(BASE_PATH) as UpgradeDefinition
	for _index: int in range(base.max_stacks):
		player.apply_upgrade(base)
	_expect(controller != null and player.get_progress(&"bow").is_base_maxed(), "长弓应达到质变门槛。")


func _disable_auto_fire(player: PlayerActor) -> void:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)


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
