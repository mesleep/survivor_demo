## 验证可爱像素素材的透明图集、运动帧、武器发射动画与停止状态。
extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: GameSession = main.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var sprite: AnimatedSprite2D = player.visual as AnimatedSprite2D
	_expect(sprite != null and sprite.sprite_frames.get_frame_count(&"walk") == 4, "玩家缺少四帧移动动画。")
	var weapon: WeaponController = player.weapon_controllers[0]
	weapon.set_process(false)
	Input.action_press(&"move_left")
	await create_timer(0.18).timeout
	_expect(sprite.animation == &"walk" and sprite.flip_h, "移动动画或左向翻转未生效。")
	var first_frame: int = sprite.frame
	await create_timer(0.15).timeout
	_expect(sprite.frame != first_frame, "移动帧没有推进。")
	Input.action_release(&"move_left")
	await create_timer(0.05).timeout
	_expect(sprite.animation == &"idle", "停止移动后没有恢复待机。")
	for name: String in ["huniu", "heibao", "boss"]:
		var frames: SpriteFrames = load("res://data/visuals/%s_frames.tres" % name) as SpriteFrames
		_expect(frames.get_frame_count(&"walk") == 4, "%s 缺少运动帧。" % name)
		for index: int in range(4):
			var atlas: AtlasTexture = frames.get_frame_texture(&"walk", index) as AtlasTexture
			_expect(atlas != null and atlas.region.end.x <= atlas.atlas.get_width() and atlas.region.end.y <= atlas.atlas.get_height(), "图集裁切超出纹理。")
	var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(session.enemy_spawn_settings.enemy_definition, player.position + Vector2(220, 0), true)
	weapon.reset_runtime_state()
	_expect(weapon.request_fire(enemy), "武器无法发射。")
	_expect(weapon.weapon_visual.animation == &"fire", "发射未触发武器动画。")
	await create_timer(0.35).timeout
	_expect(weapon.weapon_visual.animation == &"idle", "发射动画未恢复待机。")
	if "--capture" in OS.get_cmdline_user_args():
		player.position = Vector2.ZERO
		player.camera.zoom = Vector2.ONE
		for child: Node in session.enemies.get_children():
			child.queue_free()
		for index: int in range(3):
			var path: String = ["enemy_basic", "enemy_fast", "boss_default"][index]
			var definition: EnemyDefinition = load("res://data/enemies/%s.tres" % path) as EnemyDefinition
			var actor: EnemyActor = session.enemy_spawner.spawn_enemy(definition, Vector2(180 + index * 140, 100), true)
			actor.set_physics_process(false)
			session.spawn_experience_gem(1, Vector2(-160, 80))
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/survivor_pixel_art_preview.png")
	if not _failed:
		print("Pixel art smoke test passed: movement, facing, atlas bounds and weapon animation.")
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
