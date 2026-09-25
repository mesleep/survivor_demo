## T30：永久强化与开局快照专项回归。
##
## 覆盖价格曲线与等级上限、余额不足与写档回滚、开局快照生效、
## 购买不改变进行中的一局、新局生效，以及共享 Resource 不变。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const PERMANENT_CATALOG_PATH := "res://data/progression/permanent_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_t30/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_price_cap_and_purchase()
	await _test_insufficient_and_rollback()
	await _test_run_snapshot_applies()
	await _test_purchase_does_not_change_old_run()
	_test_shared_resource_unchanged()
	_cleanup()
	if not _failed:
		print("Permanent upgrade smoke test passed: price, cap, rollback, snapshot and snapshot isolation are valid.")
	quit(1 if _failed else 0)


## 价格随等级递增；满级后拒绝购买。
func _test_price_cap_and_purchase() -> void:
	var catalog: PermanentUpgradeCatalog = load(PERMANENT_CATALOG_PATH) as PermanentUpgradeCatalog
	var definition: PermanentUpgradeDefinition = catalog.get_upgrade(&"permanent_move_speed")
	_expect(definition.get_price(0) == 30, "0 级价格应为 30。")
	_expect(definition.get_price(1) == 45, "1 级价格应为 45。")

	var profile := _make_profile(1000)
	var service := UnlockService.new(profile, _make_store())
	var expected_cost: int = 0
	for level: int in range(definition.max_level):
		expected_cost += definition.get_price(level)
		_expect(
			service.purchase_permanent_upgrade(catalog, &"permanent_move_speed")
			== UnlockService.Result.SUCCESS,
			"第 %d 级应购买成功。" % (level + 1)
		)
	_expect(profile.get_permanent_level(&"permanent_move_speed") == 5, "应升到 5 级。")
	_expect(profile.coins == 1000 - expected_cost, "扣币应等于价格总和。")
	_expect(
		service.purchase_permanent_upgrade(catalog, &"permanent_move_speed")
		== UnlockService.Result.MAX_LEVEL,
		"满级后应返回 MAX_LEVEL。"
	)


## 余额不足与写档失败都不改变等级。
func _test_insufficient_and_rollback() -> void:
	var catalog: PermanentUpgradeCatalog = load(PERMANENT_CATALOG_PATH) as PermanentUpgradeCatalog
	var store: ProfileStore = _make_store()
	var profile := _make_profile(10)
	var service := UnlockService.new(profile, store)
	_expect(
		service.purchase_permanent_upgrade(catalog, &"permanent_move_speed")
		== UnlockService.Result.INSUFFICIENT_COINS,
		"余额不足应拒绝。"
	)
	_expect(profile.get_permanent_level(&"permanent_move_speed") == 0, "失败不应升级。")

	profile.coins = 1000
	store.write_failure_injected = true
	_expect(
		service.purchase_permanent_upgrade(catalog, &"permanent_move_speed")
		== UnlockService.Result.SAVE_FAILED,
		"写档失败应返回 SAVE_FAILED。"
	)
	_expect(profile.get_permanent_level(&"permanent_move_speed") == 0, "写档失败应回滚等级。")
	_expect(profile.coins == 1000, "写档失败应回滚金币。")
	store.write_failure_injected = false


## 开局把档案永久等级快照写入玩家；新局数值与存档一致。
func _test_run_snapshot_applies() -> void:
	var profile := _make_profile(0)
	profile.permanent_upgrades = {
		&"permanent_move_speed": 2,
		&"permanent_damage": 1,
		&"permanent_defense": 1,
		&"permanent_lifesteal": 1,
		&"permanent_regeneration": 1,
	}
	var store: ProfileStore = _make_store()
	store.save_profile(profile)

	var entry: GameEntry = await _spawn_entry(store)
	entry._start_session(RunLoadout.default_for(entry.catalog))
	await process_frame
	var session: GameSession = entry.get_active_session()
	var player: PlayerActor = session.player
	_expect(
		is_equal_approx(player.get_effective_move_speed(), 220.0 * 1.10),
		"2 级永久移速应为 220×1.10。"
	)
	_expect(is_equal_approx(player.get_defense(), 1.0), "1 级永久防御应为 1。")
	_expect(is_equal_approx(player.get_bonus_lifesteal_ratio(), 0.02), "1 级永久吸血应为 0.02。")
	_expect(is_equal_approx(player.get_permanent_regeneration(), 0.3), "1 级永久恢复应为 0.3。")
	var starter: WeaponController = _find_controller(player, &"staff")
	_expect(
		starter != null and is_equal_approx(starter.get_runtime_damage_multiplier(), 1.05),
		"1 级永久伤害应使武器伤害 ×1.05。"
	)
	entry.queue_free()
	await process_frame


## 购买不改变进行中的一局；新开局才生效。
func _test_purchase_does_not_change_old_run() -> void:
	var profile := _make_profile(1000)
	var store: ProfileStore = _make_store()
	store.save_profile(profile)
	var entry: GameEntry = await _spawn_entry(store)
	var loadout: RunLoadout = RunLoadout.default_for(entry.catalog)
	entry._start_session(loadout)
	await process_frame
	var first_player: PlayerActor = entry.get_active_session().player
	var before: float = first_player.get_effective_move_speed()

	entry.unlock_service.purchase_permanent_upgrade(
		entry.permanent_catalog, &"permanent_move_speed"
	)
	_expect(
		is_equal_approx(first_player.get_effective_move_speed(), before),
		"购买不应改变进行中的一局。"
	)

	entry._clear_session()
	entry._start_session(loadout)
	await process_frame
	var second_player: PlayerActor = entry.get_active_session().player
	_expect(
		is_equal_approx(second_player.get_effective_move_speed(), 220.0 * 1.05),
		"新开局应应用最新永久等级。"
	)
	entry.queue_free()
	await process_frame


## 共享目录 Resource 不应被运行时改写。
func _test_shared_resource_unchanged() -> void:
	var catalog: PermanentUpgradeCatalog = load(PERMANENT_CATALOG_PATH) as PermanentUpgradeCatalog
	var definition: PermanentUpgradeDefinition = catalog.get_upgrade(&"permanent_move_speed")
	_expect(is_equal_approx(definition.per_level_value, 0.05), "共享定义不应被回写。")
	_expect(definition.max_level == 5, "共享上限不应被回写。")


func _spawn_entry(store: ProfileStore) -> GameEntry:
	var entry := GameEntry.new()
	entry.catalog = load(CATALOG_PATH) as ContentCatalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = store
	root.add_child(entry)
	await process_frame
	return entry


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _make_profile(coins: int) -> Profile:
	var profile := Profile.new()
	profile.coins = coins
	profile.unlocked_character_ids = [&"player_default"]
	profile.unlocked_weapon_ids = [&"starter_weapon", &"bow", &"staff", &"leaf", &"bone", &"bell"]
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
