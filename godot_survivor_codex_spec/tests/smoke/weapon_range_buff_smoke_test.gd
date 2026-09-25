## T09：全武器索敌射程 Buff 的语义、边界与晚获取继承专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const RANGE_UP_PATH := "res://data/upgrades/weapon_range_up.tres"
const BASIC_PROJECTILE_PATH := "res://data/projectiles/basic_projectile.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_range_semantics()
	await _test_late_acquisition_and_restart()
	if not _failed:
		print("Weapon range buff smoke test passed: semantics, boundaries, inheritance and restart are valid.")
	quit(1 if _failed else 0)


func _test_range_semantics() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var starter: WeaponDefinition = catalog.get_weapon(&"starter_weapon")
	var projectile: ProjectileDefinition = load(BASIC_PROJECTILE_PATH) as ProjectileDefinition
	var reach_before: float = projectile.speed * projectile.lifetime_seconds
	var target_range_before: float = starter.target_range

	var controller: WeaponController = _find_controller(player, &"starter_weapon")
	_expect(controller != null, "未找到起始武器控制器。")
	if controller == null:
		await _free_node(main_node)
		return
	_expect(is_equal_approx(controller.get_effective_target_range(), 900.0), "初始有效射程应为 min(1000,900)=900。")

	# 角色上限较小：目标 5000 仍受角色 1000 限制，再乘倍率。
	var long_weapon: WeaponDefinition = _make_weapon(&"test_long", 5000.0)
	# 武器上限较小：目标 300 由武器自身限制，再乘倍率。
	var short_weapon: WeaponDefinition = _make_weapon(&"test_short", 300.0)
	player.configure_equipment([&"starter_weapon", &"test_long", &"test_short"])
	_expect(player.try_acquire_weapon(long_weapon), "应能获取长射程临时武器。")
	_expect(player.try_acquire_weapon(short_weapon), "应能获取短射程临时武器。")

	var range_up: UpgradeDefinition = load(RANGE_UP_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(range_up), "全武器射程升级应成功。")
	_expect(is_equal_approx(player.get_weapon_range_multiplier(), 1.1), "射程倍率应为 1.1。")
	_expect(is_equal_approx(controller.get_effective_target_range(), 990.0), "起始武器射程应变为 900×1.1。")
	_expect(
		is_equal_approx(_find_controller(player, &"test_long").get_effective_target_range(), 1100.0),
		"角色上限分支应为 min(1000,5000)×1.1=1100。"
	)
	_expect(
		is_equal_approx(_find_controller(player, &"test_short").get_effective_target_range(), 330.0),
		"武器上限分支应为 min(1000,300)×1.1=330。"
	)

	# 弹体实际可达距离由弹速×寿命决定，不随索敌倍率变化。
	var reach_after: float = projectile.speed * projectile.lifetime_seconds
	_expect(is_equal_approx(reach_after, reach_before), "弹体实际可达距离被误改。")
	_expect(not is_equal_approx(reach_after, controller.get_effective_target_range()), "索敌射程与弹体可达距离被混用。")
	_expect(is_equal_approx(starter.target_range, target_range_before), "共享武器射程被回写。")

	await _free_node(main_node)


func _test_late_acquisition_and_restart() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var range_up: UpgradeDefinition = load(RANGE_UP_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(range_up), "射程升级应成功。")
	var leaf: WeaponDefinition = catalog.get_weapon(&"leaf")
	player.configure_equipment([&"starter_weapon", &"leaf"])
	_expect(player.try_acquire_weapon(leaf), "应能晚获取飞叶刃。")
	var leaf_controller: WeaponController = _find_controller(player, &"leaf")
	_expect(leaf_controller != null, "未找到飞叶刃控制器。")
	if leaf_controller != null:
		_expect(
			is_equal_approx(leaf_controller.get_effective_target_range(), 850.0 * 1.1),
			"晚获取武器未继承全武器射程倍率。"
		)

	session.restart_run()
	await process_frame
	await process_frame
	var reloaded: Node = current_scene
	if reloaded == null:
		reloaded = root.get_child(root.get_child_count() - 1)
	var new_session: GameSession = reloaded.get_node("GameSession") as GameSession
	_expect(new_session != null and new_session.player != null, "重开未创建新单局。")
	if new_session != null and new_session.player != null:
		new_session.enemy_spawner.stop()
		_expect(is_equal_approx(new_session.player.get_weapon_range_multiplier(), 1.0), "重开残留射程倍率。")


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _make_weapon(id: StringName, target_range: float) -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.id = id
	weapon.display_name = String(id)
	weapon.target_range = target_range
	weapon.projectile_definition = load(BASIC_PROJECTILE_PATH) as ProjectileDefinition
	return weapon


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
