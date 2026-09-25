## T10：防御、闪避、免疫、反伤伤害结算基座专项回归。
##
## 覆盖防御公式与下限、零/负伤害、确定性命中闪避/免疫、提示标签、
## 反伤按实际伤害返还、reflect/dot 防递归，以及旧伤害回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_defense_formula()
	await _test_dodge_and_immune()
	await _test_reflect()
	if not _failed:
		print("Damage resolution smoke test passed: defense, dodge, immune and reflect are valid.")
	quit(1 if _failed else 0)


func _test_defense_formula() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var health_before: float = player.health_component.current_health

	player.set_defense(5.0)
	var result: DamageResult = player.apply_damage(DamageEvent.new(20.0, null, Vector2.ZERO))
	_expect(is_equal_approx(result.applied_amount, 15.0), "防御 5 时 20 伤害应剩 15。")
	_expect(is_equal_approx(result.blocked_amount, 5.0), "被减免伤害应为 5。")
	_expect(is_equal_approx(player.health_component.current_health, health_before - 15.0), "实际扣血不正确。")

	# 防御极高时保留 10% 下限。
	player.set_defense(1000.0)
	var floored: DamageResult = player.apply_damage(DamageEvent.new(20.0, null, Vector2.ZERO))
	_expect(is_equal_approx(floored.applied_amount, 2.0), "防御下限应为原始 10%。")

	# 零/负伤害不结算。
	var hp: float = player.health_component.current_health
	var zero: DamageResult = player.apply_damage(DamageEvent.new(0.0, null, Vector2.ZERO))
	_expect(is_equal_approx(zero.applied_amount, 0.0), "零伤害不应扣血。")
	_expect(is_equal_approx(player.health_component.current_health, hp), "零伤害改变了生命。")
	await _free_node(main_node)


func _test_dodge_and_immune() -> void:
	# 闪避：100% 触发，不扣血且有“闪避”提示。
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var rules := CombatRules.new()
	rules.max_dodge_chance = 1.0
	rules.max_immune_chance = 1.0
	player.set_combat_rules(rules)
	player.add_dodge_chance(1.0)
	var dodge_signals: Array[int] = [0]
	player.damage_dodged.connect(func(_event: DamageEvent) -> void: dodge_signals[0] += 1)
	var hp: float = player.health_component.current_health
	var dodge_result: DamageResult = player.apply_damage(DamageEvent.new(20.0, null, Vector2.ZERO))
	_expect(dodge_result.is_dodged, "100% 闪避应命中闪避分支。")
	_expect(is_equal_approx(player.health_component.current_health, hp), "闪避不应扣血。")
	_expect(dodge_signals[0] == 1, "闪避信号应触发一次。")
	_expect(_has_label(player, "闪避"), "闪避应显示提示。")
	await _free_node(main_node)

	# 免疫：100% 触发，不扣血且有“免疫”提示。
	var main_node_b: Node = await _spawn_main()
	var session_b: GameSession = main_node_b.get_node("GameSession") as GameSession
	session_b.enemy_spawner.stop()
	var player_b: PlayerActor = session_b.player
	var rules_b := CombatRules.new()
	rules_b.max_immune_chance = 1.0
	player_b.set_combat_rules(rules_b)
	player_b.add_immune_chance(1.0)
	var immune_signals: Array[int] = [0]
	player_b.damage_immune.connect(func(_event: DamageEvent) -> void: immune_signals[0] += 1)
	player_b.set_defense(5.0)
	var hp_b: float = player_b.health_component.current_health
	var immune_result: DamageResult = player_b.apply_damage(DamageEvent.new(20.0, null, Vector2.ZERO))
	_expect(immune_result.is_immune, "100% 免疫应命中免疫分支。")
	_expect(is_equal_approx(player_b.health_component.current_health, hp_b), "免疫不应扣血。")
	_expect(immune_signals[0] == 1, "免疫信号应触发一次。")
	_expect(_has_label(player_b, "免疫"), "免疫应显示提示。")
	await _free_node(main_node_b)


func _test_reflect() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	player.set_damage_reflect_ratio(0.5)
	var enemy: EnemyActor = _spawn_dummy(session)
	if enemy == null:
		_expect(false, "未能生成测试敌人。")
		await _free_node(main_node)
		return
	var enemy_hp_before: float = enemy.health_component.current_health
	var player_hp_before: float = player.health_component.current_health
	var result: DamageResult = player.apply_damage(DamageEvent.new(20.0, enemy, enemy.global_position))
	_expect(is_equal_approx(result.applied_amount, 20.0), "无防御时击杀应扣满 20。")
	_expect(
		is_equal_approx(enemy.health_component.current_health, enemy_hp_before - 10.0),
		"反伤应按实际伤害 50% 返还 10 点。"
	)

	# 攻击者也带反伤时，reflect 标签阻止递归，玩家不再二次扣血。
	enemy.add_damage_reflect_ratio(0.5)
	var player_hp_before_second: float = player.health_component.current_health
	player.apply_damage(DamageEvent.new(20.0, enemy, enemy.global_position))
	_expect(
		is_equal_approx(player.health_component.current_health, player_hp_before_second - 20.0),
		"反伤递归未收敛，玩家被额外扣血。"
	)

	# dot 标签不触发反伤。
	var enemy_hp_before_dot: float = enemy.health_component.current_health
	var dot_event := DamageEvent.new(10.0, enemy, enemy.global_position)
	dot_event.tags = [&"dot"]
	player.apply_damage(dot_event)
	_expect(
		is_equal_approx(enemy.health_component.current_health, enemy_hp_before_dot),
		"持续伤害不应触发反伤。"
	)

	await _free_node(main_node)


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _spawn_dummy(session: GameSession) -> EnemyActor:
	var definition := EnemyDefinition.new()
	definition.id = &"test_dummy"
	definition.display_name = "Dummy"
	definition.scene = load(ENEMY_SCENE_PATH) as PackedScene
	definition.max_health = 200.0
	definition.contact_damage = 0.0
	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(
		definition, session.player.global_position + Vector2(60.0, 0.0), true
	)
	if enemy != null:
		enemy.set_physics_process(false)
	return enemy


func _has_label(node: Node, text: String) -> bool:
	for child: Node in node.get_children():
		if child is Label and (child as Label).text == text:
			return true
	return false


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
