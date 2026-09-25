## T29：武器/角色解锁与购买专项回归。
##
## 覆盖购买成功/余额不足/重复/非法 ID/写档失败回滚与持久化、
## 菜单锁定显示与购买、入口拒绝未解锁配置，以及进行中的一局不被修改。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_t29/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_purchase_success_and_persist()
	await _test_insufficient_duplicate_and_invalid()
	await _test_save_failure_rollback()
	await _test_menu_lock_and_purchase()
	await _test_entry_rejects_locked_and_snapshot()
	_cleanup()
	if not _failed:
		print("Unlock shop smoke test passed: purchase, validation, rollback, menu and snapshot are valid.")
	quit(1 if _failed else 0)


## 购买成功扣币、解锁并写档，重进可见。
func _test_purchase_success_and_persist() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var profile := _make_profile(100)
	var service := UnlockService.new(profile, _make_store())
	_expect(
		service.purchase_weapon(catalog, &"bow") == UnlockService.Result.SUCCESS,
		"余额充足时应购买成功。"
	)
	_expect(profile.coins == 40, "购买弓后应扣 60 金。")
	_expect(profile.is_weapon_unlocked(&"bow"), "弓应被解锁。")
	var reloaded: Profile = _make_store().load_profile()
	_expect(reloaded.is_weapon_unlocked(&"bow") and reloaded.coins == 40, "解锁与余额应持久化。")


## 余额不足、重复购买与非法 ID 各自返回对应结果且不改变状态。
func _test_insufficient_duplicate_and_invalid() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var profile := _make_profile(10)
	var service := UnlockService.new(profile, _make_store())
	_expect(
		service.purchase_weapon(catalog, &"bow") == UnlockService.Result.INSUFFICIENT_COINS,
		"余额不足应拒绝购买。"
	)
	_expect(profile.coins == 10 and not profile.is_weapon_unlocked(&"bow"), "失败交易不应扣币或解锁。")

	profile.coins = 100
	_expect(service.purchase_weapon(catalog, &"bow") == UnlockService.Result.SUCCESS, "补足余额应成功。")
	_expect(
		service.purchase_weapon(catalog, &"bow") == UnlockService.Result.ALREADY_UNLOCKED,
		"重复购买应返回已解锁。"
	)
	_expect(profile.coins == 40, "重复购买不应再次扣币。")
	_expect(
		service.purchase_weapon(catalog, &"ghost_weapon") == UnlockService.Result.INVALID_ID,
		"非法 ID 应被拒绝。"
	)


## 写档失败时回滚内存档案，保持与磁盘一致。
func _test_save_failure_rollback() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var store: ProfileStore = _make_store()
	var profile := _make_profile(100)
	var service := UnlockService.new(profile, store)
	store.write_failure_injected = true
	_expect(
		service.purchase_weapon(catalog, &"bow") == UnlockService.Result.SAVE_FAILED,
		"写档失败应返回 SAVE_FAILED。"
	)
	_expect(profile.coins == 100 and not profile.is_weapon_unlocked(&"bow"), "失败应回滚金币与解锁。")
	store.write_failure_injected = false


## 菜单显示锁定与价格，点击购买后变为已解锁并加入候选。
func _test_menu_lock_and_purchase() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var profile := _make_profile(100)
	var service := UnlockService.new(profile, _make_store())
	var menu: MainMenu = (load(MENU_SCENE_PATH) as PackedScene).instantiate()
	menu.catalog = catalog
	menu.configure_profile(profile, service)
	root.add_child(menu)
	await process_frame

	_expect(not menu.set_weapon_selected(&"bow", true), "锁定武器不应可选中。")
	menu._on_weapon_pressed(&"bow")
	_expect(profile.is_weapon_unlocked(&"bow"), "点击锁定武器应完成购买。")
	_expect(menu.is_weapon_selected(&"bow"), "购买后该武器应加入候选池。")
	_expect(profile.coins == 40, "购买后余额应为 40。")

	menu.queue_free()
	await process_frame


## 入口拒绝未解锁配置；进行中的一局候选池不因购买而改变。
func _test_entry_rejects_locked_and_snapshot() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var store: ProfileStore = _make_store()
	var profile := _make_profile(0)
	store.save_profile(profile)

	var entry := GameEntry.new()
	entry.catalog = catalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = store
	root.add_child(entry)
	await process_frame

	var locked_loadout := RunLoadout.new(&"player_default", [&"staff", &"bow"], [&"staff"])
	_expect(not entry.is_loadout_unlocked(locked_loadout), "含未解锁武器的配置应被拒绝。")
	entry._on_start_requested(locked_loadout)
	_expect(entry.get_active_session() == null, "未解锁配置不应开始单局。")

	var valid_loadout := RunLoadout.new(&"player_default", [&"staff"], [&"staff"])
	entry._on_start_requested(valid_loadout)
	await process_frame
	var active: GameSession = entry.get_active_session()
	_expect(active != null, "已解锁配置应能开始单局。")
	_expect(
		not active.player.get_candidate_weapon_ids().has(&"bow"),
		"开局候选池应是快照，不含未解锁武器。"
	)

	profile.coins = 100
	entry.unlock_service.purchase_weapon(catalog, &"bow")
	_expect(
		not active.player.get_candidate_weapon_ids().has(&"bow"),
		"进行中的一局不应因购买而改变候选池。"
	)
	entry.queue_free()
	await process_frame


func _make_profile(coins: int) -> Profile:
	var profile := Profile.new()
	profile.coins = coins
	profile.unlocked_character_ids = [&"player_default"]
	profile.unlocked_weapon_ids = [&"staff"]
	return profile


func _make_store() -> ProfileStore:
	return ProfileStore.new(TEST_PROFILE_PATH)


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
