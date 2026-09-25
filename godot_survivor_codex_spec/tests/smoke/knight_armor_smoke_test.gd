## T22：骑士盔甲专项回归。
##
## 覆盖固定减伤与基础防御叠加、0%/100% 免伤边界、配置上限钳制、
## 免伤不触发反伤、与反伤刺甲互斥，以及专属升级。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"
const THORN_PATH := "res://data/upgrades/armor_thorns.tres"
const KNIGHT_PATH := "res://data/upgrades/armor_knight.tres"
const KNIGHT_DEFENSE_UP_PATH := "res://data/upgrades/armor_knight_defense_up.tres"
const KNIGHT_IMMUNE_UP_PATH := "res://data/upgrades/armor_knight_immune_up.tres"
const ARMOR_BASE_UP_PATH := "res://data/upgrades/armor_basic_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reduction_stacking()
	await _test_zero_immune_boundary()
	await _test_immune_cap_and_100_boundary()
	await _test_immune_no_reflect()
	await _test_mutual_exclusion()
	if not _failed:
		print("Knight armor smoke test passed: reduction, immune bounds, cap and exclusion are valid.")
	quit(1 if _failed else 0)


## 固定减伤与基础盔甲防御叠加进统一管线。
func _test_reduction_stacking() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(600.0, 0.0))
	_enable_knight(player)
	# 固定伤害断言需要确定性，关闭骑士自带的概率免伤。
	player.set_immune_chance(0.0)
	_expect(is_equal_approx(player.get_defense(), 17.0), "骑士盔甲后防御应为 11+6=17。")

	var before: float = player.health_component.current_health
	player.apply_damage(DamageEvent.new(30.0, enemy, Vector2.ZERO))
	_expect(
		is_equal_approx(before - player.health_component.current_health, 13.0),
		"30 点攻击在防御 17 下应扣 13。"
	)

	for _index: int in range(3):
		player.apply_upgrade(load(KNIGHT_DEFENSE_UP_PATH) as UpgradeDefinition)
	_expect(is_equal_approx(player.get_defense(), 26.0), "三级坚壁后防御应为 26。")
	var before_second: float = player.health_component.current_health
	player.apply_damage(DamageEvent.new(30.0, enemy, Vector2.ZERO))
	_expect(
		is_equal_approx(before_second - player.health_component.current_health, 4.0),
		"防御 26 时 30 点攻击应扣 4。"
	)
	await _free_node(main_node)


## 未选骑士时免伤为 0，攻击正常扣血。
func _test_zero_immune_boundary() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(600.0, 0.0))
	_expect(is_equal_approx(player.get_immune_chance(), 0.0), "初始完全免伤应为 0。")
	var before: float = player.health_component.current_health
	player.apply_damage(DamageEvent.new(10.0, enemy, Vector2.ZERO))
	_expect(player.health_component.current_health < before, "无免伤时应正常扣血。")
	await _free_node(main_node)


## 免伤概率受 CombatRules 上限钳制；上限放开后可到 100% 完全免伤。
func _test_immune_cap_and_100_boundary() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_knight(player)
	player.add_immune_chance(1.0)
	_expect(is_equal_approx(player.get_immune_chance(), 0.5), "默认规则下免伤应钳制到 0.5。")

	var rules := CombatRules.new()
	rules.max_immune_chance = 1.0
	player.set_combat_rules(rules)
	player.set_immune_chance(1.0)
	_expect(is_equal_approx(player.get_immune_chance(), 1.0), "上限放开后应可到 100%。")

	var enemy: EnemyActor = _spawn_dummy(session, Vector2(600.0, 0.0))
	var before: float = player.health_component.current_health
	var immune_count: Array[int] = [0]
	player.damage_immune.connect(func(_event: DamageEvent) -> void: immune_count[0] += 1)
	player.apply_damage(DamageEvent.new(50.0, enemy, Vector2.ZERO))
	_expect(is_equal_approx(player.health_component.current_health, before), "100% 免伤应完全不扣血。")
	_expect(immune_count[0] == 1, "完全免伤应触发一次免疫信号。")
	await _free_node(main_node)


## 免伤时不触发反伤，也不错误扣血。
func _test_immune_no_reflect() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var enemy: EnemyActor = _spawn_dummy(session, Vector2(600.0, 0.0))
	_enable_knight(player)
	player.set_damage_reflect_ratio(0.5)
	var rules := CombatRules.new()
	rules.max_immune_chance = 1.0
	rules.max_damage_reflect_ratio = 1.0
	player.set_combat_rules(rules)
	player.set_immune_chance(1.0)

	var player_before: float = player.health_component.current_health
	var enemy_before: float = enemy.health_component.current_health
	player.apply_damage(DamageEvent.new(50.0, enemy, Vector2.ZERO))
	_expect(is_equal_approx(player.health_component.current_health, player_before), "免伤不应扣血。")
	_expect(is_equal_approx(enemy.health_component.current_health, enemy_before), "免伤不应触发反伤。")
	await _free_node(main_node)


## 骑士盔甲与反伤刺甲互斥。
func _test_mutual_exclusion() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	_enable_knight(player)
	_expect(
		not session.upgrade_system.can_offer(load(THORN_PATH) as UpgradeDefinition),
		"已选骑士盔甲后不应再出现反伤刺甲。"
	)
	await _free_node(main_node)

	var second_node: Node = await _spawn_main()
	var second_session: GameSession = second_node.get_node("GameSession") as GameSession
	var second_player: PlayerActor = _prepare(second_session)
	_enable_thorns(second_player)
	_expect(
		not second_session.upgrade_system.can_offer(load(KNIGHT_PATH) as UpgradeDefinition),
		"已选反伤刺甲后不应再出现骑士盔甲。"
	)
	await _free_node(second_node)


func _enable_knight(player: PlayerActor) -> void:
	_expect(player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition), "应能装备基础盔甲。")
	var base_up: UpgradeDefinition = load(ARMOR_BASE_UP_PATH) as UpgradeDefinition
	for _index: int in range(4):
		_expect(player.apply_upgrade(base_up), "基础盔甲强化应成功。")
	_expect(player.apply_upgrade(load(KNIGHT_PATH) as UpgradeDefinition), "应能选择骑士盔甲。")


func _enable_thorns(player: PlayerActor) -> void:
	_expect(player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition), "应能装备基础盔甲。")
	var base_up: UpgradeDefinition = load(ARMOR_BASE_UP_PATH) as UpgradeDefinition
	for _index: int in range(4):
		_expect(player.apply_upgrade(base_up), "基础盔甲强化应成功。")
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
