## T27：版本化存档与安全读写专项回归。
##
## 每个用例使用独立临时路径，覆盖首次无档、往返读写、损坏/缺字段/未知 ID、旧版本迁移、
## 写入失败保留旧档、连续结算，以及 GameEntry 的结算累加与状态提示。
extends SceneTree

const TEST_ROOT := "user://profile_test_t27"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_first_run_defaults()
	await _test_save_load_roundtrip()
	await _test_corrupted_json()
	await _test_missing_fields_and_unknown_ids()
	await _test_old_version_migration()
	await _test_write_failure_preserves_old()
	await _test_consecutive_settlements()
	await _test_game_entry_integration()
	_cleanup()
	if not _failed:
		print("Profile store smoke test passed: defaults, roundtrip, corruption, migration, atomic write and entry are valid.")
	quit(1 if _failed else 0)


## 首次无档返回默认档案（默认解锁 + 0 金币）。
func _test_first_run_defaults() -> void:
	var store: ProfileStore = _make_store("defaults")
	var profile: Profile = store.load_profile()
	_expect(store.last_error.is_empty(), "无档加载不应报错。")
	_expect(profile.version == Profile.CURRENT_VERSION, "默认版本应为当前版本。")
	_expect(profile.coins == 0, "默认金币应为 0。")
	_expect(profile.is_character_unlocked(&"player_default"), "默认应解锁默认角色。")
	_expect(profile.is_weapon_unlocked(&"starter_weapon"), "默认应解锁起始武器。")


## 保存后可被新实例完整读回（模拟进程重启）。
func _test_save_load_roundtrip() -> void:
	var store: ProfileStore = _make_store("roundtrip")
	var profile: Profile = store.load_profile()
	profile.add_coins(42)
	profile.unlocked_character_ids = [&"player_default", &"hero_b"]
	profile.unlocked_weapon_ids = [&"starter_weapon", &"bow"]
	profile.refresh_bonus = 1
	profile.permanent_upgrades = {&"move_speed": 2}
	_expect(store.save_profile(profile), "保存应成功。")

	var reloaded_store: ProfileStore = _make_store("roundtrip")
	var reloaded: Profile = reloaded_store.load_profile()
	_expect(reloaded_store.last_error.is_empty(), "读回应无错误。")
	_expect(reloaded.coins == 42, "金币应往返一致。")
	_expect(reloaded.refresh_bonus == 1, "刷新次数应往返一致。")
	_expect(reloaded.permanent_upgrades.get(&"move_speed", 0) == 2, "永久强化应往返一致。")
	_expect(reloaded.is_weapon_unlocked(&"bow"), "解锁武器应往返一致。")


## 损坏 JSON 回退默认并给出错误，且不覆盖原文件。
func _test_corrupted_json() -> void:
	var path: String = _path_for("corrupt")
	_write_raw(path, "{ this is not json")
	var store: ProfileStore = _make_store("corrupt")
	var profile: Profile = store.load_profile()
	_expect(profile.coins == 0, "损坏时应回退默认档案。")
	_expect(not store.last_error.is_empty(), "损坏时应记录错误。")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	_expect(file != null and file.get_as_text() == "{ this is not json", "加载损坏档不应改写原文件。")
	if file != null:
		file.close()


## 缺字段用默认值；已知 ID 之外的未知项被丢弃。
func _test_missing_fields_and_unknown_ids() -> void:
	_write_raw(_path_for("missing"), JSON.stringify({
		"coins": 5,
		"unlocked_character_ids": ["player_default", "ghost_character"],
		"unlocked_weapon_ids": ["starter_weapon", "ghost_weapon"],
	}))
	var store: ProfileStore = _make_store("missing")
	var profile: Profile = store.load_profile()
	_expect(profile.coins == 5, "缺失字段时已有金币应保留。")
	_expect(profile.refresh_bonus == 0, "缺失字段应使用默认值。")
	_expect(profile.is_character_unlocked(&"player_default"), "已知角色应保留。")
	_expect(not profile.is_character_unlocked(&"ghost_character"), "未知角色应被丢弃。")
	_expect(profile.is_weapon_unlocked(&"starter_weapon"), "已知武器应保留。")
	_expect(not profile.is_weapon_unlocked(&"ghost_weapon"), "未知武器应被丢弃。")


## 旧版本档案应迁移到当前版本并保留数据。
func _test_old_version_migration() -> void:
	_write_raw(_path_for("migrate"), JSON.stringify({"version": 0, "coins": 9}))
	var store: ProfileStore = _make_store("migrate")
	var profile: Profile = store.load_profile()
	_expect(profile.version == Profile.CURRENT_VERSION, "旧版本应迁移到当前版本。")
	_expect(profile.coins == 9, "迁移应保留金币。")


## 写入失败时返回 false 并保留旧档。
func _test_write_failure_preserves_old() -> void:
	var store: ProfileStore = _make_store("atomic")
	var profile: Profile = store.load_profile()
	profile.coins = 10
	_expect(store.save_profile(profile), "首次保存应成功。")
	var saved_coins: int = profile.coins

	store.write_failure_injected = true
	profile.add_coins(99)
	_expect(not store.save_profile(profile), "注入失败时应返回 false。")
	_expect(not store.last_error.is_empty(), "失败时应记录错误。")

	store.write_failure_injected = false
	var reloaded: Profile = _make_store("atomic").load_profile()
	_expect(reloaded.coins == saved_coins, "失败写入后应保留旧档金币 %d。" % saved_coins)


## 连续两次结算金币应累加。
func _test_consecutive_settlements() -> void:
	var store: ProfileStore = _make_store("settle")
	var profile: Profile = store.load_profile()
	profile.add_coins(5)
	_expect(store.save_profile(profile), "第一次结算保存应成功。")
	profile.add_coins(7)
	_expect(store.save_profile(profile), "第二次结算保存应成功。")
	_expect(_make_store("settle").load_profile().coins == 12, "两次结算金币应为 12。")


## GameEntry 结算累加并持久化；写入失败时菜单显示状态。
func _test_game_entry_integration() -> void:
	var entry := GameEntry.new()
	entry.catalog = load(CATALOG_PATH) as ContentCatalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = _make_store("entry")
	root.add_child(entry)
	await process_frame
	_expect(entry.get_profile() != null, "入口应加载档案。")

	_expect(entry.apply_run_result(GameResult.new(GameResult.Outcome.DEFEAT, 10.0, 2, 3, 4, 6)), "结算应保存成功。")
	_expect(entry.get_profile().coins == 10, "首局总奖励 10 应入账。")
	_expect(entry.apply_run_result(GameResult.new(GameResult.Outcome.VICTORY, 10.0, 3, 1, 0, 5)), "第二局应保存成功。")
	_expect(entry.get_profile().coins == 15, "两局应累加到 15。")
	_expect(_make_store("entry").load_profile().coins == 15, "累计金币应持久化。")

	entry.profile_store.write_failure_injected = true
	_expect(not entry.apply_run_result(GameResult.new(GameResult.Outcome.DEFEAT, 1.0, 1, 1, 0, 1)), "注入失败时应返回 false。")
	_expect(not entry.get_menu().get_status().is_empty(), "写入失败时菜单应显示状态。")

	entry.queue_free()
	await process_frame


func _path_for(name: String) -> String:
	return TEST_ROOT + "/" + name + ".json"


func _make_store(name: String) -> ProfileStore:
	var store := ProfileStore.new(_path_for(name))
	store.known_character_ids = [&"player_default", &"hero_b"]
	store.known_weapon_ids = [&"starter_weapon", &"bow"]
	store.default_character_ids = [&"player_default"]
	store.default_weapon_ids = [&"starter_weapon"]
	return store


func _write_raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(TEST_ROOT)
	var directory: DirAccess = DirAccess.open(absolute_root)
	if directory != null:
		for file_name: String in directory.get_files():
			directory.remove(file_name)
		DirAccess.remove_absolute(absolute_root)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
