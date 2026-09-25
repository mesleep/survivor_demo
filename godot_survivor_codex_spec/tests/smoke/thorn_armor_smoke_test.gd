## T21：反伤刺甲专项回归。
##
## 覆盖刺圈周期/范围、受击按实际伤害返还、零伤害与闪避不返伤、反伤不递归、
## 专属升级独立上限，以及重新初始化清理。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"
const THORN_PATH := "res://data/upgrades/armor_thorns.tres"
const RADIUS_UP_PATH := "res://data/upgrades/armor_thorns_radius_up.tres"
const REFLECT_UP_PATH := "res://data/upgrades/armor_thorns_reflect_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_aura_tick_and_range()
	await _test_hit_reflect_actual_damage()
	await _test_zero_and_dodged_no_reflect()
	await _test_aura_not_reflected_back()
	await _test_exclusive_upgrades_and_limits()
	await _test_reinitialize_clears()
	if not _failed:
		print("Thorn armor smoke test passed: aura, reflect, limits and cleanup are valid.")
	quit(1 if _failed else 0)


## 刺圈按 0.5 秒周期伤害范围内敌人，范围外不受影响。
func _test_aura_tick_and_range() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var inside: EnemyActor = _spawn_dummy(session, Vector2(30.0, 0.0))
	var outside: EnemyActor = _spawn_dummy(session, Vector2(200.0, 0.0))
	_enable_thorns(player)
	var aura: ThornAuraComponent = player.get_thorn_aura()
	aura.set_process(false)
	await physics_frame

	aura.advance_time(0.5)
	_expect(is_equal_approx(inside.health_component.current_health, 496.0), "范围内敌人应受 4 点刺圈伤害。")
	_expect(
		is_equal_approx(outside.health_component.current_health, 500.0),
		"范围外敌人不应受刺圈伤害。"
	)
	_expect(aura.get_tick_count() == 1, "0.5 秒应结算 1 次。")
	aura.advance_time(0.5)
	_expect(is_equal_approx(inside.health_component.current_health, 492.0), "1 秒应累计 8 点。")
	await _free_node(main_node)


## 受击返还按“实际扣血”的比例计算，并打上 reflect 标签。
func _test_hit_reflect_actual_damage() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(600.0, 0.0))
	_enable_thorns(player)
	_expect(is_equal_approx(player.get_damage_reflect_ratio(), 0.3), "刺甲应设置 30% 返还。")

	var player_before: float = player.health_component.current_health
	var enemy_before: float = enemy.health_component.current_health
	player.apply_damage(DamageEvent.new(20.0, enemy, Vector2.ZERO))
	var applied: float = player_before - player.health_component.current_health
	var reflected: float = enemy_before - enemy.health_component.current_health
	_expect(applied > 0.0, "玩家应受到实际伤害。")
	_expect(is_equal_approx(reflected, applied * 0.3), "返还应为实际伤害的 30%。")
	await _free_node(main_node)


## 零伤害不返伤；闪避时同样不返伤。
func _test_zero_and_dodged_no_reflect() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(600.0, 0.0))
	_enable_thorns(player)

	var enemy_before: float = enemy.health_component.current_health
	player.apply_damage(DamageEvent.new(0.0, enemy, Vector2.ZERO))
	_expect(
		is_equal_approx(enemy.health_component.current_health, enemy_before),
		"零伤害不应返还。"
	)

	var rules := CombatRules.new()
	rules.max_dodge_chance = 1.0
	player.set_combat_rules(rules)
	player.add_dodge_chance(1.0)
	var enemy_before_dodge: float = enemy.health_component.current_health
	player.apply_damage(DamageEvent.new(20.0, enemy, Vector2.ZERO))
	_expect(is_equal_approx(enemy.health_component.current_health, enemy_before_dodge), "闪避不应返还伤害。")
	await _free_node(main_node)


## 刺圈带 reflect 标签，不会引起敌人反伤回玩家。
func _test_aura_not_reflected_back() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(30.0, 0.0))
	enemy.set_damage_reflect_ratio(1.0)
	_enable_thorns(player)
	var aura: ThornAuraComponent = player.get_thorn_aura()
	aura.set_process(false)
	await physics_frame

	var player_before: float = player.health_component.current_health
	aura.advance_time(0.5)
	_expect(enemy.health_component.current_health < 500.0, "刺圈应伤害敌人。")
	_expect(
		is_equal_approx(player.health_component.current_health, player_before),
		"刺圈伤害不应被敌人反伤回玩家。"
	)
	await _free_node(main_node)


## 范围与返还专属升级独立上限；已选刺甲后不再出现。
func _test_exclusive_upgrades_and_limits() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_thorns(player)
	var aura: ThornAuraComponent = player.get_thorn_aura()

	var radius_up: UpgradeDefinition = load(RADIUS_UP_PATH) as UpgradeDefinition
	var reflect_up: UpgradeDefinition = load(REFLECT_UP_PATH) as UpgradeDefinition
	for _index: int in range(radius_up.max_stacks):
		_expect(player.apply_upgrade(radius_up), "扩刺升级应成功。")
	for _index: int in range(reflect_up.max_stacks):
		_expect(player.apply_upgrade(reflect_up), "锐刺升级应成功。")

	_expect(
		is_equal_approx(aura.get_effective_radius(), 90.0 * 1.2 * 1.2 * 1.2),
		"三级扩刺应为 90×1.2³。"
	)
	_expect(
		is_equal_approx(player.get_damage_reflect_ratio(), 0.6),
		"三级锐刺应为 0.3+0.3=0.6。"
	)
	_expect(not session.upgrade_system.can_offer(radius_up), "扩刺达上限后不应再出现。")
	_expect(not session.upgrade_system.can_offer(reflect_up), "锐刺达上限后不应再出现。")
	_expect(
		not session.upgrade_system.can_offer(load(THORN_PATH) as UpgradeDefinition),
		"已选反伤刺甲后不应再次出现。"
	)
	await _free_node(main_node)


## 重新初始化应清空刺圈与返还比例。
func _test_reinitialize_clears() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_thorns(player)
	_expect(player.get_thorn_aura() != null, "应先有刺圈。")
	player.initialize(player.definition)
	_expect(player.get_thorn_aura() == null, "重新初始化应移除刺圈。")
	_expect(is_equal_approx(player.get_damage_reflect_ratio(), 0.0), "重新初始化应清空返还比例。")
	await _free_node(main_node)


func _enable_thorns(player: PlayerActor) -> void:
	_expect(player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition), "应能装备基础盔甲。")
	for _index: int in range(4):
		player.add_equipment_base_level(&"armor_basic")
	_expect(player.apply_upgrade(load(THORN_PATH) as UpgradeDefinition), "应能选择反伤刺甲。")


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
