## T25：科技三件套与发射器专项回归。
##
## 覆盖三件都需科技质变、状态变化只激活一次、可撤销（不重复移速/不重复发射器）、
## 随机目标导弹、目标缺失回退、清理与重开。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"
const HELMET_PATH := "res://data/armor/armor_helmet.tres"
const GLOVES_PATH := "res://data/armor/armor_gloves.tres"
const ARMOR_BASE_UP_PATH := "res://data/upgrades/armor_basic_up.tres"
const HELMET_BASE_UP_PATH := "res://data/upgrades/helmet_base_up.tres"
const GLOVES_BASE_UP_PATH := "res://data/upgrades/gloves_base_up.tres"
const ARMOR_TECH_PATH := "res://data/upgrades/armor_tech.tres"
const HELMET_TECH_PATH := "res://data/upgrades/helmet_tech.tres"
const GLOVES_TECH_PATH := "res://data/upgrades/gloves_tech.tres"
const THORN_PATH := "res://data/upgrades/armor_thorns.tres"
const TECH_SET_PATH := "res://data/armor/tech_set_default.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_set_requires_all_three_and_is_idempotent()
	await _test_branch_mismatch_blocks_set()
	await _test_random_target_missiles()
	await _test_fallback_when_no_random_target()
	await _test_cleanup_on_clear()
	if not _failed:
		print("Tech set smoke test passed: activation, idempotency, missiles, fallback and cleanup are valid.")
	quit(1 if _failed else 0)


## 三件都选科技才激活；重复评估不重复加速、不生成第二个发射器。
func _test_set_requires_all_three_and_is_idempotent() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_tech(player, ARMOR_PATH, &"armor_basic", ARMOR_BASE_UP_PATH, ARMOR_TECH_PATH)
	_expect(not player.is_tech_set_active(), "只有战甲时不应激活套装。")
	_enable_tech(player, HELMET_PATH, &"armor_helmet", HELMET_BASE_UP_PATH, HELMET_TECH_PATH)
	_expect(not player.is_tech_set_active(), "只有两件时不应激活套装。")
	_enable_tech(player, GLOVES_PATH, &"armor_gloves", GLOVES_BASE_UP_PATH, GLOVES_TECH_PATH)
	_expect(player.is_tech_set_active(), "三件科技应激活套装。")
	_expect(
		is_equal_approx(player.get_effective_move_speed(), 220.0 * 1.4),
		"套装激活后移速应为 220×1.4。"
	)
	_expect(_launcher_count(player) == 1, "套装应只授予一个科技发射器。")

	player.configure_tech_set(load(TECH_SET_PATH) as TechSetDefinition)
	_expect(is_equal_approx(player.get_effective_move_speed(), 220.0 * 1.4), "重复评估不应重复加速。")
	_expect(_launcher_count(player) == 1, "重复评估不应生成第二发射器。")
	await _free_node(main_node)


## 盔甲选非科技分支时套装不激活。
func _test_branch_mismatch_blocks_set() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_expect(player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition), "应能装备基础盔甲。")
	_max_base(player, &"armor_basic", ARMOR_BASE_UP_PATH)
	_expect(player.apply_upgrade(load(THORN_PATH) as UpgradeDefinition), "盔甲应能选择反伤刺甲。")
	_enable_tech(player, HELMET_PATH, &"armor_helmet", HELMET_BASE_UP_PATH, HELMET_TECH_PATH)
	_enable_tech(player, GLOVES_PATH, &"armor_gloves", GLOVES_BASE_UP_PATH, GLOVES_TECH_PATH)
	_expect(not player.is_tech_set_active(), "盔甲非科技分支时不应激活套装。")
	_expect(_launcher_count(player) == 0, "未激活时不应有发射器。")
	await _free_node(main_node)


## 一次攻击生成 3 枚带爆炸的导弹，并各自朝候选中随机目标发射。
func _test_random_target_missiles() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_activate_set(player)
	_disable_all_weapons(player)
	var enemy_a: EnemyActor = _spawn_dummy(session, Vector2(200.0, 0.0))
	_spawn_dummy(session, Vector2(0.0, 200.0))
	_spawn_dummy(session, Vector2(-200.0, 0.0))
	await create_timer(0.15).timeout

	session.targeting_service.set_random_seed(7)
	var launcher: WeaponController = _find_controller(player, &"tech_launcher")
	launcher.reset_runtime_state()
	_expect(launcher.request_fire(enemy_a), "发射器应能发射。")
	_expect(_count_projectiles(session, &"tech_missile") == 3, "一次应生成 3 枚导弹。")
	var directions: Dictionary[float, bool] = {}
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == &"tech_missile":
			var missile: ProjectileBase = child as ProjectileBase
			_expect(missile.definition.explosion != null, "导弹应带爆炸档案。")
			directions[snappedf(missile.direction.angle(), 0.001)] = true
	_expect(directions.size() >= 2, "随机目标应使导弹方向不全相同。")
	await _free_node(main_node)


## 随机候选中没有有效目标时回退到基础方向，仍能发射。
func _test_fallback_when_no_random_target() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_activate_set(player)
	_disable_all_weapons(player)
	var far_enemy: EnemyActor = _spawn_dummy(session, Vector2(1500.0, 0.0))
	await create_timer(0.15).timeout

	var launcher: WeaponController = _find_controller(player, &"tech_launcher")
	launcher.reset_runtime_state()
	_expect(launcher.request_fire(far_enemy), "范围内没有候选时仍应回退发射。")
	_expect(_count_projectiles(session, &"tech_missile") == 3, "回退时也应生成 3 枚导弹。")
	await _free_node(main_node)


## clear_weapons 应移除发射器并清空套装武器引用。
func _test_cleanup_on_clear() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_activate_set(player)
	_expect(_launcher_count(player) == 1, "清理前应有发射器。")
	player.clear_weapons()
	_expect(player.get_set_weapon() == null, "清理后套装武器引用应为空。")
	_expect(_launcher_count(player) == 0, "清理后不应再有发射器控制器。")
	await _free_node(main_node)


func _activate_set(player: PlayerActor) -> void:
	_enable_tech(player, ARMOR_PATH, &"armor_basic", ARMOR_BASE_UP_PATH, ARMOR_TECH_PATH)
	_enable_tech(player, HELMET_PATH, &"armor_helmet", HELMET_BASE_UP_PATH, HELMET_TECH_PATH)
	_enable_tech(player, GLOVES_PATH, &"armor_gloves", GLOVES_BASE_UP_PATH, GLOVES_TECH_PATH)
	_expect(player.is_tech_set_active(), "套装应已激活。")


func _enable_tech(
		player: PlayerActor,
		armor_path: String,
		equipment_id: StringName,
		base_up_path: String,
		tech_path: String
) -> void:
	_expect(player.try_acquire_armor(load(armor_path) as ArmorDefinition), "应能装备 %s。" % equipment_id)
	_max_base(player, equipment_id, base_up_path)
	_expect(player.apply_upgrade(load(tech_path) as UpgradeDefinition), "%s 应能选择科技质变。" % equipment_id)


func _max_base(player: PlayerActor, equipment_id: StringName, upgrade_path: String) -> void:
	var upgrade: UpgradeDefinition = load(upgrade_path) as UpgradeDefinition
	for _index: int in range(upgrade.max_stacks):
		_expect(player.apply_upgrade(upgrade), "基础强化应成功：%s。" % equipment_id)


func _launcher_count(player: PlayerActor) -> int:
	var count: int = 0
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == &"tech_launcher":
			count += 1
	return count


func _disable_all_weapons(player: PlayerActor) -> void:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _count_projectiles(session: GameSession, definition_id: StringName) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == definition_id:
			count += 1
	return count


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	_disable_all_weapons(player)
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
		if enemy.status_effect_component != null:
			enemy.status_effect_component.set_process(false)
	return enemy


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
