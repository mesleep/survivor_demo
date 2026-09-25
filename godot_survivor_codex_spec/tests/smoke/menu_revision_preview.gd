## 本轮主菜单图形验收截图；输出到临时目录，不覆盖历史 art_review。
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
	var result: Error = root.get_texture().get_image().save_png("/private/tmp/survivor_menu_revision.png")
	if result != OK:
		push_error("无法保存菜单截图：%s" % result)
	quit(0 if result == OK else 1)
