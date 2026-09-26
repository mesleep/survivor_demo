## 数值/素材工作台：分类枚举、属性收集、数值修改与保存回读。
extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_categories()
	_test_rows_and_edit()
	_test_save_round_trip()
	await _test_ui_builds()
	await _test_entry_opens_workbench()
	if not _failed:
		print("Config workbench smoke test passed: categories, rows, save and UI are valid.")
	quit(1 if _failed else 0)


func _test_categories() -> void:
	var categories: Array[Dictionary] = ConfigWorkbenchService.get_categories()
	_expect(not categories.is_empty(), "工作台应有分类。")
	for category: Dictionary in categories:
		var paths: Array[String] = ConfigWorkbenchService.list_resource_paths(String(category["id"]))
		_expect(not paths.is_empty(), "分类应有资源：%s" % category["id"])
		for path: String in paths:
			_expect(
				ConfigWorkbenchService.load_resource(path) != null,
				"分类资源应能加载：%s" % path
			)


func _test_rows_and_edit() -> void:
	var resource: Resource = ConfigWorkbenchService.load_resource("res://data/upgrades/damage_up.tres")
	_expect(resource != null, "应能加载 damage_up。")
	if resource == null:
		return
	var rows: Array[Dictionary] = ConfigWorkbenchService.collect_rows(resource)
	var names: Array[String] = []
	var labelled_count: int = 0
	for row: Dictionary in rows:
		if String(row["kind"]) == "property":
			names.append(String(row["name"]))
			if not String(row.get("comment", "")).is_empty():
				labelled_count += 1
	_expect(names.has("value"), "应收集到数值字段 value。")
	_expect(names.has("icon"), "应收集到素材字段 icon。")
	_expect(labelled_count > 0, "应至少从注释解析出一部分中文字段说明。")
	var old_value: float = float(resource.get("value"))
	resource.set("value", old_value + 0.25)
	_expect(
		is_equal_approx(float(resource.get("value")), old_value + 0.25),
		"数值应能写回资源实例。"
	)
	resource.set("value", old_value)
	var weapon: Resource = ConfigWorkbenchService.load_resource("res://data/weapons/bow.tres")
	var group_count: int = 0
	for row: Dictionary in ConfigWorkbenchService.collect_rows(weapon):
		if String(row["kind"]) == "group":
			group_count += 1
	_expect(group_count >= 3, "武器应有中文导出分组。")


func _test_save_round_trip() -> void:
	var source: Resource = ConfigWorkbenchService.load_resource("res://data/upgrades/damage_up.tres")
	var copy: Resource = source.duplicate(true)
	var target_dir: String = "user://workbench_test"
	DirAccess.make_dir_recursive_absolute(target_dir)
	var target_path: String = target_dir + "/damage_up_copy.tres"
	copy.take_over_path(target_path)
	copy.set("value", 0.33)
	var result: Error = ConfigWorkbenchService.save_resource(copy)
	_expect(result == OK, "保存副本应成功：%s" % error_string(result))
	var reloaded: Resource = ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(reloaded != null, "应能重读保存后的资源。")
	if reloaded != null:
		_expect(
			is_equal_approx(float(reloaded.get("value")), 0.33),
			"重读应得到保存后的数值。"
		)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))


func _test_ui_builds() -> void:
	var workbench: ConfigWorkbench = (
		(load("res://scenes/tools/config_workbench.tscn") as PackedScene).instantiate() as ConfigWorkbench
	)
	root.add_child(workbench)
	await process_frame
	await process_frame
	var tree: Tree = workbench.find_child("CategoryTree", true, false) as Tree
	_expect(tree != null and tree.get_root() != null, "工作台应构建分类树。")
	if tree != null and tree.get_root() != null:
		var category_count: int = tree.get_root().get_child_count()
		_expect(
			category_count == ConfigWorkbenchService.get_categories().size(),
			"分类树数量应与服务一致。"
		)
	var property_list: VBoxContainer = workbench.find_child("PropertyList", true, false) as VBoxContainer
	_expect(property_list != null, "工作台应有属性列表。")
	if property_list != null:
		# 每个分类抽第一个资源在 UI 中打开，确保各类型属性行都能构建。
		for category: Dictionary in ConfigWorkbenchService.get_categories():
			var paths: Array[String] = ConfigWorkbenchService.list_resource_paths(String(category["id"]))
			if paths.is_empty():
				continue
			var resource: Resource = ConfigWorkbenchService.load_resource(paths[0])
			workbench.call("_open_resource", resource)
			await process_frame
			_expect(
				property_list.get_child_count() > 0,
				"属性行应能构建：%s" % paths[0]
			)
	workbench.queue_free()
	await process_frame


## 入口通过主菜单设置打开工作台，关闭后释放。
func _test_entry_opens_workbench() -> void:
	var entry := GameEntry.new()
	entry.catalog = ConfigWorkbenchService.load_resource(
		"res://data/catalog/default_catalog.tres"
	) as ContentCatalog
	entry.menu_scene = load("res://scenes/ui/main_menu.tscn") as PackedScene
	entry.session_scene = load("res://scenes/gameplay/game_session.tscn") as PackedScene
	entry.profile_store = ProfileStore.new("user://profile_test_workbench/profile.json")
	root.add_child(entry)
	await process_frame
	entry.call("_open_config_workbench")
	await process_frame
	var workbench: ConfigWorkbench = entry.get("_workbench") as ConfigWorkbench
	_expect(workbench != null, "入口应能打开工作台。")
	if workbench != null:
		workbench.closed.emit()
		await process_frame
		_expect(entry.get("_workbench") == null, "关闭后应释放工作台。")
	entry.queue_free()
	await process_frame
	ProfileStore.new("user://profile_test_workbench/profile.json").delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
