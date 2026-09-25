## 地图选择专项回归。
##
## 覆盖目录含两张地图、快照地图校验与解析、菜单选择、单局应用所选地图、默认地图。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_map/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_catalog_and_loadout()
	await _test_menu_selection()
	await _test_session_applies_map()
	_cleanup()
	if not _failed:
		print("Map selection smoke test passed: catalog, loadout, menu and session are valid.")
	quit(1 if _failed else 0)


## 目录含两张地图；快照可解析、未知地图被拒绝；默认取第一张。
func _test_catalog_and_loadout() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var ids: Array[StringName] = catalog.get_map_ids()
	_expect(ids.has(&"moonlit_courtyard") and ids.has(&"eclipse_wasteland"), "目录应含两张地图。")
	_expect(catalog.validate().is_empty(), "含地图的目录应通过校验。")

	var loadout := RunLoadout.new(&"player_default", [&"staff"], [&"staff"], &"eclipse_wasteland")
	_expect(loadout.validate(catalog).is_empty(), "合法地图快照应通过校验。")
	_expect(
		loadout.resolve_map(catalog) != null and loadout.resolve_map(catalog).id == &"eclipse_wasteland",
		"快照应解析到所选地图。"
	)
	var bad := RunLoadout.new(&"player_default", [&"staff"], [&"staff"], &"ghost_map")
	_expect(not bad.validate(catalog).is_empty(), "未知地图应校验失败。")
	_expect(RunLoadout.default_for(catalog).map_id == &"moonlit_courtyard", "默认地图应为第一张。")


## 菜单可选择地图并写入开局快照。
func _test_menu_selection() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var menu: MainMenu = (load(MENU_SCENE_PATH) as PackedScene).instantiate()
	menu.catalog = catalog
	root.add_child(menu)
	await process_frame
	_expect(menu.get_map_id() == &"moonlit_courtyard", "菜单默认应选第一张地图。")
	_expect(menu.select_map(&"eclipse_wasteland"), "应能选择月蚀荒原。")
	_expect(menu.get_selected_loadout().map_id == &"eclipse_wasteland", "快照应带上所选地图。")
	_expect(not menu.select_map(&"ghost_map"), "未知地图不应可选。")
	menu.queue_free()
	await process_frame


## 单局按快照切换到所选地图。
func _test_session_applies_map() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var entry := GameEntry.new()
	entry.catalog = catalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = ProfileStore.new(TEST_PROFILE_PATH)
	root.add_child(entry)
	await process_frame
	var base: RunLoadout = RunLoadout.default_for(catalog, &"player_default")
	var loadout := RunLoadout.new(
		base.character_id, base.candidate_weapon_ids, base.starting_weapon_ids, &"eclipse_wasteland"
	)
	entry._start_session(loadout)
	await process_frame
	var session: GameSession = entry.get_active_session()
	_expect(session != null, "应能开始单局。")
	_expect(
		session.arena.get_definition() != null and session.arena.get_definition().id == &"eclipse_wasteland",
		"单局应应用所选地图。"
	)
	entry.queue_free()
	await process_frame


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
