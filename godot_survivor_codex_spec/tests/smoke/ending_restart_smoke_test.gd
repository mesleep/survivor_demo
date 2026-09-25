## P4-05 玩家失败、结算 UI 与连续三次重开烟雾检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const RESTART_COUNT := 3

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	current_scene = main_node
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	session.advance_time(42.0)
	session.player.add_experience(8)
	var choices: Array[UpgradeDefinition] = session.upgrade_system.get_current_choices()
	if not choices.is_empty():
		session.upgrade_system.apply_choice(choices[0])
	await process_frame
	# 随机首卡可能是闪避/免疫升级；关闭概率免伤以保证致命伤害确定性。
	var rules := CombatRules.new()
	rules.max_dodge_chance = 0.0
	rules.max_immune_chance = 0.0
	session.player.set_combat_rules(rules)
	session.player.apply_damage(DamageEvent.new(session.player.health_component.maximum_health, null, Vector2.ZERO))
	_expect(not session.is_run_active and paused, "玩家死亡未结束并暂停本局。")
	_expect(session.end_panel.visible and session.end_panel.title.text == "休息一下，再来一局", "失败结算面板未显示。")
	_expect(session.end_panel.stats_label.text.contains("00:42") and session.end_panel.stats_label.text.contains("等级  2"), "结算统计未显示存活时间和等级。")

	for restart_index: int in range(RESTART_COUNT):
		var old_session_id: int = session.get_instance_id()
		var old_runtime_ids: Dictionary[int, bool] = _collect_runtime_ids(session)
		session.restart_run()
		await process_frame
		await process_frame
		main_node = current_scene
		if main_node == null:
			main_node = root.get_child(root.get_child_count() - 1)
		session = main_node.get_node("GameSession") as GameSession
		_expect(session.get_instance_id() != old_session_id, "第 %d 次重开未替换旧 GameSession。" % (restart_index + 1))
		_expect(session.is_run_active and not paused, "第 %d 次重开后本局未运行。" % (restart_index + 1))
		_expect(session.elapsed_seconds < 0.25 and session.kill_count == 0, "第 %d 次重开残留计时或击杀。" % (restart_index + 1))
		_expect(session.player.get_current_level() == 1 and session.player.get_current_experience() == 0, "第 %d 次重开残留等级或经验。" % (restart_index + 1))
		_expect(not _contains_old_runtime_node(session, old_runtime_ids), "第 %d 次重开残留旧敌人、子弹或掉落物。" % (restart_index + 1))
		_expect(not session.boss_has_spawned and not session.end_panel.visible, "第 %d 次重开残留 Boss 或结算 UI。" % (restart_index + 1))
		session.enemy_spawner.stop()

	if not _failed:
		print("Ending restart smoke test passed: defeat, result UI, and three clean restarts are valid.")
	quit(1 if _failed else 0)


func _collect_runtime_ids(session: GameSession) -> Dictionary[int, bool]:
	var ids: Dictionary[int, bool] = {}
	for parent: Node in [session.enemies, session.projectiles, session.pickups]:
		for child: Node in parent.get_children():
			ids[child.get_instance_id()] = true
	return ids


func _contains_old_runtime_node(session: GameSession, old_ids: Dictionary[int, bool]) -> bool:
	for parent: Node in [session.enemies, session.projectiles, session.pickups]:
		for child: Node in parent.get_children():
			if old_ids.has(child.get_instance_id()):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
