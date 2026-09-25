## T07：星光魔杖样板质变（基础→质变→专属）与晚获取继承的专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const BASE_PATH := "res://data/upgrades/star_wand_base.tres"
const SCATTER_PATH := "res://data/upgrades/star_wand_scatter.tres"
const FOCUS_PATH := "res://data/upgrades/star_wand_focus.tres"
const SCATTER_UP_PATH := "res://data/upgrades/star_wand_scatter_up.tres"
const FOCUS_UP_PATH := "res://data/upgrades/star_wand_focus_up.tres"
const DAMAGE_UP_PATH := "res://data/upgrades/damage_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_scatter_chain()
	await _test_focus_mutex()
	await _test_late_acquisition_inheritance()
	await _test_restart_zeroes()
	if not _failed:
		print("Weapon ascension smoke test passed: base, branch, exclusive and inheritance are valid.")
	quit(1 if _failed else 0)


func _test_scatter_chain() -> void:
	var main_node: Node = await _spawn_main()
	var player: PlayerActor = (main_node.get_node("GameSession") as GameSession).player
	(main_node.get_node("GameSession") as GameSession).enemy_spawner.stop()
	var upgrade_system: UpgradeSystem = _make_system(player)
	var controller: WeaponController = _find_controller(player, &"starter_weapon")
	var base: UpgradeDefinition = load(BASE_PATH) as UpgradeDefinition
	var scatter: UpgradeDefinition = load(SCATTER_PATH) as UpgradeDefinition
	var focus: UpgradeDefinition = load(FOCUS_PATH) as UpgradeDefinition
	var scatter_up: UpgradeDefinition = load(SCATTER_UP_PATH) as UpgradeDefinition
	var focus_up: UpgradeDefinition = load(FOCUS_UP_PATH) as UpgradeDefinition

	_expect(upgrade_system.can_offer(base), "未满级时基础升级应可出。")
	_expect(not upgrade_system.can_offer(scatter), "未满级时质变不应可出。")
	var damage_before: float = controller.get_runtime_damage_multiplier()
	for _index: int in range(base.max_stacks):
		_expect(player.apply_upgrade(base), "基础升级应成功。")
	_expect(player.get_progress(&"starter_weapon").base_level == EquipmentProgress.MAX_BASE_LEVEL, "基础等级未满。")
	_expect(controller.get_runtime_damage_multiplier() > damage_before, "基础升级未提高伤害倍率。")
	_expect(not upgrade_system.can_offer(base), "满级后基础升级不应再出。")

	_expect(upgrade_system.can_offer(scatter), "满级后星屑散射应可出。")
	_expect(upgrade_system.can_offer(focus), "满级后星辉聚焦应可出。")
	var count_before: int = controller.get_effective_projectile_count()
	_expect(player.apply_upgrade(scatter), "应能选择星屑散射。")
	_expect(player.get_progress(&"starter_weapon").branch_id == &"scatter", "分支未记录为 scatter。")
	_expect(controller.get_effective_projectile_count() == count_before + 1, "质变未增加弹数。")

	_expect(not upgrade_system.can_offer(focus), "已选分支后其它质变不应可出。")
	_expect(upgrade_system.can_offer(scatter_up), "本分支专属升级应可出。")
	_expect(not upgrade_system.can_offer(focus_up), "其它分支专属升级不应可出。")
	for _index: int in range(scatter_up.max_stacks):
		_expect(player.apply_upgrade(scatter_up), "星屑迸发应成功。")
	_expect(not upgrade_system.can_offer(scatter_up), "专属升级满级后不应再出。")
	_expect(controller.get_effective_projectile_count() == count_before + 1 + scatter_up.max_stacks, "专属弹数未叠加。")
	upgrade_system.free()
	await _free_node(main_node)


func _test_focus_mutex() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = session.player
	session.enemy_spawner.stop()
	var upgrade_system: UpgradeSystem = _make_system(player)
	var controller: WeaponController = _find_controller(player, &"starter_weapon")
	var base: UpgradeDefinition = load(BASE_PATH) as UpgradeDefinition
	var scatter: UpgradeDefinition = load(SCATTER_PATH) as UpgradeDefinition
	var focus: UpgradeDefinition = load(FOCUS_PATH) as UpgradeDefinition
	var focus_up: UpgradeDefinition = load(FOCUS_UP_PATH) as UpgradeDefinition

	for _index: int in range(base.max_stacks):
		player.apply_upgrade(base)
	var damage_before_focus: float = controller.get_runtime_damage_multiplier()
	_expect(player.apply_upgrade(focus), "应能选择星辉聚焦。")
	_expect(controller.get_runtime_damage_multiplier() > damage_before_focus, "星辉聚焦未提高伤害。")
	_expect(not upgrade_system.can_offer(scatter), "已选聚焦后星屑散射不应可出。")
	_expect(upgrade_system.can_offer(focus_up), "聚焦专属升级应可出。")
	upgrade_system.free()
	await _free_node(main_node)


func _test_late_acquisition_inheritance() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = session.player
	session.enemy_spawner.stop()
	var damage_up: UpgradeDefinition = load(DAMAGE_UP_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(damage_up), "通用伤害升级应成功。")
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var leaf: WeaponDefinition = catalog.get_weapon(&"leaf")
	player.configure_equipment([&"starter_weapon", &"leaf"])
	_expect(player.try_acquire_weapon(leaf), "应能获取飞叶刃。")
	var leaf_controller: WeaponController = _find_controller(player, &"leaf")
	_expect(leaf_controller != null, "未找到飞叶刃控制器。")
	if leaf_controller != null:
		_expect(leaf_controller.get_runtime_damage_multiplier() > 1.0, "晚获取武器未继承通用伤害升级。")
	await _free_node(main_node)


func _test_restart_zeroes() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var base: UpgradeDefinition = load(BASE_PATH) as UpgradeDefinition
	player.apply_upgrade(base)
	player.apply_upgrade(base)
	_expect(player.get_progress(&"starter_weapon").base_level == 3, "重开前基础等级应生效。")
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
		var fresh: EquipmentProgress = new_session.player.get_progress(&"starter_weapon")
		_expect(fresh != null and fresh.base_level == 1 and not fresh.has_branch(), "重开残留了装备成长。")
		var controller: WeaponController = _find_controller(new_session.player, &"starter_weapon")
		if controller != null:
			_expect(is_equal_approx(controller.get_runtime_damage_multiplier(), 1.0), "重开残留了伤害倍率。")


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _make_system(player: PlayerActor) -> UpgradeSystem:
	var system := UpgradeSystem.new()
	system.initialize(player)
	return system


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
