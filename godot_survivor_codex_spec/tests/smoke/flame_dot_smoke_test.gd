## T17：火焰持续伤害与地面火坑专项回归。
##
## 用可手动推进的 advance_time 保证 tick 数确定，覆盖刷新不叠层、无吸血/无暴击/无反伤、
## 来源离树、敌人死亡、火焰分支挂 DoT、火坑进出范围/重叠与结算清理。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectiles/projectile_base.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const FLAME_BOLT_PATH := "res://data/projectiles/staff_flame_bolt.tres"
const FLAME_DOT_PATH := "res://data/combat/flame_dot.tres"
const STAFF_PATH := "res://data/weapons/staff.tres"
const FLAME_UPGRADE_PATH := "res://data/upgrades/staff_flame.tres"
const FLAME_DURATION_UPGRADE_PATH := "res://data/upgrades/staff_flame_duration_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_dot_tick_count()
	await _test_dot_refresh_not_stack()
	await _test_dot_no_lifesteal_reflect()
	await _test_source_leaving_and_enemy_death()
	await _test_flame_branch_and_patch()
	await _test_patch_enter_leave_and_overlap()
	await _test_end_run_cleanup()
	if not _failed:
		print("Flame DoT smoke test passed: ticks, refresh, tags, patch and cleanup are valid.")
	quit(1 if _failed else 0)


## 固定时间内的 DoT tick 数与总伤害可精确断言。
func _test_dot_tick_count() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(400.0, 0.0))
	var dot: DamageOverTimeEffect = _make_dot(3.0, 0.5, 2.0)
	_expect(enemy.apply_damage_over_time(dot, player, 1.0), "应能施加持续伤害。")
	for _step: int in range(25):
		enemy.status_effect_component.advance_time(0.1)
	_expect(
		is_equal_approx(enemy.health_component.current_health, 488.0),
		"2 秒 / 每 0.5 秒应结算 4 跳，共 12 点。"
	)
	_expect(enemy.status_effect_component.get_active_dot_count() == 0, "持续时间结束后应移除状态。")
	await _free_node(main_node)


## 重复施加同一效果只刷新持续时间，不叠层、不改变每跳伤害。
func _test_dot_refresh_not_stack() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(400.0, 0.0))
	var dot: DamageOverTimeEffect = _make_dot(3.0, 0.5, 2.0)
	enemy.apply_damage_over_time(dot, player, 1.0)
	for _step: int in range(10):
		enemy.status_effect_component.advance_time(0.1)
	_expect(enemy.status_effect_component.get_active_dot_count() == 1, "同一效果不应叠层。")
	var damage_before: float = enemy.health_component.current_health
	enemy.apply_damage_over_time(dot, player, 1.0)
	_expect(enemy.status_effect_component.get_active_dot_count() == 1, "刷新后仍应只有一层。")
	for _step: int in range(5):
		enemy.status_effect_component.advance_time(0.1)
	_expect(
		is_equal_approx(damage_before - enemy.health_component.current_health, 3.0),
		"刷新后每跳伤害应仍为 3。"
	)
	_expect(
		enemy.status_effect_component.get_dot_remaining(dot.id) > 1.4,
		"刷新后持续时间应被重置。"
	)
	await _free_node(main_node)


## DoT 打上 dot 标签：不吸血、不暴击、不触发反伤。
func _test_dot_no_lifesteal_reflect() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(400.0, 0.0))
	enemy.set_damage_reflect_ratio(1.0)
	var health_before: float = player.health_component.current_health
	var dot: DamageOverTimeEffect = _make_dot(4.0, 0.5, 1.0)
	enemy.apply_damage_over_time(dot, player, 1.0)
	enemy.status_effect_component.advance_time(1.0)
	_expect(
		is_equal_approx(player.health_component.current_health, health_before),
		"DoT 不应吸血，也不应因目标反伤而伤害施法者。"
	)
	_expect(
		is_equal_approx(enemy.health_component.current_health, 492.0),
		"DoT 应无视反伤照常结算自身伤害。"
	)
	await _free_node(main_node)


## 来源离树后 DoT 继续到时长结束；敌人死亡则清除状态。
func _test_source_leaving_and_enemy_death() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(400.0, 0.0))
	var source := Node2D.new()
	session.add_child(source)
	var dot: DamageOverTimeEffect = _make_dot(3.0, 0.5, 2.0)
	enemy.apply_damage_over_time(dot, source, 1.0)
	source.queue_free()
	await process_frame
	enemy.status_effect_component.advance_time(0.5)
	_expect(
		enemy.health_component.current_health < 500.0,
		"来源离树后 DoT 应继续结算。"
	)
	enemy.apply_damage(DamageEvent.new(9999.0, null, Vector2.ZERO))
	enemy.status_effect_component.advance_time(1.0)
	_expect(
		enemy.status_effect_component.get_active_dot_count() == 0,
		"敌人死亡后应清除持续伤害状态。"
	)
	await _free_node(main_node)


## 火焰质变切换为火焰弹，命中挂 DoT 并在地面生成火坑；持续时间升级可叠加。
func _test_flame_branch_and_patch() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_expect(player.add_weapon(load(STAFF_PATH) as WeaponDefinition), "应能装备蓄力法杖。")
	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")
	var ascension: UpgradeDefinition = load(FLAME_UPGRADE_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(ascension), "基础满级后应能选择火焰法术。")
	var controller: WeaponController = _find_controller(player, &"staff")
	_expect(
		controller != null and controller.get_effective_projectile_definition().id == &"staff_flame_bolt",
		"选择火焰分支后应切换为火焰弹。"
	)

	var duration_upgrade: UpgradeDefinition = load(FLAME_DURATION_UPGRADE_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(duration_upgrade), "应能提升火坑持续时间。")
	_expect(
		is_equal_approx(controller.get_ground_area_duration_multiplier(), 1.25),
		"一级持续时间升级应为 1.25 倍。"
	)

	var enemy: EnemyActor = _spawn_dummy(session, Vector2(0.0, 0.0))
	await physics_frame
	var flame_bolt: ProjectileDefinition = load(FLAME_BOLT_PATH) as ProjectileDefinition
	_hit_with(session, player, flame_bolt, Vector2.ZERO, enemy)
	_expect(enemy.status_effect_component.has_dot(&"flame_dot"), "火焰弹命中应挂上持续伤害。")
	_expect(_count_ground_areas(session) == 1, "火焰弹命中应生成一个火坑。")
	await _free_node(main_node)


## 火坑只伤害范围内的敌人；目标离开不再受伤；多个火坑独立重叠结算。
func _test_patch_enter_leave_and_overlap() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var inside: EnemyActor = _spawn_dummy(session, Vector2(20.0, 0.0))
	var outside: EnemyActor = _spawn_dummy(session, Vector2(300.0, 0.0))
	await physics_frame
	await physics_frame

	var patch_definition: GroundDamageAreaDefinition = load("res://data/combat/fire_patch.tres") as GroundDamageAreaDefinition
	var patch: GroundDamageArea = _spawn_patch(session, patch_definition, player, Vector2.ZERO)
	patch.advance_time(0.5)
	_expect(inside.health_component.current_health < 500.0, "范围内敌人应受到火坑伤害。")
	_expect(
		is_equal_approx(outside.health_component.current_health, 500.0),
		"范围外敌人不应受到火坑伤害。"
	)

	var health_after_tick: float = inside.health_component.current_health
	inside.global_position = Vector2(300.0, 0.0)
	await physics_frame
	patch.advance_time(0.5)
	_expect(
		is_equal_approx(inside.health_component.current_health, health_after_tick),
		"离开范围后不应继续受到伤害。"
	)

	inside.global_position = Vector2.ZERO
	await physics_frame
	var overlap: GroundDamageArea = _spawn_patch(session, patch_definition, player, Vector2.ZERO)
	var before_overlap: float = inside.health_component.current_health
	patch.advance_time(0.5)
	overlap.advance_time(0.5)
	_expect(
		before_overlap - inside.health_component.current_health >= 4.0,
		"两个重叠火坑应各自结算。"
	)
	await _free_node(main_node)


## 结算后应清理地面火坑。
func _test_end_run_cleanup() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var patch_definition: GroundDamageAreaDefinition = load("res://data/combat/fire_patch.tres") as GroundDamageAreaDefinition
	_spawn_patch(session, patch_definition, player, Vector2.ZERO)
	_expect(_count_ground_areas(session) == 1, "应存在一个火坑节点。")
	session.end_run(GameResult.Outcome.DEFEAT)
	await process_frame
	await process_frame
	_expect(_count_ground_areas(session) == 0, "结算后应清理火坑。")
	await _free_node(main_node)


func _make_dot(damage_per_tick: float, tick_interval: float, duration: float) -> DamageOverTimeEffect:
	var effect := DamageOverTimeEffect.new()
	effect.id = &"test_dot"
	effect.damage_per_tick = damage_per_tick
	effect.tick_interval_seconds = tick_interval
	effect.duration_seconds = duration
	return effect


func _hit_with(
		session: GameSession,
		player: PlayerActor,
		definition: ProjectileDefinition,
		position: Vector2,
		target: ActorBase
) -> void:
	var projectile: ProjectileBase = (load(PROJECTILE_SCENE_PATH) as PackedScene).instantiate()
	session.projectiles.add_child(projectile)
	var context := ProjectileSpawnContext.new(player, &"player", position, Vector2.RIGHT)
	context.weapon_id = &"staff"
	projectile.initialize(definition, context)
	projectile.launch(Vector2.RIGHT)
	projectile.on_hit(target)


func _spawn_patch(
		session: GameSession,
		definition: GroundDamageAreaDefinition,
		source: Node,
		position: Vector2
) -> GroundDamageArea:
	var patch := GroundDamageArea.new()
	session.projectiles.add_child(patch)
	patch.global_position = position
	patch.set_process(false)
	patch.setup(definition, source, &"player", 1.0, 1.0)
	return patch


func _count_ground_areas(session: GameSession) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is GroundDamageArea:
			count += 1
	return count


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
