## T32：基础剑与近战扇形专项回归。
##
## 覆盖攻击形态与射程、扇形内多目标各命中一次、扇形外与超距不命中、
## 不生成弹体、基础升级与重开清理。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const ENEMY_SCENE_PATH := "res://scenes/actors/enemies/enemy_basic.tscn"
const SWORD_PATH := "res://data/weapons/sword.tres"
const SWORD_BASE_PATH := "res://data/upgrades/sword_base.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_melee_fan_hit_and_angle()
	await _test_base_upgrade_and_restart()
	if not _failed:
		print("Sword melee smoke test passed: fan hit, angle/range filter, single hit and cleanup are valid.")
	quit(1 if _failed else 0)


## 扇形内目标各命中一次，扇形外与超距不命中，且不生成弹体。
func _test_melee_fan_hit_and_angle() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	var sword: WeaponDefinition = load(SWORD_PATH) as WeaponDefinition
	_expect(player.add_weapon(sword), "应能装备铁剑。")
	var controller: WeaponController = _find_controller(player, &"sword")
	controller.set_process(false)
	_expect(
		controller.definition.attack_mode == WeaponDefinition.AttackMode.MELEE_FAN,
		"铁剑应为近战形态。"
	)
	_expect(
		is_equal_approx(controller.get_effective_target_range(), 130.0),
		"铁剑有效索敌射程应为 130。"
	)

	var front: EnemyActor = _spawn_dummy(session, Vector2(100.0, 0.0))
	var side: EnemyActor = _spawn_dummy(session, Vector2(100.0, 60.0))
	var behind: EnemyActor = _spawn_dummy(session, Vector2(-100.0, 0.0))
	var far: EnemyActor = _spawn_dummy(session, Vector2(300.0, 0.0))
	await physics_frame
	await physics_frame

	_expect(controller.request_fire(front), "铁剑应能斩击。")
	_expect(is_equal_approx(front.health_component.current_health, 486.0), "正前方目标应受 14 点。")
	_expect(is_equal_approx(side.health_component.current_health, 486.0), "扇形内目标应受 14 点。")
	_expect(is_equal_approx(behind.health_component.current_health, 500.0), "身后目标不应被斩中。")
	_expect(is_equal_approx(far.health_component.current_health, 500.0), "超距目标不应被斩中。")
	_expect(session.projectiles.get_child_count() == 0, "近战不应生成弹体。")
	await _free_node(main_node)


## 基础升级提升近战伤害；清理武器后无残留。
func _test_base_upgrade_and_restart() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = _prepare(session)
	player.add_weapon(load(SWORD_PATH) as WeaponDefinition)
	var controller: WeaponController = _find_controller(player, &"sword")
	controller.set_process(false)
	var base_up: UpgradeDefinition = load(SWORD_BASE_PATH) as UpgradeDefinition
	for _index: int in range(base_up.max_stacks):
		_expect(player.apply_upgrade(base_up), "铁剑基础升级应成功。")
	var expected_multiplier: float = pow(1.12, 4.0)
	_expect(
		is_equal_approx(controller.get_runtime_damage_multiplier(), expected_multiplier),
		"四级开锋应为 1.12⁴。"
	)

	var enemy: EnemyActor = _spawn_dummy(session, Vector2(100.0, 0.0))
	await physics_frame
	await physics_frame
	controller.request_fire(enemy)
	_expect(
		is_equal_approx(enemy.health_component.current_health, 500.0 - 14.0 * expected_multiplier),
		"升级后单次斩击应受 14×1.12⁴。"
	)

	player.clear_weapons()
	_expect(_find_controller(player, &"sword") == null, "清理后不应有铁剑控制器。")
	await _free_node(main_node)


func _prepare(session: GameSession) -> PlayerActor:
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	for controller: WeaponController in player.weapon_controllers:
		controller.set_process(false)
	_clear_container(session.enemies)
	_clear_container(session.projectiles)
	return player


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
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
