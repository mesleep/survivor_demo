## 主菜单界面预览：验证面板/按钮样式、锁定/价格、永久强化区与主菜单设置（T34）。
##
## 仅图形模式使用，不参与 headless 回归。
extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var entry: Node = (load("res://scenes/bootstrap/game_entry.tscn") as PackedScene).instantiate()
	root.add_child(entry)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://art_review/v2_main_menu_preview.png")
	if result != OK:
		push_error("Could not save menu preview: %s" % result)
		quit(1)
		return

	# 主菜单设置面板：声音 / 重置存档 / 数值素材工作台 / 退出游戏。
	var menu: MainMenu = entry.call("get_menu") as MainMenu
	menu._on_settings_pressed()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	result = root.get_texture().get_image().save_png("res://art_review/v2_menu_settings_preview.png")
	if result != OK:
		push_error("Could not save menu settings preview: %s" % result)
	quit(0 if result == OK else 1)
