## T19 第一步：冰枪穿透与减速专项回归。
##
## 覆盖分支切换、穿透逐一命中、减速生效与恢复、Boss 控制免疫、死亡清理与共享 Resource。
extends SceneTree

const MAIN_SCENE_PATH := "res://tests/fixtures/legacy_main.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const BOSS_PATH := "res://data/enemies/boss_default.tres"
const STAFF_PATH := "res://data/weapons/staff.tres"
const ICE_UPGRADE_PATH := "res://data/upgrades/staff_ice.tres"
const ICE_SPEAR_PATH := "res://data/projectiles/staff_ice_spear.tres"
const ICE_SLOW_PATH := "res://data/combat/ice_slow.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_branch_pierce_and_slow()
	await _test_boss_immune()
	await _test_enemy_death_clears_slow()
	if not _failed:
		print("Ice slow smoke test passed: pierce, slow, immunity and cleanup are valid.")
	quit(1 if _failed else 0)


## 冰枪可穿透不同敌人各命中一次并施加减速，减速到期后恢复。
func _test_branch_pierce_and_slow() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var controller: WeaponController = _acquire_staff(player)
	_expect(player.apply_upgrade(load(ICE_UPGRADE_PATH) as UpgradeDefinition), "应能选择寒冰法术。")
	_expect(
		controller.get_effective_projectile_definition().id == &"staff_ice_spear",
		"选择寒冰分支后应切换为冰枪。"
	)

	var first: EnemyActor = _spawn_dummy(session, Vector2(100.0, 0.0))
	var second: EnemyActor = _spawn_dummy(session, Vector2(200.0, 0.0))
	await physics_frame
	await physics_frame
	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var projectile: ProjectileBase = _spawn_projectile(session, player, spear, Vector2.ZERO)
	projectile.on_hit(first)
	projectile.on_hit(second)

	_expect(is_equal_approx(first.health_component.current_health, 493.0), "第一个敌人应受 7 点冰枪伤害。")
	_expect(is_equal_approx(second.health_component.current_health, 493.0), "第二个敌人应受 7 点冰枪伤害。")
	_expect(projectile.is_active, "穿透未耗尽时冰枪应继续飞行。")
	_expect(projectile.get_remaining_pierces() == 1, "命中两次后应剩余 1 次穿透。")
	_expect(first.status_effect_component.has_slow(&"ice_slow"), "命中应施加冰缓。")
	# 冰枪同时附带冻结，冻结期间移速为 0；冻结结束后才应看到冰缓倍率。
	first.status_effect_component.advance_time(0.8)
	_expect(
		is_equal_approx(first.get_status_move_speed_multiplier(), 0.6),
		"冻结结束后冰缓 0.4 应使移速倍率为 0.6。"
	)
	first.status_effect_component.advance_time(0.7)
	_expect(first.status_effect_component.get_active_slow_count() == 0, "减速到期后应移除状态。")
	_expect(is_equal_approx(first.get_status_move_speed_multiplier(), 1.0), "状态结束后移速应恢复。")
	await _free_node(main_node)


## Boss 标记控制免疫后不接受减速。
func _test_boss_immune() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_prepare(session)
	var boss_definition: EnemyDefinition = load(BOSS_PATH) as EnemyDefinition
	var boss: EnemyActor = session.enemy_spawner.spawn_enemy(boss_definition, Vector2(300.0, 0.0), true)
	_expect(boss != null and boss.is_control_immune(), "Boss 应标记为控制免疫。")
	var slow: MovementSlowEffect = load(ICE_SLOW_PATH) as MovementSlowEffect
	_expect(not boss.apply_movement_slow(slow), "控制免疫目标应拒绝减速。")
	_expect(is_equal_approx(boss.get_status_move_speed_multiplier(), 1.0), "Boss 移速不应被减速。")
	await _free_node(main_node)


## 敌人死亡时清除减速状态，且共享 Resource 未被回写。
func _test_enemy_death_clears_slow() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(300.0, 0.0))
	var slow: MovementSlowEffect = load(ICE_SLOW_PATH) as MovementSlowEffect
	enemy.apply_movement_slow(slow)
	_expect(enemy.status_effect_component.get_active_slow_count() == 1, "应先有减速状态。")
	enemy.apply_damage(DamageEvent.new(9999.0, null, Vector2.ZERO))
	_expect(enemy.status_effect_component.get_active_slow_count() == 0, "死亡后应清除减速。")

	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	_expect(is_equal_approx(spear.on_hit_slow.slow_ratio, 0.4), "共享冰缓比例不应被回写。")
	_expect(spear.pierce_count == 3, "共享冰枪穿透不应被回写。")
	await _free_node(main_node)


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


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	return player


func _acquire_staff(player: PlayerActor) -> WeaponController:
	_expect(player.add_weapon(load(STAFF_PATH) as WeaponDefinition), "应能装备蓄力法杖。")
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")
	return _find_controller(player, &"staff")


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
