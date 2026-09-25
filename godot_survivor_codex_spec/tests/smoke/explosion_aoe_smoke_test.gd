## T16：爆炸与范围命中专项回归。
##
## 覆盖中心/范围外、同帧重叠去重、直击与溅射配置、穿透只引爆一次、
## 已释放目标与 Boss、爆炸分支与溅射升级，以及结算后的节点清理。
extends SceneTree

const MAIN_SCENE_PATH := "res://tests/fixtures/legacy_main.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const EXPLOSION_ORB_PATH := "res://data/projectiles/staff_orb_explosion.tres"
const BASE_ORB_PATH := "res://data/projectiles/staff_orb.tres"
const STAFF_PATH := "res://data/weapons/staff.tres"
const EXPLOSION_UPGRADE_PATH := "res://data/upgrades/staff_explosion.tres"
const EXPLOSION_RADIUS_UPGRADE_PATH := "res://data/upgrades/staff_explosion_radius_up.tres"
const EXPLOSION_DAMAGE_UPGRADE_PATH := "res://data/upgrades/staff_explosion_damage_up.tres"
const BOSS_PATH := "res://data/enemies/boss_default.tres"

var _failed: bool = false
var _last_hit_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_center_and_outside()
	await _test_multiple_targets_and_overlap()
	await _test_direct_target_configuration()
	await _test_pierce_detonates_once()
	await _test_released_target_and_boss()
	await _test_branch_and_splash_upgrades()
	await _test_end_run_cleanup()
	if not _failed:
		print("Explosion AoE smoke test passed: query, dedup, config, pierce, branch and cleanup are valid.")
	quit(1 if _failed else 0)


## 中心与范围内目标受溅射，范围外目标不受影响；直击目标同时承受直击与溅射。
func _test_center_and_outside() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var center: EnemyActor = _spawn_dummy(session, Vector2.ZERO)
	var inside: EnemyActor = _spawn_dummy(session, Vector2(60.0, 0.0))
	var outside: EnemyActor = _spawn_dummy(session, Vector2(200.0, 0.0))
	await physics_frame
	await physics_frame

	var explosion_count: Array[int] = [0]
	var hit_count: int = _detonate(session, player, _load_definition(EXPLOSION_ORB_PATH), Vector2.ZERO, center, explosion_count)
	_expect(explosion_count[0] == 1, "应只触发一次爆炸。")
	_expect(hit_count == 2, "爆炸应命中中心与范围内目标，共 2 个。")
	_expect(is_equal_approx(center.health_component.current_health, 488.0), "直击目标应同时承受直击 8 与溅射 4。")
	_expect(is_equal_approx(inside.health_component.current_health, 496.0), "范围内目标应承受溅射 4。")
	_expect(is_equal_approx(outside.health_component.current_health, 500.0), "范围外目标不应受伤。")
	await _free_node(main_node)


## 同帧重叠的多个目标各自只结算一次；爆炸命中数等于唯一目标数。
func _test_multiple_targets_and_overlap() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var center: EnemyActor = _spawn_dummy(session, Vector2.ZERO)
	var overlap_a: EnemyActor = _spawn_dummy(session, Vector2(50.0, 0.0))
	var overlap_b: EnemyActor = _spawn_dummy(session, Vector2(50.0, 0.0))
	await physics_frame
	await physics_frame

	var hit_count: int = _detonate(session, player, _load_definition(EXPLOSION_ORB_PATH), Vector2.ZERO, center, [])
	_expect(hit_count == 3, "重叠目标应按唯一实例去重，共 3 个。")
	_expect(is_equal_approx(overlap_a.health_component.current_health, 496.0), "重叠目标 A 应只受伤一次。")
	_expect(is_equal_approx(overlap_b.health_component.current_health, 496.0), "重叠目标 B 应只受伤一次。")
	await _free_node(main_node)


## 关闭 hits_direct_target 时直击目标不吃溅射，配置生效。
func _test_direct_target_configuration() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var center: EnemyActor = _spawn_dummy(session, Vector2.ZERO)
	var neighbor: EnemyActor = _spawn_dummy(session, Vector2(60.0, 0.0))
	await physics_frame
	await physics_frame

	var definition: ProjectileDefinition = _make_explosion_projectile(false)
	var hit_count: int = _detonate(session, player, definition, Vector2.ZERO, center, [])
	_expect(hit_count == 1, "直击目标被排除后应只命中周围 1 个目标。")
	_expect(is_equal_approx(center.health_component.current_health, 492.0), "直击目标应只承受直击 8。")
	_expect(is_equal_approx(neighbor.health_component.current_health, 496.0), "周围目标应承受溅射 4。")
	await _free_node(main_node)


## 带穿透的爆炸弹首击引爆后停用，不消耗穿透也不二次爆炸。
func _test_pierce_detonates_once() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var center: EnemyActor = _spawn_dummy(session, Vector2.ZERO)
	_spawn_dummy(session, Vector2(60.0, 0.0))
	await physics_frame
	await physics_frame

	var explosion_count: Array[int] = [0]
	var definition: ProjectileDefinition = _load_definition(EXPLOSION_ORB_PATH)
	definition = definition.duplicate() as ProjectileDefinition
	definition.pierce_count = 5
	var projectile: ProjectileBase = _detonate_projectile(session, player, definition, Vector2.ZERO, center, explosion_count)
	_expect(explosion_count[0] == 1, "穿透弹也应只引爆一次。")
	_expect(projectile != null and not projectile.is_active, "爆炸后弹体应停用，不再穿透。")
	_expect(projectile != null and projectile.get_remaining_pierces() == 5, "引爆应发生在消耗穿透之前。")
	await _free_node(main_node)


## 已释放目标被安全跳过，Boss 作为普通 EnemyActor 同样承受爆炸伤害。
func _test_released_target_and_boss() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var center: EnemyActor = _spawn_dummy(session, Vector2.ZERO)
	var released: EnemyActor = _spawn_dummy(session, Vector2(40.0, 0.0))
	var boss_definition: EnemyDefinition = load(BOSS_PATH) as EnemyDefinition
	var boss: EnemyActor = session.enemy_spawner.spawn_enemy(boss_definition, Vector2(70.0, 0.0), true)
	if boss != null:
		boss.set_physics_process(false)
	released.queue_free()
	await physics_frame
	await physics_frame

	var hit_count: int = _detonate(session, player, _load_definition(EXPLOSION_ORB_PATH), Vector2.ZERO, center, [])
	_expect(hit_count == 2, "已释放目标应被跳过，命中直击目标与 Boss 共 2 个。")
	_expect(boss != null and boss.health_component.current_health < boss_definition.max_health, "Boss 应承受溅射伤害。")
	await _free_node(main_node)


## 爆炸分支使法杖切换为爆炸法球；溅射范围/伤害升级只作用于运行时，不回写共享 Resource。
func _test_branch_and_splash_upgrades() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_expect(player.add_weapon(load(STAFF_PATH) as WeaponDefinition), "应能装备蓄力法杖。")
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")

	var ascension: UpgradeDefinition = load(EXPLOSION_UPGRADE_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(ascension), "基础满级后应能选择爆炸法术。")
	var controller: WeaponController = _find_controller(player, &"staff")
	_expect(controller != null, "应能找到法杖控制器。")
	_expect(
		controller.get_effective_projectile_definition().id == &"staff_orb_explosion",
		"选择爆炸分支后应切换为爆炸法球。"
	)
	_expect(
		not session.upgrade_system.can_offer(ascension),
		"已选爆炸分支后同一质变不应再次出现。"
	)

	var radius_upgrade: UpgradeDefinition = load(EXPLOSION_RADIUS_UPGRADE_PATH) as UpgradeDefinition
	var damage_upgrade: UpgradeDefinition = load(EXPLOSION_DAMAGE_UPGRADE_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(radius_upgrade), "应能提升溅射范围。")
	_expect(player.apply_upgrade(radius_upgrade), "溅射范围应能再升一级。")
	_expect(player.apply_upgrade(damage_upgrade), "应能提升溅射伤害。")
	_expect(
		is_equal_approx(controller.get_explosion_radius_multiplier(), 1.5625),
		"两级溅射范围应为 1.25×1.25。"
	)
	_expect(
		is_equal_approx(controller.get_explosion_damage_multiplier(), 1.2),
		"一级溅射伤害倍率应为 1.2。"
	)

	var base_orb: ProjectileDefinition = load(BASE_ORB_PATH) as ProjectileDefinition
	var staff: WeaponDefinition = load(STAFF_PATH) as WeaponDefinition
	_expect(base_orb.explosion == null, "基础法球共享 Resource 不应被写入爆炸。")
	_expect(staff.projectile_definition.id == &"staff_orb", "法杖共享 Resource 不应被改写。")
	await _free_node(main_node)


## 结算后应清理爆炸特效，且不再有活动弹体。
func _test_end_run_cleanup() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var center: EnemyActor = _spawn_dummy(session, Vector2.ZERO)
	await physics_frame
	await physics_frame

	_detonate(session, player, _load_definition(EXPLOSION_ORB_PATH), Vector2.ZERO, center, [])
	_expect(_count_effects(session) >= 1, "爆炸后应存在一个爆炸特效节点。")
	session.end_run(GameResult.Outcome.DEFEAT)
	await process_frame
	await process_frame
	_expect(_count_effects(session) == 0, "结算后应清理爆炸特效。")
	_expect(_count_active_projectiles(session) == 0, "结算后不应有活动弹体。")
	await _free_node(main_node)


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	_disable_weapons(player)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	return player


func _detonate(
		session: GameSession,
		player: PlayerActor,
		definition: ProjectileDefinition,
		position: Vector2,
		direct_target: ActorBase,
		explosion_count: Array[int]
) -> int:
	_last_hit_count = 0
	_detonate_projectile(session, player, definition, position, direct_target, explosion_count)
	return _last_hit_count


func _detonate_projectile(
		session: GameSession,
		player: PlayerActor,
		definition: ProjectileDefinition,
		position: Vector2,
		direct_target: ActorBase,
		explosion_count: Array[int]
) -> ProjectileBase:
	var projectile: ProjectileBase = (load(PROJECTILE_SCENE_PATH) as PackedScene).instantiate()
	session.projectiles.add_child(projectile)
	var context := ProjectileSpawnContext.new(player, &"player", position, Vector2.RIGHT)
	context.weapon_id = &"staff"
	projectile.initialize(definition, context)
	projectile.launch(Vector2.RIGHT)
	var counter: Array[int] = [0]
	projectile.explosion_triggered.connect(func(_center: Vector2, hit_count: int) -> void:
		counter[0] += 1
		_last_hit_count = hit_count
		if not explosion_count.is_empty():
			explosion_count[0] = counter[0]
	)
	projectile.on_hit(direct_target)
	return projectile


func _make_explosion_projectile(hits_direct: bool) -> ProjectileDefinition:
	var profile := ExplosionDefinition.new()
	profile.radius = 90.0
	profile.damage_multiplier = 0.5
	profile.hits_direct_target = hits_direct
	var template: ProjectileDefinition = _load_definition(EXPLOSION_ORB_PATH)
	var definition := ProjectileDefinition.new()
	definition.id = &"test_explosion"
	definition.scene = template.scene
	definition.visual_frames = template.visual_frames
	definition.visual_scale = template.visual_scale
	definition.damage = template.damage
	definition.speed = template.speed
	definition.lifetime_seconds = template.lifetime_seconds
	definition.hit_radius = template.hit_radius
	definition.explosion = profile
	return definition


func _load_definition(path: String) -> ProjectileDefinition:
	return load(path) as ProjectileDefinition


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
	return enemy


func _disable_weapons(player: PlayerActor) -> void:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(false)


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _count_effects(session: GameSession) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ExplosionEffect:
			count += 1
	return count


func _count_active_projectiles(session: GameSession) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).is_active:
			count += 1
	return count


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
