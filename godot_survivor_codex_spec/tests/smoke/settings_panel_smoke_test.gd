## 设置面板专项回归。
##
## 覆盖局内 Esc 暂停并打开设置、关闭恢复、返回主菜单；主菜单设置与静音偏好。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_settings/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_ingame_settings_and_return()
	await _test_menu_settings()
	_cleanup()
	if not _failed:
		print("Settings panel smoke test passed: pause settings, return to menu and menu settings are valid.")
	quit(1 if _failed else 0)


## Esc 打开设置并暂停；再次 Esc 恢复；返回主菜单释放单局并显示菜单。
func _test_ingame_settings_and_return() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var entry := GameEntry.new()
	entry.catalog = catalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = ProfileStore.new(TEST_PROFILE_PATH)
	root.add_child(entry)
	await process_frame
	entry._start_session(RunLoadout.default_for(catalog, &"player_default"))
	await process_frame
	var session: GameSession = entry.get_active_session()
	_expect(session != null, "应能开始单局。")

	var controls: SessionControls = session.session_controls
	_expect(controls != null, "单局应有 SessionControls。")
	controls.toggle_pause()
	_expect(paused and controls._settings_panel.is_open(), "Esc 应暂停并打开设置。")
	_expect(
		controls._settings_panel._quit_button != null and controls._settings_panel._quit_button.visible,
		"暂停菜单应显示退出游戏按钮。"
	)
	controls.toggle_pause()
	_expect(not paused and not controls._settings_panel.is_open(), "再次 Esc 应恢复并关闭设置。")

	session.request_return_to_menu()
	await process_frame
	await process_frame
	_expect(entry.get_active_session() == null, "返回主菜单应释放单局。")
	_expect(entry.get_menu() != null, "返回后应显示主菜单。")
	entry.queue_free()
	await process_frame


## 主菜单设置可打开并记录静音偏好。
func _test_menu_settings() -> void:
	var menu: MainMenu = (load(MENU_SCENE_PATH) as PackedScene).instantiate()
	menu.catalog = load(CATALOG_PATH) as ContentCatalog
	root.add_child(menu)
	await process_frame
	_expect(not menu.get_preferred_muted(), "主菜单默认不静音。")
	_expect(menu.quit_button != null and menu.quit_button.visible, "主菜单应显示退出游戏按钮。")
	menu._on_settings_pressed()
	_expect(menu._settings_panel.is_open(), "主菜单设置应能打开。")
	menu._on_menu_mute_toggled(true)
	_expect(menu.get_preferred_muted(), "主菜单应记录静音偏好。")
	menu.queue_free()
	await process_frame


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
