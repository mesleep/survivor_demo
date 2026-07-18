## P1-03 敌人追踪烟雾检查。
##
## 启动真实主场景，验证敌人 Resource 注入、直线追踪、碰撞层，
## 以及玩家引用失效后的安全停止行为。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const EXPECTED_MOVE_SPEED := 80.0

var _failed: bool = false


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

	var player: PlayerActor = game_session.player
	var enemy: EnemyActor = game_session.enemies.get_child(0) as EnemyActor
	_expect(is_instance_valid(player), "GameSession 未创建 PlayerActor。")
	_expect(is_instance_valid(enemy), "GameSession 未创建基础 EnemyActor。")
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		quit(1)
		return

	_expect(enemy.definition == game_session.enemy_spawn_settings.enemy_definition, "EnemyActor 未使用 GameSession 注入的配置。")
	_expect(enemy.target_player == player, "EnemyActor 未获得玩家引用。")
	_expect(enemy.collision_layer == 4, "EnemyActor 未使用 EnemyBody 碰撞层。")
	_expect(enemy.collision_mask & 1 != 0, "EnemyActor 未检测 World 碰撞层。")
	_expect(enemy.collision_mask & 2 == 0, "EnemyActor 不应与 PlayerBody 产生实体阻挡。")
	_expect(enemy.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "EnemyActor 未使用俯视角 FLOATING 运动模式。")

	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(400.0, 0.0)
	await physics_frame
	await physics_frame
	_expect(enemy.global_position.x < 400.0, "EnemyActor 未向玩家移动。")
	_expect(is_equal_approx(enemy.velocity.length(), EXPECTED_MOVE_SPEED), "EnemyActor 未使用 Resource 中的移动速度。")
	_expect(game_session.enemies.get_child_count() == 1, "P1-03 应只创建一个验收敌人。")

	player.queue_free()
	await process_frame
	await physics_frame
	_expect(enemy.velocity == Vector2.ZERO, "玩家失效后 EnemyActor 未停止。")
	_expect(not enemy.is_physics_processing(), "玩家失效后 EnemyActor 仍在执行物理处理。")

	if not _failed:
		print("Enemy tracking smoke test passed: data, target injection, tracking, and safe stop are valid.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
