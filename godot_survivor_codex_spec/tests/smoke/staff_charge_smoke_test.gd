## T15：蓄力法杖蓄力/冷却、重复请求与取消专项回归。
##
## 用固定蓄力时长的临时武器驱动，避免 headless 帧时长波动导致计时不确定。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ORB_PATH := "res://data/projectiles/staff_orb.tres"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_charge_and_release()
	await _test_reset_cancels()
	await _test_target_disappears()
	if not _failed:
		print("Staff charge smoke test passed: charge, cooldown, repeat request and cancel are valid.")
	quit(1 if _failed else 0)


func _test_charge_and_release() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var staff: WeaponDefinition = _make_charge_weapon()
	_expect(player.add_weapon(staff), "应能装备蓄力法杖。")
	var controller: WeaponController = _find_controller(player, &"test_staff")
	_only_enable(player, &"test_staff")
	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(200.0, 0.0))

	await create_timer(0.3).timeout
	_expect(controller.is_charging(), "应已进入蓄力。")
	_expect(session.projectiles.get_child_count() == 0, "蓄力期间不应发射。")
	var remaining_before: float = controller.get_charge_remaining()
	_expect(not controller.begin_charge(enemy), "蓄力中重复请求应被拒绝。")
	_expect(controller.get_charge_remaining() <= remaining_before, "重复请求重置了蓄力进度。")

	await create_timer(1.0).timeout
	_expect(session.projectiles.get_child_count() >= 1, "蓄力完成后应发射法球。")
	_expect(not controller.is_charging(), "释放后应结束蓄力。")
	_expect(not controller.can_fire(), "释放后应进入冷却。")
	var orb: ProjectileBase = _first_projectile(session)
	_expect(orb != null and is_equal_approx(orb.context.damage_multiplier, 2.0), "蓄力伤害倍率应为 2.0。")
	await _free_node(main_node)


func _test_reset_cancels() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	player.add_weapon(_make_charge_weapon())
	var controller: WeaponController = _find_controller(player, &"test_staff")
	_only_enable(player, &"test_staff")
	_spawn_dummy(session, player.global_position + Vector2(200.0, 0.0))
	await create_timer(0.3).timeout
	_expect(controller.is_charging(), "应已进入蓄力。")
	controller.reset_runtime_state()
	_expect(not controller.is_charging(), "重置应取消蓄力。")
	_expect(controller.get_charge_remaining() < 0.0, "重置后蓄力进度应清空。")
	_expect(session.projectiles.get_child_count() == 0, "重置瞬间不应有法球。")
	await _free_node(main_node)


func _test_target_disappears() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	player.add_weapon(_make_charge_weapon())
	var controller: WeaponController = _find_controller(player, &"test_staff")
	_only_enable(player, &"test_staff")
	var enemy: EnemyActor = _spawn_dummy(session, player.global_position + Vector2(200.0, 0.0))
	await create_timer(0.3).timeout
	_expect(controller.is_charging(), "应已进入蓄力。")
	enemy.queue_free()
	await create_timer(1.0).timeout
	_expect(session.projectiles.get_child_count() >= 1, "目标消失后应按最后位置释放。")
	await _free_node(main_node)


func _make_charge_weapon() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.id = &"test_staff"
	weapon.display_name = "Test Staff"
	weapon.projectile_definition = load(ORB_PATH) as ProjectileDefinition
	weapon.cooldown_seconds = 2.0
	weapon.projectile_count = 1
	weapon.target_range = 1200.0
	weapon.charge_seconds = 1.0
	weapon.charge_damage_multiplier = 2.0
	return weapon


func _only_enable(player: PlayerActor, weapon_id: StringName) -> void:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller):
			controller.set_process(controller.definition.id == weapon_id)


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
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


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _first_projectile(session: GameSession) -> ProjectileBase:
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase:
			return child as ProjectileBase
	return null


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
