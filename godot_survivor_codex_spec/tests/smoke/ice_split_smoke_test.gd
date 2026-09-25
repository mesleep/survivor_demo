## T19 第三步：冰枪分裂专项回归。
##
## 覆盖命中分裂、分裂弹不递归、分裂数量升级、角度与伤害倍率、共享 Resource 不变。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const STAFF_PATH := "res://data/weapons/staff.tres"
const ICE_UPGRADE_PATH := "res://data/upgrades/staff_ice.tres"
const ICE_SPLIT_UPGRADE_PATH := "res://data/upgrades/staff_ice_split_up.tres"
const ICE_SPEAR_PATH := "res://data/projectiles/staff_ice_spear.tres"
const ICE_SPLIT_PATH := "res://data/projectiles/staff_ice_split.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_split_and_no_recursion()
	await _test_split_count_upgrade()
	await _test_split_angle_and_damage()
	if not _failed:
		print("Ice split smoke test passed: spawn, no recursion, count, angle and damage are valid.")
	quit(1 if _failed else 0)


## 冰枪命中分裂两枚小冰枪；小冰枪命中后不再分裂。
func _test_split_and_no_recursion() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_ice_staff(player)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(120.0, 0.0))
	var other: EnemyActor = _spawn_dummy(session, Vector2(400.0, 0.0))
	await physics_frame
	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var projectile: ProjectileBase = _spawn_projectile(session, player, spear, Vector2.ZERO)
	projectile.on_hit(enemy)
	_expect(_count_projectiles(session, &"staff_ice_split") == 2, "命中应分裂出 2 枚小冰枪。")
	_expect(projectile.is_active, "分裂不影响主冰枪的穿透存续。")

	var split_child: ProjectileBase = _first_projectile(session, &"staff_ice_split")
	_expect(split_child != null, "应能找到分裂小冰枪。")
	if split_child != null:
		split_child.on_hit(other)
		_expect(
			_count_projectiles(session, &"staff_ice_split") == 2,
			"分裂弹命中后不应再产生新的分裂弹。"
		)
	await _free_node(main_node)


## 裂冰专属升级每级增加 1 枚分裂弹，且独立上限。
func _test_split_count_upgrade() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var controller: WeaponController = _acquire_ice_staff(player)
	var upgrade: UpgradeDefinition = load(ICE_SPLIT_UPGRADE_PATH) as UpgradeDefinition
	for _index: int in range(upgrade.max_stacks):
		_expect(player.apply_upgrade(upgrade), "裂冰升级应成功。")
	_expect(controller.get_split_count_bonus() == 2, "两级裂冰应增加 2 枚分裂弹。")
	_expect(not session.upgrade_system.can_offer(upgrade), "裂冰达到上限后不应再出现。")

	var enemy: EnemyActor = _spawn_dummy(session, Vector2(120.0, 0.0))
	await physics_frame
	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var projectile: ProjectileBase = _spawn_projectile(session, player, spear, Vector2.ZERO)
	projectile.context.split_count_bonus = controller.get_split_count_bonus()
	projectile.on_hit(enemy)
	_expect(_count_projectiles(session, &"staff_ice_split") == 4, "基础 2 + 升级 2 应分裂 4 枚。")
	await _free_node(main_node)


## 分裂弹方向对称且不重叠，伤害按倍率衰减；共享 Resource 不变。
func _test_split_angle_and_damage() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_ice_staff(player)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(120.0, 0.0))
	await physics_frame
	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var projectile: ProjectileBase = _spawn_projectile(session, player, spear, Vector2.ZERO)
	projectile.on_hit(enemy)

	var angles: Array[float] = []
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == &"staff_ice_split":
			var split: ProjectileBase = child as ProjectileBase
			angles.append(split.direction.angle())
			_expect(
				is_equal_approx(split.context.damage_multiplier, 0.4),
				"分裂弹伤害倍率应为 0.4。"
			)
			_expect(absf(rad_to_deg(split.direction.angle())) <= 45.001, "分裂弹应落在 ±45° 内。")
	_expect(angles.size() == 2 and not is_equal_approx(angles[0], angles[1]), "两枚分裂弹方向应不同。")

	var spear_resource: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var split_resource: ProjectileDefinition = load(ICE_SPLIT_PATH) as ProjectileDefinition
	_expect(spear_resource.split_count == 2, "共享冰枪分裂数不应被回写。")
	_expect(split_resource.split_projectile == null, "共享小冰枪不应再配置分裂。")
	await _free_node(main_node)


func _acquire_ice_staff(player: PlayerActor) -> WeaponController:
	_expect(player.add_weapon(load(STAFF_PATH) as WeaponDefinition), "应能装备蓄力法杖。")
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")
	_expect(player.apply_upgrade(load(ICE_UPGRADE_PATH) as UpgradeDefinition), "应能选择寒冰法术。")
	return _find_controller(player, &"staff")


func _spawn_projectile(
		session: GameSession,
		player: PlayerActor,
		definition: ProjectileDefinition,
		position: Vector2
) -> ProjectileBase:
	var projectile: ProjectileBase = (load(PROJECTILE_SCENE_PATH) as PackedScene).instantiate()
	session.projectiles.add_child(projectile)
	var context := ProjectileSpawnContext.new(player, &"player", position, Vector2.RIGHT)
	context.weapon_id = &"staff"
	projectile.initialize(definition, context)
	projectile.launch(Vector2.RIGHT)
	return projectile


func _count_projectiles(session: GameSession, definition_id: StringName) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == definition_id:
			count += 1
	return count


func _first_projectile(session: GameSession, definition_id: StringName) -> ProjectileBase:
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == definition_id:
			return child as ProjectileBase
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
		child.queue_free()


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
