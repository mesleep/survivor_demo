## P4-04/P4-05 十分钟 Boss 单次生成与胜利结算烟雾检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _boss_signal_count: int = 0
var _end_signal_count: int = 0
var _last_result: GameResult


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_clear_children(session.enemies)
	await process_frame
	session.boss_spawned.connect(_on_boss_spawned)
	session.run_ended.connect(_on_run_ended)

	session.advance_time(599.0)
	_expect(not session.boss_has_spawned, "十分钟前不应生成 Boss。")
	session.advance_time(1.0)
	_expect(session.boss_has_spawned and is_instance_valid(session.boss), "10 分钟未生成 Boss。")
	_expect(_boss_signal_count == 1, "Boss 生成信号未恰好触发一次。")
	_expect(not session.enemy_spawner.spawn_timer.is_stopped(), "Boss 出现后小怪应继续刷新。")
	_expect(session.hud.time_label.text == "00:00", "Boss 出现时 HUD 未显示 00:00。")
	var boss: EnemyActor = session.boss
	_expect(boss.definition.is_boss and boss.definition.scene.resource_path.ends_with("boss.tscn"), "Boss 未使用独立场景和 Resource。")
	session.advance_time(10.0)
	_expect(_boss_signal_count == 1 and session.boss == boss, "时间结束后重复生成 Boss。")

	boss.apply_damage(DamageEvent.new(boss.health_component.maximum_health, session.player, session.player.global_position))
	_expect(not session.is_run_active and paused, "Boss 死亡后本局未停止并暂停。")
	_expect(_end_signal_count == 1 and _last_result.outcome == GameResult.Outcome.VICTORY, "Boss 死亡未生成胜利结果。")
	_expect(session.end_panel.visible and session.end_panel.title.text == "庭院守护成功", "胜利结算面板未显示。")
	_expect(_last_result.kill_count == 1 and session.kill_count == 1, "Boss 击杀统计不正确。")

	paused = false
	if not _failed:
		print("Boss victory smoke test passed: ten-minute spawn, single boss, victory, and stats are valid.")
	quit(1 if _failed else 0)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()


func _on_boss_spawned(_boss: EnemyActor) -> void:
	_boss_signal_count += 1


func _on_run_ended(result: GameResult) -> void:
	_end_signal_count += 1
	_last_result = result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
