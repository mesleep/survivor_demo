## 宠物美术、背景、中文、暂停状态隔离和本地音频的回归验证。
extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: GameSession = main.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	check(session.arena.background_texture != null, "背景未加载")
	check(session.hud.health_label.text.begins_with("生命"), "生命值未中文化")
	check(session.game_audio.music.stream != null, "背景音乐未加载")
	if DisplayServer.get_name() != "headless":
		check(session.game_audio.music.playing, "背景音乐未播放")
	check((session.game_audio.music.stream as AudioStreamWAV).loop_end > 0, "音乐循环范围为空")
	for key: StringName in GameAudio.SOUND_FILES:
		var stream: AudioStream = load("res://assets/audio/%s.wav" % GameAudio.SOUND_FILES[key]) as AudioStream
		check(stream != null and stream.get_length() > 0.05, "音频为空")
	for name: String in ["enemy_basic", "enemy_fast"]:
		var definition: EnemyDefinition = load("res://data/enemies/%s.tres" % name) as EnemyDefinition
		var enemy: EnemyActor = session.enemy_spawner.spawn_enemy(definition, Vector2(300, 0), true)
		var frames: SpriteFrames = (enemy.visual as AnimatedSprite2D).sprite_frames
		check(frames.get_frame_count(&"walk") == 4, "宠物运动帧缺失")
		check((frames.get_frame_texture(&"walk", 0) as AtlasTexture).atlas.resource_path.contains("/pets/"), "未替换为宠物图集")
	session.session_controls.toggle_pause()
	check(paused, "暂停未生效")
	var before: float = session.elapsed_seconds
	await create_timer(0.1, true).timeout
	check(session.elapsed_seconds == before, "暂停仍推进计时")
	session.session_controls.toggle_pause()
	check(not paused, "暂停无法恢复")
	session.game_audio.set_muted(true)
	check(session.game_audio.muted and session.game_audio.music.volume_db <= -80, "静音失败")
	session.game_audio.set_muted(false)
	session.upgrade_system.request_choices(3)
	paused = true
	session.session_controls.toggle_pause()
	check(paused, "Esc 穿透升级暂停")
	session.end_run(GameResult.Outcome.DEFEAT)
	session.session_controls.toggle_pause()
	check(paused and not session.game_audio.music.playing, "结算没有保持暂停或停止音乐")
	paused = false
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("宠物表现专项：" + ("失败" if failed else "通过"))
	quit(1 if failed else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
