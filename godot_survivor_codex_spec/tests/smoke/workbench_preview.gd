## 数值/素材工作台实拍：从主菜单设置打开工作台并选中一把武器。
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
	entry.call("_open_config_workbench")
	await process_frame
	await process_frame
	var workbench: ConfigWorkbench = entry.get("_workbench") as ConfigWorkbench
	var tree: Tree = workbench.find_child("CategoryTree", true, false) as Tree
	if tree != null and tree.get_root() != null:
		for category_item: TreeItem in tree.get_root().get_children():
			if category_item.get_text(0) == "武器":
				category_item.collapsed = false
				for resource_item: TreeItem in category_item.get_children():
					if String(resource_item.get_metadata(0).get("path", "")).ends_with("/bow.tres"):
						resource_item.select(0)
						break
				break
	workbench.call("_on_tree_item_selected")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(
		"res://art_review/v2_workbench_preview.png"
	)
	if result != OK:
		push_error("Could not save workbench preview: %s" % result)
	quit(0 if result == OK else 1)
