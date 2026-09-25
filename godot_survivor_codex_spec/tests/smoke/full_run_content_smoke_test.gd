## T35：完整一局（含新敌人与远程弹体）的端到端自动验收。
##
## 覆盖：推进到五分钟生成 Boss、击杀 Boss 胜利、结算一次、敌方弹体清理、
## 连续重开隔离。人工五分钟游玩不在此测试内，按验证协议另行标记。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const SHOOTER_PATH := "res://data/enemies/enemy_shooter.tres"
const BRUTE_PATH := "res://data/enemies/enemy_brute.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_full_run_victory_with_new_content()
	await _test_restart_isolated()
	if not _failed:
		print("Full run content smoke test passed: boss victory, new enemies, cleanup and restart are valid.")
	quit(1 if _failed else 0)


## 五分钟推进生成 Boss；期间新敌人可行动并发射弹体；击杀 Boss 胜利并清理。
func _test_full_run_victory_with_new_content() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	_clear_container(session.enemies)
	_clear_container(session.projectiles)

	# 手动放入新敌人，验证它们在同一局内正常工作。
	session.enemy_spawner.spawn_enemy(load(SHOOTER_PATH) as EnemyDefinition, Vector2(300.0, 0.0), true)
	session.enemy_spawner.spawn_enemy(load(BRUTE_PATH) as EnemyDefinition, Vector2(-300.0, 0.0), true)
	await physics_frame
	await physics_frame
	_expect(_count_projectiles(session, &"enemy_bolt") >= 1, "远程敌人应在真实单局内发射弹体。")

	# 推进到五分钟，Boss 生成。
	session.advance_time(session.run_definition.run_duration_seconds)
	_expect(session.boss_has_spawned and is_instance_valid(session.boss), "五分钟应生成 Boss。")

	var results: Array[GameResult] = []
	session.run_ended.connect(func(result: GameResult) -> void: results.append(result))
	session.boss.apply_damage(DamageEvent.new(session.boss.health_component.maximum_health, null, Vector2.ZERO))
	_expect(results.size() == 1 and results[0].outcome == GameResult.Outcome.VICTORY, "Boss 死亡应胜利结算一次。")
	_expect(not session.is_run_active and paused, "胜利后应结束并暂停。")
	_expect(_count_active_projectiles(session) == 0, "结算后敌方弹体应被清理。")
	await _free_node(main_node)


## 重开后应回到全新一局且无旧内容残留。
func _test_restart_isolated() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var old_id: int = session.get_instance_id()
	session.end_run(GameResult.Outcome.DEFEAT)
	await process_frame
	session.restart_run()
	await process_frame
	await process_frame
	main_node = current_scene
	if main_node == null:
		main_node = root.get_child(root.get_child_count() - 1)
	session = main_node.get_node("GameSession") as GameSession
	_expect(session.get_instance_id() != old_id, "重开应替换 GameSession。")
	_expect(session.is_run_active and not paused, "重开后应运行。")
	_expect(session.enemies.get_child_count() <= 1, "重开后不应残留大量敌人。")
	await _free_node(main_node)


func _count_projectiles(session: GameSession, definition_id: StringName) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == definition_id:
			count += 1
	return count


func _count_active_projectiles(session: GameSession) -> int:
	var count: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).is_active:
			count += 1
	return count


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	return main_node


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
