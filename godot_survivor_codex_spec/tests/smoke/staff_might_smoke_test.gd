## T18：威能分支（伤害/攻速/射程三修正）专项回归。
##
## 验证质变捆绑修正、专属升级独立上限、与通用 Buff 叠加、冷却下限钳制、
## 分支互斥、晚获取继承通用 Buff 以及共享 Resource 不变。
extends SceneTree

const MAIN_SCENE_PATH := "res://tests/fixtures/legacy_main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const STAFF_PATH := "res://data/weapons/staff.tres"
const MIGHT_PATH := "res://data/upgrades/staff_might.tres"
const POWER_UP_PATH := "res://data/upgrades/staff_might_power_up.tres"
const HASTE_UP_PATH := "res://data/upgrades/staff_might_haste_up.tres"
const RANGE_UP_PATH := "res://data/upgrades/staff_might_range_up.tres"
const EXPLOSION_PATH := "res://data/upgrades/staff_explosion.tres"
const FLAME_PATH := "res://data/upgrades/staff_flame.tres"
const DAMAGE_UP_PATH := "res://data/upgrades/damage_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ascension_bundle()
	await _test_generic_stack_and_late_acquire()
	await _test_exclusive_limits_and_clamp()
	if not _failed:
		print("Staff might smoke test passed: bundle, stacking, limits and clamp are valid.")
	quit(1 if _failed else 0)


## 威能质变一次性提高伤害、攻速（冷却缩短）与射程，且不写共享 Resource。
func _test_ascension_bundle() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var controller: WeaponController = _acquire_staff(player)
	_expect(is_equal_approx(controller.get_effective_cooldown_seconds(), 2.0), "质变前冷却应为 2.0。")
	_expect(is_equal_approx(controller.get_runtime_damage_multiplier(), 1.0), "质变前伤害倍率应为 1.0。")

	_expect(player.apply_upgrade(load(MIGHT_PATH) as UpgradeDefinition), "应能选择威能法术。")
	_expect(
		is_equal_approx(controller.get_effective_cooldown_seconds(), 1.6),
		"威能质变后冷却应缩短为 1.6。"
	)
	_expect(
		is_equal_approx(controller.get_runtime_damage_multiplier(), 1.4),
		"威能质变后伤害倍率应为 1.4。"
	)
	_expect(
		is_equal_approx(controller.get_effective_target_range(), 1250.0),
		"威能质变后有效索敌射程应为 1000×1.25。"
	)

	var staff: WeaponDefinition = load(STAFF_PATH) as WeaponDefinition
	_expect(is_equal_approx(staff.cooldown_seconds, 2.0), "共享法杖冷却不应被回写。")
	await _free_node(main_node)


## 与通用伤害 Buff 叠加；晚获取的武器继承通用 Buff 但不继承法杖分支修正。
func _test_generic_stack_and_late_acquire() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var controller: WeaponController = _acquire_staff(player)
	player.apply_upgrade(load(DAMAGE_UP_PATH) as UpgradeDefinition)
	player.apply_upgrade(load(MIGHT_PATH) as UpgradeDefinition)
	_expect(
		is_equal_approx(controller.get_runtime_damage_multiplier(), 1.68),
		"通用 +20% 与威能 ×1.4 应相乘为 1.68。"
	)

	var bow: WeaponDefinition = (load(CATALOG_PATH) as ContentCatalog).get_weapon(&"bow")
	_expect(player.try_acquire_weapon(bow), "应能获取长弓。")
	var bow_controller: WeaponController = _find_controller(player, &"bow")
	_expect(
		bow_controller != null and is_equal_approx(bow_controller.get_runtime_damage_multiplier(), 1.2),
		"晚获取的长弓应只继承通用 Buff。"
	)
	var staff_resource: WeaponDefinition = load(STAFF_PATH) as WeaponDefinition
	_expect(is_equal_approx(staff_resource.cooldown_seconds, 2.0), "共享法杖 Resource 不应被回写。")
	await _free_node(main_node)


## 专属升级各自独立上限；冷却存在全局下限；选择威能后其他法杖分支不可再出。
func _test_exclusive_limits_and_clamp() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var controller: WeaponController = _acquire_staff(player)
	player.apply_upgrade(load(MIGHT_PATH) as UpgradeDefinition)

	var power: UpgradeDefinition = load(POWER_UP_PATH) as UpgradeDefinition
	var haste: UpgradeDefinition = load(HASTE_UP_PATH) as UpgradeDefinition
	var range_up: UpgradeDefinition = load(RANGE_UP_PATH) as UpgradeDefinition
	for _index: int in range(power.max_stacks):
		_expect(player.apply_upgrade(power), "伤害专属升级应成功。")
	for _index: int in range(haste.max_stacks):
		_expect(player.apply_upgrade(haste), "攻速专属升级应成功。")
	for _index: int in range(range_up.max_stacks):
		_expect(player.apply_upgrade(range_up), "射程专属升级应成功。")

	_expect(not session.upgrade_system.can_offer(power), "伤害专属达到上限后不应再出现。")
	_expect(not session.upgrade_system.can_offer(haste), "攻速专属达到上限后不应再出现。")
	_expect(not session.upgrade_system.can_offer(range_up), "射程专属达到上限后不应再出现。")
	_expect(
		is_equal_approx(controller.get_runtime_damage_multiplier(), 1.4 * 1.15 * 1.15 * 1.15),
		"三级伤害专属应为 1.4×1.15³。"
	)
	_expect(
		is_equal_approx(controller.get_effective_cooldown_seconds(), 2.0 * 0.8 * 0.9 * 0.9 * 0.9),
		"三级攻速专属应将冷却缩为 2.0×0.8×0.9³。"
	)
	_expect(
		is_equal_approx(controller.get_effective_target_range(), 1000.0 * 1.25 * 1.1 * 1.1 * 1.1),
		"三级射程专属应为 1000×1.25×1.1³。"
	)

	var tiny := WeaponRuntimeModifier.new()
	tiny.cooldown_multiplier = 0.05
	controller.apply_runtime_modifier(tiny)
	controller.apply_runtime_modifier(tiny)
	_expect(
		is_equal_approx(controller.get_effective_cooldown_seconds(), WeaponController.MINIMUM_COOLDOWN_SECONDS),
		"冷却应钳制到最小值 0.02。"
	)

	_expect(
		not session.upgrade_system.can_offer(load(EXPLOSION_PATH) as UpgradeDefinition),
		"已选威能后不应再出现爆炸法术。"
	)
	_expect(
		not session.upgrade_system.can_offer(load(FLAME_PATH) as UpgradeDefinition),
		"已选威能后不应再出现火焰法术。"
	)
	await _free_node(main_node)


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)
	return player


func _acquire_staff(player: PlayerActor) -> WeaponController:
	_expect(player.add_weapon(load(STAFF_PATH) as WeaponDefinition), "应能装备蓄力法杖。")
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")
	return _find_controller(player, &"staff")


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
