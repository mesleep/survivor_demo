## P2-05 敌人死亡、经验掉落与连续拾取集成烟雾检查。
##
## 验证 EnemyDefinition 数值、死亡位置、单次掉落、玩家信号及连续 100 次击杀。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const STRESS_KILL_COUNT := 100

var _failed: bool = false
var _experience_signal_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	_expect(main_scene != null, "无法加载主场景。")
	if main_scene == null:
		quit(1)
		return

	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	var game_session: GameSession = main_node.get_node_or_null("GameSession") as GameSession
	_expect(game_session != null, "主场景缺少 GameSession。")
	if game_session == null:
		quit(1)
		return
	game_session.enemy_spawner.stop()
	for controller: WeaponController in game_session.player.weapon_controllers:
		controller.set_process(false)
	_clear_children(game_session.enemies)
	_clear_children(game_session.pickups)
	await process_frame

	var player: PlayerActor = game_session.player
	player.experience_changed.connect(_on_experience_changed)
	# P2-05 专项仍需跨越等级阈值验证 100 次拾取；自动提交升级，避免 P3 暂停阻断物理帧。
	game_session.upgrade_system.choices_ready.connect(_on_upgrade_choices_ready.bind(game_session.upgrade_system))
	var enemy_definition: EnemyDefinition = game_session.enemy_spawn_settings.enemy_definition
	var death_position := Vector2(220.0, 40.0)
	var enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(enemy_definition, death_position)
	_expect(enemy != null, "无法创建经验掉落验收敌人。")
	if enemy == null:
		quit(1)
		return
	enemy.set_physics_process(false)
	var lethal_event := DamageEvent.new(enemy.health_component.maximum_health, player, player.global_position)
	enemy.apply_damage(lethal_event)
	enemy.apply_damage(lethal_event)
	await process_frame
	_expect(game_session.pickups.get_child_count() == 1, "一次敌人死亡未生成且只生成一颗经验宝石。")
	if game_session.pickups.get_child_count() != 1:
		quit(1)
		return
	var gem: ExperienceGem = game_session.pickups.get_child(0) as ExperienceGem
	_expect(gem != null, "掉落节点不是 ExperienceGem。")
	_expect(gem.get_experience_value() == enemy_definition.experience_value, "宝石未携带 EnemyDefinition.experience_value。")
	_expect(gem.global_position.is_equal_approx(death_position), "经验宝石未在敌人死亡位置生成。")

	player.global_position = death_position
	player.force_update_transform()
	player.pickup_component.force_update_transform()
	await physics_frame
	await physics_frame
	await process_frame
	_expect(player.get_current_experience() == enemy_definition.experience_value, "玩家接近掉落物后经验累加不正确。")
	_expect(_experience_signal_count == 1, "一次拾取未恰好触发一次经验变化信号。")
	_expect(game_session.pickups.get_child_count() == 0, "拾取后的经验宝石仍残留在容器中。")

	for index: int in range(STRESS_KILL_COUNT):
		var stress_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(enemy_definition, player.global_position)
		_expect(stress_enemy != null, "连续击杀第 %d 个敌人生成失败。" % (index + 1))
		if stress_enemy == null:
			break
		stress_enemy.set_physics_process(false)
		stress_enemy.apply_damage(DamageEvent.new(stress_enemy.health_component.maximum_health, player, player.global_position))
		await physics_frame
		await physics_frame
		await process_frame

	var expected_experience: int = enemy_definition.experience_value * (STRESS_KILL_COUNT + 1)
	_expect(player.get_current_experience() == expected_experience, "连续 100 次击杀后经验总值不正确。")
	_expect(_experience_signal_count == STRESS_KILL_COUNT + 1, "连续拾取出现丢失或重复经验信号。")
	_expect(game_session.enemies.get_child_count() == 0, "连续击杀后敌人节点未清理。")
	_expect(game_session.pickups.get_child_count() == 0, "连续拾取后经验宝石节点未清理。")

	if not _failed:
		print("Experience flow smoke test passed: death drop, pickup, signal, and 100 kills are valid.")
	quit(1 if _failed else 0)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()


func _on_experience_changed(_current_experience: int, _gained_amount: int) -> void:
	_experience_signal_count += 1


func _on_upgrade_choices_ready(choices: Array[UpgradeDefinition], upgrade_system: UpgradeSystem) -> void:
	if not choices.is_empty():
		upgrade_system.apply_choice(choices[0])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
