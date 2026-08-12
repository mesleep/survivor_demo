## P1-02 玩家移动烟雾检查。
##
## 启动真实主场景，验证数据注入、斜向速度归一化、Camera2D
## 和 World 边界碰撞。该脚本不修改游戏 Resource。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const EXPECTED_MOVE_SPEED := 220.0
const RIGHT_BOUNDARY_MAX_X := 1257.0

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
	_expect(is_instance_valid(player), "GameSession 未创建 PlayerActor。")
	if not is_instance_valid(player):
		quit(1)
		return

	_expect(player.definition == game_session.player_definition, "PlayerActor 未使用 GameSession 注入的配置。")
	_expect(player.collision_layer == 2, "PlayerActor 未使用 PlayerBody 碰撞层。")
	_expect(player.collision_mask & 1 != 0, "PlayerActor 未检测 World 碰撞层。")
	_expect(player.collision_mask & 4 == 0, "PlayerActor 不应与 EnemyBody 产生实体阻挡。")
	_expect(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "PlayerActor 未使用俯视角 FLOATING 运动模式。")
	_expect(player.camera.enabled, "PlayerActor 的 Camera2D 未启用。")
	_expect(player.get_viewport().get_camera_2d() == player.camera, "PlayerActor 的 Camera2D 未成为当前摄像机。")
	_expect(player.camera.zoom.is_equal_approx(Vector2.ONE * player.definition.camera_zoom), "Camera2D 未使用角色配置的视野缩放。")

	var start_position: Vector2 = player.global_position
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	await physics_frame
	await physics_frame
	var diagonal_speed: float = player.velocity.length()
	_expect(is_equal_approx(diagonal_speed, EXPECTED_MOVE_SPEED), "斜向移动速度未归一化。")
	_expect(player.global_position.distance_to(start_position) > 0.0, "玩家未响应移动输入。")
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")

	player.global_position = Vector2(1240.0, 0.0)
	Input.action_press(&"move_right")
	for _frame: int in range(12):
		await physics_frame
	Input.action_release(&"move_right")
	_expect(player.global_position.x <= RIGHT_BOUNDARY_MAX_X, "玩家穿过场地右侧边界。")

	if not _failed:
		print("Player movement smoke test passed: data, movement, camera, and bounds are valid.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
