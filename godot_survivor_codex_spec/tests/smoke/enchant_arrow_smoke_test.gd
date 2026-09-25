## T20：附魔箭与法杖分支联动专项回归。
##
## 覆盖候选资格（需持弓且法杖已质变对应分支）、四分支效果映射、弓分支互斥与共享 Resource。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const STAFF_PATH := "res://data/weapons/staff.tres"
const BOW_MULTISHOT_PATH := "res://data/upgrades/bow_multishot.tres"
const BOW_VOLLEY_PATH := "res://data/upgrades/bow_volley.tres"
const STAFF_EXPLOSION_PATH := "res://data/upgrades/staff_explosion.tres"
const STAFF_FLAME_PATH := "res://data/upgrades/staff_flame.tres"
const STAFF_ICE_PATH := "res://data/upgrades/staff_ice.tres"
const STAFF_MIGHT_PATH := "res://data/upgrades/staff_might.tres"
const ENCHANT_EXPLOSION_PATH := "res://data/upgrades/enchant_explosion.tres"
const ENCHANT_FLAME_PATH := "res://data/upgrades/enchant_flame.tres"
const ENCHANT_ICE_PATH := "res://data/upgrades/enchant_ice.tres"
const ENCHANT_POWER_PATH := "res://data/upgrades/enchant_power.tres"
const ARROW_PATH := "res://data/projectiles/arrow_projectile.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_candidate_eligibility()
	await _test_explosion_mapping_and_exclusion()
	await _test_flame_mapping()
	await _test_ice_mapping()
	await _test_power_mapping()
	if not _failed:
		print("Enchant arrow smoke test passed: eligibility, four mappings and exclusion are valid.")
	quit(1 if _failed else 0)


## 无弓、无杖、杖未质变时都不应出现；杖质变后只出现对应元素。
func _test_candidate_eligibility() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var explosion: UpgradeDefinition = load(ENCHANT_EXPLOSION_PATH) as UpgradeDefinition
	var flame: UpgradeDefinition = load(ENCHANT_FLAME_PATH) as UpgradeDefinition
	_expect(not session.upgrade_system.can_offer(explosion), "无弓时不应出现附魔箭。")

	_acquire_bow(player)
	_max_bow_base(player)
	_expect(not session.upgrade_system.can_offer(explosion), "无杖时不应出现附魔箭。")

	_acquire_staff(player)
	_expect(not session.upgrade_system.can_offer(explosion), "法杖未质变时不应出现附魔箭。")

	_max_staff_base(player)
	player.apply_upgrade(load(STAFF_EXPLOSION_PATH) as UpgradeDefinition)
	_expect(session.upgrade_system.can_offer(explosion), "爆炸法杖应解锁爆炸附魔箭。")
	_expect(not session.upgrade_system.can_offer(flame), "火焰附魔箭不应在爆炸法杖下出现。")
	await _free_node(main_node)


## 爆炸附魔箭切换弹体并带爆炸；选择后与多重/万箭及另一附魔互斥。
func _test_explosion_mapping_and_exclusion() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var bow_controller: WeaponController = _setup_ascended_bow(player, STAFF_EXPLOSION_PATH)
	var explosion: UpgradeDefinition = load(ENCHANT_EXPLOSION_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(explosion), "应能选择爆炸附魔箭。")
	_expect(
		bow_controller.get_effective_projectile_definition().id == &"arrow_explosion"
		and bow_controller.get_effective_projectile_definition().explosion != null,
		"爆炸附魔箭应切换弹体并带爆炸档案。"
	)
	_expect(
		not session.upgrade_system.can_offer(load(BOW_MULTISHOT_PATH) as UpgradeDefinition),
		"附魔箭应与多重射击互斥。"
	)
	_expect(
		not session.upgrade_system.can_offer(load(BOW_VOLLEY_PATH) as UpgradeDefinition),
		"附魔箭应与万箭齐发互斥。"
	)
	_expect(
		not session.upgrade_system.can_offer(load(ENCHANT_FLAME_PATH) as UpgradeDefinition),
		"选定附魔箭后不应再出现其它附魔箭。"
	)
	await _free_node(main_node)


func _test_flame_mapping() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var bow_controller: WeaponController = _setup_ascended_bow(player, STAFF_FLAME_PATH)
	_expect(player.apply_upgrade(load(ENCHANT_FLAME_PATH) as UpgradeDefinition), "应能选择火焰附魔箭。")
	var arrow: ProjectileDefinition = bow_controller.get_effective_projectile_definition()
	_expect(arrow.id == &"arrow_flame", "火焰附魔箭应切换为火焰箭。")
	_expect(arrow.damage_over_time != null and arrow.ground_area != null, "火焰箭应带 DoT 与火坑。")
	await _free_node(main_node)


func _test_ice_mapping() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var bow_controller: WeaponController = _setup_ascended_bow(player, STAFF_ICE_PATH)
	_expect(player.apply_upgrade(load(ENCHANT_ICE_PATH) as UpgradeDefinition), "应能选择寒冰附魔箭。")
	var arrow: ProjectileDefinition = bow_controller.get_effective_projectile_definition()
	_expect(arrow.id == &"arrow_ice", "寒冰附魔箭应切换为寒冰箭。")
	_expect(arrow.on_hit_slow != null and arrow.on_hit_freeze != null, "寒冰箭应带减速与冻结。")
	await _free_node(main_node)


func _test_power_mapping() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var bow_controller: WeaponController = _setup_ascended_bow(player, STAFF_MIGHT_PATH)
	_expect(player.apply_upgrade(load(ENCHANT_POWER_PATH) as UpgradeDefinition), "应能选择威能附魔箭。")
	_expect(
		bow_controller.get_effective_projectile_definition().id == &"arrow_power",
		"威能附魔箭应切换为威能箭。"
	)
	_expect(
		is_equal_approx(bow_controller.get_runtime_damage_multiplier(), 1.3),
		"威能附魔应提高长弓伤害 30%。"
	)
	_expect(
		is_equal_approx(bow_controller.get_effective_cooldown_seconds(), 1.2 * 0.85),
		"威能附魔应使长弓冷却 ×0.85。"
	)
	_expect(
		is_equal_approx(bow_controller.get_effective_target_range(), 1200.0),
		"威能附魔应使长弓射程 ×1.2。"
	)
	var arrow_resource: ProjectileDefinition = load(ARROW_PATH) as ProjectileDefinition
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	_expect(arrow_resource.explosion == null, "共享普通箭不应被写入附魔效果。")
	_expect(bow.projectile_definition.id == &"arrow_projectile", "共享长弓弹体不应被回写。")
	await _free_node(main_node)


func _setup_ascended_bow(player: PlayerActor, staff_branch_path: String) -> WeaponController:
	_acquire_bow(player)
	_max_bow_base(player)
	_acquire_staff(player)
	_max_staff_base(player)
	_expect(
		player.apply_upgrade(load(staff_branch_path) as UpgradeDefinition),
		"法杖应能选择目标质变。"
	)
	return _find_controller(player, &"bow")


func _acquire_bow(player: PlayerActor) -> void:
	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	_expect(player.try_acquire_weapon(bow), "应能获取长弓。")


func _acquire_staff(player: PlayerActor) -> void:
	_expect(player.add_weapon(load(STAFF_PATH) as WeaponDefinition), "应能装备蓄力法杖。")


func _max_staff_base(player: PlayerActor) -> void:
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")


func _max_bow_base(player: PlayerActor) -> void:
	for _index: int in range(4):
		player.add_equipment_base_level(&"bow")


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)
	return player


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	return main_node


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
