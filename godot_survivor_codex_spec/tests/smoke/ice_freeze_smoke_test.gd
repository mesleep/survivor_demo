## T19 第二步：冰枪冻结专项回归。
##
## 覆盖冻结停止移动与恢复、减速叠加时的恢复顺序、冻结时长升级、刷新与 Boss 免疫。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const BOSS_PATH := "res://data/enemies/boss_default.tres"
const STAFF_PATH := "res://data/weapons/staff.tres"
const ICE_UPGRADE_PATH := "res://data/upgrades/staff_ice.tres"
const ICE_FREEZE_UPGRADE_PATH := "res://data/upgrades/staff_ice_freeze_up.tres"
const ICE_SPEAR_PATH := "res://data/projectiles/staff_ice_spear.tres"
const ICE_FREEZE_PATH := "res://data/combat/ice_freeze.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_freeze_stops_and_recovers()
	await _test_freeze_duration_upgrade()
	await _test_reapply_refresh()
	await _test_boss_immune()
	if not _failed:
		print("Ice freeze smoke test passed: stop, recovery, duration, refresh and immunity are valid.")
	quit(1 if _failed else 0)


## 冻结期间移速为 0；冻结结束后先回到减速倍率，减速结束后完全恢复。
func _test_freeze_stops_and_recovers() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_acquire_ice_staff(player)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(120.0, 0.0))
	await physics_frame
	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var projectile: ProjectileBase = _spawn_projectile(session, player, spear, Vector2.ZERO)
	projectile.on_hit(enemy)

	_expect(enemy.is_frozen(), "命中冰枪应进入冻结。")
	_expect(
		is_equal_approx(enemy.get_status_move_speed_multiplier(), 0.0),
		"冻结期间移速倍率应为 0。"
	)
	_expect(is_equal_approx(enemy.get_effective_move_speed(), 0.0), "冻结期间有效移速应为 0。")

	enemy.status_effect_component.advance_time(0.8)
	_expect(not enemy.is_frozen(), "0.8 秒后冻结应结束。")
	_expect(
		is_equal_approx(enemy.get_status_move_speed_multiplier(), 0.6),
		"冻结结束后应回到冰缓倍率 0.6。"
	)
	enemy.status_effect_component.advance_time(0.7)
	_expect(
		is_equal_approx(enemy.get_status_move_speed_multiplier(), 1.0),
		"冰缓也结束后应完全恢复。"
	)
	await _free_node(main_node)


## 冻结时长升级按倍率作用于本次施加，且共享 Resource 不变。
func _test_freeze_duration_upgrade() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var controller: WeaponController = _acquire_ice_staff(player)
	_expect(
		player.apply_upgrade(load(ICE_FREEZE_UPGRADE_PATH) as UpgradeDefinition),
		"应能提升冻结时长。"
	)
	_expect(
		is_equal_approx(controller.get_freeze_duration_multiplier(), 1.25),
		"一级冰封应为 1.25 倍。"
	)

	var enemy: EnemyActor = _spawn_dummy(session, Vector2(120.0, 0.0))
	await physics_frame
	var spear: ProjectileDefinition = load(ICE_SPEAR_PATH) as ProjectileDefinition
	var projectile: ProjectileBase = _spawn_projectile(session, player, spear, Vector2.ZERO)
	projectile.context.freeze_duration_multiplier = controller.get_freeze_duration_multiplier()
	projectile.on_hit(enemy)
	_expect(
		is_equal_approx(enemy.status_effect_component.get_freeze_remaining(&"ice_freeze"), 1.0),
		"升级后冻结剩余时长应为 0.8×1.25=1.0。"
	)

	var freeze: FreezeEffect = load(ICE_FREEZE_PATH) as FreezeEffect
	_expect(is_equal_approx(freeze.duration_seconds, 0.8), "共享冻结 Resource 不应被回写。")
	await _free_node(main_node)


## 重复冻结只刷新时长，不叠层。
func _test_reapply_refresh() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(300.0, 0.0))
	var freeze: FreezeEffect = load(ICE_FREEZE_PATH) as FreezeEffect
	enemy.apply_freeze(freeze)
	enemy.status_effect_component.advance_time(0.5)
	enemy.apply_freeze(freeze)
	_expect(enemy.status_effect_component.is_frozen(), "刷新后应仍在冻结。")
	_expect(
		is_equal_approx(enemy.status_effect_component.get_freeze_remaining(&"ice_freeze"), 0.8),
		"刷新后冻结剩余时长应重置为 0.8。"
	)
	await _free_node(main_node)


## Boss 控制免疫应同时拒绝冻结。
func _test_boss_immune() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_prepare(session)
	var boss_definition: EnemyDefinition = load(BOSS_PATH) as EnemyDefinition
	var boss: EnemyActor = session.enemy_spawner.spawn_enemy(boss_definition, Vector2(300.0, 0.0), true)
	var freeze: FreezeEffect = load(ICE_FREEZE_PATH) as FreezeEffect
	_expect(not boss.apply_freeze(freeze), "Boss 应拒绝冻结。")
	_expect(not boss.is_frozen(), "Boss 不应处于冻结状态。")
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
