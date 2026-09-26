## 存档重置专项：重置后回到默认解锁、金币清零并删除存档文件。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_reset/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var entry := GameEntry.new()
	entry.catalog = catalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = ProfileStore.new(TEST_PROFILE_PATH)
	root.add_child(entry)
	await process_frame

	var store: ProfileStore = entry.get_profile_store()
	var profile: Profile = entry.get_profile()
	profile.add_coins(500)
	profile.unlocked_character_ids.append(&"player_ranger")
	profile.permanent_upgrades[&"permanent_damage"] = 3
	_expect(store.save_profile(profile), "测试前应能写入存档。")
	_expect(store.has_save(), "测试前应存在存档文件。")

	entry.reset_profile()
	_expect(not store.has_save(), "重置应删除存档文件。")
	var fresh: Profile = entry.get_profile()
	_expect(fresh != null, "重置后应有默认档案。")
	if fresh != null:
		_expect(fresh.coins == 0, "重置后金币应为 0。")
		_expect(not fresh.is_character_unlocked(&"player_ranger"), "重置后付费角色应重新锁定。")
		_expect(fresh.get_permanent_level(&"permanent_damage") == 0, "重置后永久强化应清零。")
		_expect(
			fresh.is_character_unlocked(&"player_default"),
			"重置后免费角色应保持解锁。"
		)
		_expect(
			fresh.is_weapon_unlocked(&"staff"),
			"重置后免费角色的起始武器应保持解锁（否则新档无法开局）。"
		)
		_expect(entry.get_menu().profile == fresh, "主菜单应切换到重置后的档案。")
	_expect(entry.unlock_service.profile == fresh, "解锁服务应切换到重置后的档案。")

	# 购买角色应附送其起始武器，避免买下角色后无法开局。
	fresh.add_coins(200)
	_expect(
		entry.unlock_service.purchase_character(catalog, &"player_ranger") == UnlockService.Result.SUCCESS,
		"补足金币后应能购买远程射手。"
	)
	_expect(fresh.is_weapon_unlocked(&"bow"), "购买远程射手应附送其起始武器长弓。")

	entry.queue_free()
	await process_frame
	_cleanup()
	if not _failed:
		print("Profile reset smoke test passed: coins, unlocks and permanents return to defaults.")
	quit(1 if _failed else 0)


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
