## P4-02 高密度阶段生成上限与稳定性快速检查。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.player.health_component.initialize(1000000.0)
	for controller: WeaponController in session.player.weapon_controllers:
		controller.set_process(false)
	session.advance_time(240.0)
	var maximum: int = session.enemy_spawner.get_runtime_max_alive_enemies()
	_expect(maximum == 160 and session.enemy_spawner.get_runtime_batch_size() == 4, "4:00 高密度阶段参数不正确。")

	for _batch: int in range(60):
		session.enemy_spawner.spawn_batch()
	_expect(session.enemy_spawner.get_enemy_count() == maximum, "高密度阶段未稳定在动态数量上限。")
	_expect(session.enemy_spawner.spawn_batch().is_empty(), "达到动态上限后仍可继续生成。")
	await process_frame
	_expect(session.enemy_spawner.get_enemy_count() <= maximum, "物理帧后敌人数超过动态上限。")

	if not _failed:
		print("Difficulty density smoke test passed: high-density batch and dynamic cap are stable.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
