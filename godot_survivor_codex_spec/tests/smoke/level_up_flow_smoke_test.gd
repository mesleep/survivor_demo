## P3-03 主场景连续升级、暂停 UI、重复点击防护与 HUD 烟雾检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false
var _applied_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	for controller: WeaponController in session.player.weapon_controllers:
		controller.set_process(false)
	session.upgrade_system.upgrade_applied.connect(_on_upgrade_applied)

	session.player.add_experience(22)
	_expect(paused, "达到升级阈值后场景树未暂停。")
	_expect(session.player.get_current_level() == 3, "大量经验未连续升级。")
	_expect(session.player.get_current_level_experience() == 3, "连续升级剩余经验不正确。")
	_expect(session.player.get_pending_upgrade_count() == 1, "首个选择显示后待升级队列不正确。")
	_expect(session.level_up_panel.visible, "升级面板未显示。")
	_expect(session.level_up_panel.process_mode == Node.PROCESS_MODE_ALWAYS, "升级 UI 暂停时不可处理输入。")
	_expect(session.level_up_panel.choices_container.get_child_count() == 3, "升级面板未生成三个按钮。")
	_expect(session.hud.level_label.text == "Level 3", "HUD 等级显示未更新。")
	_expect(roundi(session.hud.experience_bar.value) == 3 and roundi(session.hud.experience_bar.max_value) == 14, "HUD 经验条未更新。")
	_expect(session.hud.health_bar.custom_minimum_size.is_equal_approx(Vector2(390.0, 23.4)), "HUD 未应用 GameSession.ui_scale。")

	var first_choice: UpgradeDefinition = session.upgrade_system.get_current_choices()[0]
	var first_button: Button = session.level_up_panel.choices_container.get_child(0) as Button
	first_button.pressed.emit()
	_expect(not session.upgrade_system.apply_choice(first_choice), "按钮提交后同一选择仍可重复应用。")
	await process_frame
	_expect(paused, "连续升级的第二次选择前错误恢复了游戏。")
	_expect(session.player.get_pending_upgrade_count() == 0, "第二次选择显示后队列未正确消费。")
	_expect(session.level_up_panel.visible and session.level_up_panel.choices_container.get_child_count() == 3, "连续升级未显示下一组三选一。")
	var scaled_button: Button = session.level_up_panel.choices_container.get_child(0) as Button
	_expect(scaled_button.custom_minimum_size.is_equal_approx(Vector2(546.0, 83.2)), "升级面板未应用 GameSession.ui_scale。")

	var second_button: Button = session.level_up_panel.choices_container.get_child(0) as Button
	second_button.pressed.emit()
	await process_frame
	_expect(not paused, "完成全部升级选择后游戏未恢复。")
	_expect(not session.level_up_panel.visible, "完成选择后升级面板未隐藏。")
	_expect(_applied_count == 2, "连续升级未恰好应用两次选择。")

	if not _failed:
		print("Level-up flow smoke test passed: pause, UI, queue, HUD, and resume are valid.")
	quit(1 if _failed else 0)


func _on_upgrade_applied(_definition: UpgradeDefinition) -> void:
	_applied_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
