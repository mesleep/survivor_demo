## 确认当前可玩场景使用已导入的新版暗色漫画素材。
extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var backgrounds: Texture2D = load("res://assets/v2_dark_comic/backgrounds/F01_moonlit_courtyard.png")
	check(backgrounds != null and backgrounds.get_size() == Vector2(2560, 1440), "庭院尺寸或加载失败")
	for name: String in ["player", "huniu", "heibao", "xiaosi", "xiaoqi", "boss", "wand", "bolt", "leaf", "bone", "bell", "gem"]:
		var frames: SpriteFrames = load("res://data/visuals/v2_dark_comic/%s_frames.tres" % name)
		check(frames != null, "%s 新版 SpriteFrames 缺失" % name)
		if frames == null:
			continue
		var animation: StringName = &"walk" if name in ["player", "huniu", "heibao", "xiaosi", "xiaoqi", "boss"] else (&"fire" if name == "wand" else &"default")
		check(frames.get_frame_count(animation) == 4, "%s 动画播放槽数量不对" % name)
		var paths := PackedStringArray()
		for index: int in range(frames.get_frame_count(animation)):
			var texture: Texture2D = frames.get_frame_texture(animation, index)
			check(texture.resource_path.contains("/v2_dark_comic/"), "%s 混入旧版纹理" % name)
			check(texture.get_image().get_pixel(0, 0).a < 0.01, "%s 透明角不透明" % name)
			paths.append(texture.resource_path)
		if name in ["player", "huniu", "heibao", "xiaosi", "xiaoqi", "boss", "wand", "bolt"]:
			var unique_paths := {}
			for path: String in paths:
				unique_paths[path] = true
			check(unique_paths.size() == 4, "%s 四帧未接入独立图像" % name)
	var upgrade_dir := DirAccess.open("res://data/upgrades")
	check(upgrade_dir != null, "升级目录无法打开")
	if upgrade_dir != null:
		var upgrade_count := 0
		for file_name: String in upgrade_dir.get_files():
			if not file_name.ends_with(".tres"):
				continue
			var definition: UpgradeDefinition = load("res://data/upgrades/%s" % file_name) as UpgradeDefinition
			check(definition != null, "升级定义加载失败：%s" % file_name)
			if definition == null:
				continue
			upgrade_count += 1
			check(
				definition.icon != null and definition.icon.resource_path.contains("res://assets/v2_dark_comic/"),
				"升级缺少新版图标：%s" % file_name
			)
		check(upgrade_count > 0, "未找到任何升级定义")
	var main: Node = (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: GameSession = main.get_node("GameSession") as GameSession
	check(session.arena.background_texture.resource_path.contains("/v2_dark_comic/"), "场景未使用新版庭院")
	check((session.player.visual as AnimatedSprite2D).sprite_frames.resource_path.contains("/v2_dark_comic/"), "场景未使用新版玩家")
	main.queue_free()
	await process_frame
	print("新版美术资源验收：" + ("失败" if failed else "通过"))
	quit(1 if failed else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
