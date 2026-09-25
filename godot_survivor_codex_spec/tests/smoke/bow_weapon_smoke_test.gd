## T12：基础弓箭数据、获取、攻击与重开专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://tests/fixtures/legacy_main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const ACQUIRE_BOW_PATH := "res://data/upgrades/acquire_bow.tres"
const BOW_BASE_PATH := "res://data/upgrades/bow_base.tres"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_bow_flow()
	if not _failed:
		print("Bow weapon smoke test passed: acquisition, base upgrade, firing and restart are valid.")
	quit(1 if _failed else 0)


func _test_bow_flow() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var bow: WeaponDefinition = catalog.get_weapon(&"bow")
	_expect(bow != null, "目录缺少长弓。")
	if bow == null:
		await _free_node(main_node)
		return
	_expect(is_equal_approx(bow.cooldown_seconds, 1.2), "长弓冷却应为 1.2。")
	_expect(bow.projectile_definition != null and bow.projectile_definition.id == &"arrow_projectile", "长弓应使用箭矢弹体。")

	var upgrade_system := UpgradeSystem.new()
	upgrade_system.initialize(player)
	var acquire_card: UpgradeDefinition = load(ACQUIRE_BOW_PATH) as UpgradeDefinition
	var base_card: UpgradeDefinition = load(BOW_BASE_PATH) as UpgradeDefinition
	_expect(upgrade_system.can_offer(acquire_card), "未持有时长弓获取卡应可出。")
	_expect(not upgrade_system.can_offer(base_card), "未持有时长弓基础升级不应可出。")
	_expect(player.apply_upgrade(acquire_card), "应能获取长弓。")
	_expect(player.has_weapon(&"bow"), "获取后应持长弓。")
	_expect(player.get_equipped_count() == 2, "长弓应占一格。")
	_expect(not upgrade_system.can_offer(acquire_card), "已持有后获取卡不应再出。")
	_expect(upgrade_system.can_offer(base_card), "持有后长弓基础升级应可出。")

	var controller: WeaponController = _find_controller(player, &"bow")
	_expect(controller != null, "未找到长弓控制器。")
	if controller == null:
		upgrade_system.free()
		await _free_node(main_node)
		return
	_expect(is_equal_approx(controller.get_effective_target_range(), 1000.0), "长弓有效射程应为 min(1000,1000)。")

	for _index: int in range(base_card.max_stacks):
		player.apply_upgrade(base_card)
	_expect(controller.get_runtime_damage_multiplier() > 1.0, "长弓基础升级未提高伤害。")
	_expect(not upgrade_system.can_offer(base_card), "满级后基础升级不应再出。")

	# 实际发射一支箭。
	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(200.0, 0.0))
	_expect(enemy != null, "未能生成测试敌人。")
	if enemy != null:
		controller.reset_runtime_state()
		var before: int = session.projectiles.get_child_count()
		_expect(controller.request_fire(enemy), "长弓应能发射。")
		_expect(session.projectiles.get_child_count() > before, "发射后未生成箭矢。")
		var spawned: ProjectileBase = null
		for child: Node in session.projectiles.get_children():
			if child is ProjectileBase:
				spawned = child as ProjectileBase
				break
		_expect(spawned != null and spawned.definition.id == &"arrow_projectile", "生成的弹体不是箭矢。")

	# 与旧武器共存。
	var leaf: WeaponDefinition = load("res://data/weapons/leaf.tres") as WeaponDefinition
	player.configure_equipment([&"starter_weapon", &"bow", &"leaf"])
	_expect(player.try_acquire_weapon(leaf), "长弓应能与飞叶刃共存。")
	_expect(_find_controller(player, &"leaf") != null, "缺少飞叶刃控制器。")

	upgrade_system.free()
	await _free_node(main_node)

	# 重开清空长弓。
	var restart_main: Node = await _spawn_main()
	current_scene = restart_main
	var restart_session: GameSession = restart_main.get_node("GameSession") as GameSession
	restart_session.enemy_spawner.stop()
	restart_session.player.add_weapon(bow)
	_expect(restart_session.player.has_weapon(&"bow"), "重开前应持有长弓。")
	restart_session.restart_run()
	await process_frame
	await process_frame
	var reloaded: Node = current_scene
	if reloaded == null:
		reloaded = root.get_child(root.get_child_count() - 1)
	var new_session: GameSession = reloaded.get_node("GameSession") as GameSession
	_expect(new_session != null and new_session.player != null, "重开未创建新单局。")
	if new_session != null and new_session.player != null:
		new_session.enemy_spawner.stop()
		_expect(not new_session.player.has_weapon(&"bow"), "重开残留长弓。")


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
	definition.max_health = 200.0
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
