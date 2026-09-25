## T28：升级选项刷新次数专项回归。
##
## 覆盖零次禁用、刷新消耗与换卡、空池不死锁、跨升级保留余额、默认值，
## 以及 GameEntry 从档案复制永久刷新加成。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_t28/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_zero_disables_refresh()
	await _test_refresh_consumes_and_redraws()
	await _test_empty_pool_no_deadlock()
	await _test_balance_persists_across_levels()
	await _test_default_and_entry_bonus()
	_cleanup()
	if not _failed:
		print("Upgrade refresh smoke test passed: disable, consume, empty pool, balance and entry bonus are valid.")
	quit(1 if _failed else 0)


## 刷新次数为 0 时不能刷新。
func _test_zero_disables_refresh() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	upgrade_system.set_refresh_count(0)
	upgrade_system.request_choices(3)
	_expect(upgrade_system.get_current_choices().size() == 3, "应正常给出三张卡。")
	_expect(not upgrade_system.can_refresh(), "0 次刷新时不应可刷新。")
	_expect(not upgrade_system.refresh_choices(), "0 次刷新时 refresh 应返回 false。")
	await _free_node(main_node)


## 每次刷新消耗一次并换成不同的卡；用尽后不可再刷新。
func _test_refresh_consumes_and_redraws() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	upgrade_system.set_refresh_count(2)
	upgrade_system.set_random_seed(20260925)
	upgrade_system.request_choices(3)
	var first: Array[UpgradeDefinition] = upgrade_system.get_current_choices()
	_expect(upgrade_system.can_refresh(), "还有次数时应可刷新。")

	_expect(upgrade_system.refresh_choices(3), "第一次刷新应成功。")
	_expect(upgrade_system.get_remaining_refreshes() == 1, "刷新后应剩 1 次。")
	var second: Array[UpgradeDefinition] = upgrade_system.get_current_choices()
	_expect(second.size() == 3, "刷新后仍应给出三张卡。")
	var changed: bool = false
	for definition: UpgradeDefinition in second:
		if not first.has(definition):
			changed = true
			break
	_expect(changed, "刷新后应换成不同的卡。")

	_expect(upgrade_system.refresh_choices(3), "第二次刷新应成功。")
	_expect(upgrade_system.get_remaining_refreshes() == 0, "两次后应耗尽。")
	_expect(not upgrade_system.can_refresh(), "耗尽后不应可刷新。")
	await _free_node(main_node)


## 空升级池不给卡也不死锁。
func _test_empty_pool_no_deadlock() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	upgrade_system.set_refresh_count(2)
	upgrade_system.upgrade_pool = []
	upgrade_system.request_choices(3)
	_expect(upgrade_system.get_current_choices().is_empty(), "空池应给出空列表。")
	_expect(not upgrade_system.can_refresh(), "空池不应可刷新。")
	await _free_node(main_node)


## 连续升级之间刷新余额保留。
func _test_balance_persists_across_levels() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	upgrade_system.set_refresh_count(2)
	upgrade_system.set_random_seed(7)
	upgrade_system.request_choices(3)
	_expect(upgrade_system.refresh_choices(3), "第一次刷新应成功。")
	var chosen: UpgradeDefinition = upgrade_system.get_current_choices()[0]
	_expect(upgrade_system.apply_choice(chosen), "应能提交当前卡。")

	upgrade_system.request_choices(3)
	_expect(upgrade_system.get_remaining_refreshes() == 1, "跨升级应保留剩余刷新次数。")
	_expect(upgrade_system.can_refresh(), "下一次升级仍应可刷新。")
	await _free_node(main_node)


## 默认基础次数生效；入口把档案永久加成叠加进本局。
func _test_default_and_entry_bonus() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	_expect(
		session.upgrade_system.get_remaining_refreshes() == session.base_refresh_count,
		"直启应使用基础刷新次数。"
	)
	await _free_node(main_node)

	var store := ProfileStore.new(TEST_PROFILE_PATH)
	var profile: Profile = store.load_profile()
	profile.refresh_bonus = 2
	store.save_profile(profile)

	var entry := GameEntry.new()
	entry.catalog = load(CATALOG_PATH) as ContentCatalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = store
	root.add_child(entry)
	await process_frame
	var loadout: RunLoadout = RunLoadout.default_for(entry.catalog)
	entry._start_session(loadout)
	await process_frame
	var active: GameSession = entry.get_active_session()
	_expect(active != null, "入口应创建单局。")
	_expect(
		active.upgrade_system.get_remaining_refreshes() == active.base_refresh_count + 2,
		"本局刷新次数应为 基础+档案加成。"
	)
	entry.queue_free()
	await process_frame


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	return main_node


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
