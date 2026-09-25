## T24：头盔、手套与科技分支专项回归。
##
## 覆盖基础头盔防御、手套冷却/射程、逐项精确断言、科技单件每秒经验与宝石倍率、
## 三件各自生效、质变门槛、与盔甲其它分支互斥，以及重新初始化清理。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const HELMET_PATH := "res://data/armor/armor_helmet.tres"
const GLOVES_PATH := "res://data/armor/armor_gloves.tres"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"
const HELMET_BASE_UP_PATH := "res://data/upgrades/helmet_base_up.tres"
const GLOVES_BASE_UP_PATH := "res://data/upgrades/gloves_base_up.tres"
const ARMOR_BASE_UP_PATH := "res://data/upgrades/armor_basic_up.tres"
const ARMOR_TECH_PATH := "res://data/upgrades/armor_tech.tres"
const HELMET_TECH_PATH := "res://data/upgrades/helmet_tech.tres"
const GLOVES_TECH_PATH := "res://data/upgrades/gloves_tech.tres"
const THORN_PATH := "res://data/upgrades/armor_thorns.tres"
const GEM_SCENE_PATH := "res://scenes/pickups/experience_gem.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_base_helmet_and_gloves()
	await _test_tech_single_piece()
	await _test_tech_three_pieces_and_gem()
	await _test_tech_gate_and_exclusion()
	await _test_reinitialize_resets()
	if not _failed:
		print("Helmet/gloves/tech smoke test passed: stats, tech xp, gem multiplier and cleanup are valid.")
	quit(1 if _failed else 0)


## 基础头盔防御与手套冷却/射程逐项精确。
func _test_base_helmet_and_gloves() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_armor(player, HELMET_PATH)
	_acquire_armor(player, GLOVES_PATH)
	_expect(is_equal_approx(player.get_defense(), 3.0), "头盔 2 + 手套 1 应共 3 点防御。")

	var controller: WeaponController = _find_controller(player, &"starter_weapon")
	_expect(
		is_equal_approx(controller.get_effective_cooldown_seconds(), 0.9),
		"手套后起始武器冷却应为 1.0×0.9。"
	)
	_expect(
		is_equal_approx(controller.get_effective_target_range(), 990.0),
		"手套后索敌射程应为 900×1.1。"
	)

	var helmet_up: UpgradeDefinition = load(HELMET_BASE_UP_PATH) as UpgradeDefinition
	for _index: int in range(helmet_up.max_stacks):
		player.apply_upgrade(helmet_up)
	var gloves_up: UpgradeDefinition = load(GLOVES_BASE_UP_PATH) as UpgradeDefinition
	for _index: int in range(gloves_up.max_stacks):
		player.apply_upgrade(gloves_up)
	_expect(is_equal_approx(player.get_defense(), 9.0), "满级后防御应为 (2+4)+(1+2)=9。")
	_expect(
		is_equal_approx(player.get_bonus_cooldown_multiplier(), 0.82),
		"满级手套冷却倍率应为 1-0.18=0.82。"
	)
	_expect(
		is_equal_approx(player.get_bonus_range_multiplier(), 1.18),
		"满级手套射程倍率应为 1.18。"
	)
	await _free_node(main_node)


## 单件科技只提供自身每秒经验与宝石倍率。
func _test_tech_single_piece() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_armor(player, HELMET_PATH)
	_max_base(player, &"armor_helmet", HELMET_BASE_UP_PATH)
	_expect(player.apply_upgrade(load(HELMET_TECH_PATH) as UpgradeDefinition), "应能选择科技头盔。")
	_expect(
		is_equal_approx(player.get_tech_experience_per_second(), 2.0),
		"科技头盔每秒经验应为 2。"
	)
	_expect(
		is_equal_approx(player.get_experience_gain_multiplier(), 1.15),
		"科技头盔宝石倍率应为 1.15。"
	)
	var before: int = player.get_current_experience()
	player.advance_tech_time(1.0)
	_expect(player.get_current_experience() == before + 2, "1 秒应获得 2 点经验。")
	await _free_node(main_node)


## 三件科技汇总每秒经验与宝石倍率，宝石经验经统一入口结算一次。
func _test_tech_three_pieces_and_gem() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_armor(player, ARMOR_PATH)
	_acquire_armor(player, HELMET_PATH)
	_acquire_armor(player, GLOVES_PATH)
	_max_base(player, &"armor_basic", ARMOR_BASE_UP_PATH)
	_max_base(player, &"armor_helmet", HELMET_BASE_UP_PATH)
	_max_base(player, &"armor_gloves", GLOVES_BASE_UP_PATH)
	_expect(player.apply_upgrade(load(ARMOR_TECH_PATH) as UpgradeDefinition), "应能选择科技战甲。")
	_expect(player.apply_upgrade(load(HELMET_TECH_PATH) as UpgradeDefinition), "应能选择科技头盔。")
	_expect(player.apply_upgrade(load(GLOVES_TECH_PATH) as UpgradeDefinition), "应能选择科技手套。")

	_expect(
		is_equal_approx(player.get_tech_experience_per_second(), 7.0),
		"三件科技每秒经验应为 3+2+2=7。"
	)
	var expected_gem: float = 1.25 * 1.15 * 1.15
	_expect(
		is_equal_approx(player.get_experience_gain_multiplier(), expected_gem),
		"三件科技宝石倍率应为 1.25×1.15×1.15。"
	)
	var before: int = player.get_current_experience()
	player.advance_tech_time(2.0)
	_expect(player.get_current_experience() == before + 14, "2 秒应获得 14 点经验。")

	var gem: ExperienceGem = (load(GEM_SCENE_PATH) as PackedScene).instantiate()
	session.pickups.add_child(gem)
	gem.initialize(10)
	var before_gem: int = player.get_current_experience()
	_expect(gem.collect(player), "宝石应被拾取。")
	var expected_gain: int = roundi(10.0 * expected_gem)
	_expect(
		player.get_current_experience() == before_gem + expected_gain,
		"宝石经验应按倍率结算为 %d。" % expected_gain
	)
	_expect(not gem.collect(player), "同一颗宝石不应重复结算。")
	await _free_node(main_node)


## 未满级不能选科技；盔甲科技与其它盔甲分支互斥。
func _test_tech_gate_and_exclusion() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_armor(player, ARMOR_PATH)
	var armor_tech: UpgradeDefinition = load(ARMOR_TECH_PATH) as UpgradeDefinition
	_expect(not player.apply_upgrade(armor_tech), "未满级不应能选择科技战甲。")
	_max_base(player, &"armor_basic", ARMOR_BASE_UP_PATH)
	_expect(player.apply_upgrade(armor_tech), "满级后应能选择科技战甲。")
	_expect(
		not session.upgrade_system.can_offer(load(THORN_PATH) as UpgradeDefinition),
		"已选科技战甲后不应再出现反伤刺甲。"
	)
	await _free_node(main_node)


func _test_reinitialize_resets() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_armor(player, GLOVES_PATH)
	_acquire_armor(player, HELMET_PATH)
	_max_base(player, &"armor_helmet", HELMET_BASE_UP_PATH)
	player.apply_upgrade(load(HELMET_TECH_PATH) as UpgradeDefinition)
	player.initialize(player.definition)
	_expect(is_equal_approx(player.get_bonus_cooldown_multiplier(), 1.0), "重新初始化应清空手套冷却。")
	_expect(is_equal_approx(player.get_bonus_range_multiplier(), 1.0), "重新初始化应清空手套射程。")
	_expect(is_equal_approx(player.get_tech_experience_per_second(), 0.0), "重新初始化应清空科技经验。")
	await _free_node(main_node)


func _acquire_armor(player: PlayerActor, path: String) -> void:
	_expect(player.try_acquire_armor(load(path) as ArmorDefinition), "应能装备 %s。" % path)


func _max_base(player: PlayerActor, equipment_id: StringName, upgrade_path: String) -> void:
	var upgrade: UpgradeDefinition = load(upgrade_path) as UpgradeDefinition
	for _index: int in range(upgrade.max_stacks):
		_expect(player.apply_upgrade(upgrade), "基础强化应成功：%s。" % equipment_id)


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	return player


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


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
