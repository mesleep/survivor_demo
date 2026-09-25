## T02：角色/武器目录、单局配置快照与旧直启兼容的专项回归。
##
## 覆盖目录校验、默认快照、非法配置边界、数组隔离，以及 GameSession
## 在“有/无 RunLoadout”两条路径下的启动与重开行为。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	_test_catalog_defaults(catalog)
	_test_validation_errors(catalog)
	_test_copy_isolation()
	await _test_game_session_paths(catalog)
	if not _failed:
		print("Run loadout smoke test passed: catalog, validation, isolation and both start paths are valid.")
	quit(1 if _failed else 0)


func _test_catalog_defaults(catalog: ContentCatalog) -> void:
	_expect(catalog != null, "默认内容目录加载失败。")
	if catalog == null:
		return
	_expect(catalog.validate().is_empty(), "默认目录自身校验应通过。")
	_expect(catalog.get_character(&"player_default") != null, "目录缺少默认角色。")
	for weapon_id: StringName in [&"starter_weapon", &"leaf", &"bone", &"bell"]:
		_expect(catalog.get_weapon(weapon_id) != null, "目录缺少武器：%s。" % weapon_id)

	var loadout: RunLoadout = RunLoadout.default_for(catalog)
	_expect(loadout.is_valid(catalog), "默认快照应通过校验：%s。" % str(loadout.validate(catalog)))
	_expect(loadout.character_id == &"player_default", "默认快照角色 ID 不正确。")
	_expect(loadout.starting_weapon_ids.has(&"starter_weapon"), "默认快照缺少起始武器。")
	_expect(loadout.candidate_weapon_ids.size() == catalog.weapons.size(), "默认候选池应包含全部现有武器。")
	_expect(loadout.candidate_weapon_ids.size() <= RunLoadout.MAX_CANDIDATE_WEAPONS, "默认候选池超过上限。")
	for weapon_id: StringName in loadout.starting_weapon_ids:
		_expect(loadout.candidate_weapon_ids.has(weapon_id), "起始武器必须包含在候选池：%s。" % weapon_id)


func _test_validation_errors(catalog: ContentCatalog) -> void:
	var unknown_character := RunLoadout.new(&"ghost_character", [&"leaf"], [&"leaf"])
	_expect(_contains(unknown_character.validate(catalog), "未知角色"), "未知角色未被识别。")

	var unknown_weapon := RunLoadout.new(
		&"player_default", [&"starter_weapon", &"ghost_weapon"], [&"starter_weapon"]
	)
	_expect(_contains(unknown_weapon.validate(catalog), "不在目录"), "未知武器未被识别。")

	var duplicate_candidate := RunLoadout.new(&"player_default", [&"leaf", &"leaf"], [&"leaf"])
	_expect(_contains(duplicate_candidate.validate(catalog), "重复"), "重复候选未被识别。")

	var starting_outside_pool := RunLoadout.new(&"player_default", [&"leaf"], [&"starter_weapon"])
	_expect(_contains(starting_outside_pool.validate(catalog), "不在候选池"), "起始武器越界未被识别。")

	var empty_starting := RunLoadout.new(&"player_default", [&"leaf"], [])
	_expect(_contains(empty_starting.validate(catalog), "至少需要一把起始武器"), "空起始武器未被识别。")

	var many_ids: Array[StringName] = [&"starter_weapon", &"leaf", &"bone", &"bell"]
	while many_ids.size() < RunLoadout.MAX_CANDIDATE_WEAPONS + 1:
		many_ids.append(StringName("fake_%d" % many_ids.size()))
	var over_limit := RunLoadout.new(&"player_default", many_ids, [&"starter_weapon"])
	_expect(_contains(over_limit.validate(catalog), "最多"), "超过候选上限未被识别。")

	var fewer_than_ten := RunLoadout.new(&"player_default", [&"starter_weapon"], [&"starter_weapon"])
	_expect(fewer_than_ten.is_valid(catalog), "库存不足十个时应允许少选。")


func _test_copy_isolation() -> void:
	var candidates: Array[StringName] = [&"leaf"]
	var starting: Array[StringName] = [&"leaf"]
	var loadout := RunLoadout.new(&"player_default", candidates, starting)
	candidates.append(&"bone")
	starting.append(&"bone")
	_expect(loadout.candidate_weapon_ids.size() == 1, "构造未复制候选数组。")
	_expect(loadout.starting_weapon_ids.size() == 1, "构造未复制起始数组。")

	var cloned: RunLoadout = loadout.copy()
	cloned.candidate_weapon_ids.append(&"bell")
	_expect(loadout.candidate_weapon_ids.size() == 1, "copy() 未隔离数组。")


func _test_game_session_paths(catalog: ContentCatalog) -> void:
	if catalog == null:
		return

	# 有配置：外部改动不应影响已注入本局的快照；起始武器来自快照。
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.auto_start = false
	root.add_child(main_node)
	await process_frame
	var external := RunLoadout.new(&"player_default", [&"leaf", &"bone"], [&"leaf"])
	session.set_run_loadout(external)
	external.starting_weapon_ids.clear()
	external.candidate_weapon_ids.clear()
	session.start_run()
	await process_frame
	_expect(session.player != null, "配置路径未创建玩家。")
	if session.player != null:
		_expect(session.player.has_weapon(&"leaf"), "配置路径未按快照装备起始武器。")
		_expect(not session.player.has_weapon(&"starter_weapon"), "配置路径错误添加了非起始武器。")
	session.enemy_spawner.stop()
	main_node.queue_free()
	await process_frame

	# 无配置：旧直启入口沿用导出角色与起始武器。
	var legacy_main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(legacy_main)
	await process_frame
	var legacy_session: GameSession = legacy_main.get_node("GameSession") as GameSession
	_expect(legacy_session.player != null, "旧直启未创建玩家。")
	if legacy_session.player != null:
		_expect(legacy_session.player.has_weapon(&"starter_weapon"), "旧直启缺少起始武器。")
	legacy_session.enemy_spawner.stop()
	legacy_main.queue_free()
	await process_frame


func _contains(errors: Array[String], fragment: String) -> bool:
	for message: String in errors:
		if message.contains(fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
