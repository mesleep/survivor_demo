## T31：远程射手角色与被动专项回归。
##
## 覆盖被动只作用于带标签武器、两名角色同武器差异、切换角色属性、
## 解锁条件、重开隔离与共享 Resource 不变。
extends SceneTree

const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const SESSION_SCENE_PATH := "res://scenes/gameplay/game_session.tscn"
const TEST_PROFILE_PATH := "user://profile_test_t31/profile.json"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	await _test_passive_ranged_only()
	await _test_two_characters_difference_and_switch()
	await _test_unlock_and_restart_isolation()
	_test_shared_resource_unchanged()
	_cleanup()
	if not _failed:
		print("Ranger character smoke test passed: passive tag, character switch, unlock and isolation are valid.")
	quit(1 if _failed else 0)


## 被动只加成带 ranged 标签的武器，未打标签武器不受影响。
func _test_passive_ranged_only() -> void:
	var entry: GameEntry = await _spawn_entry()
	var catalog: ContentCatalog = entry.catalog
	entry._start_session(RunLoadout.default_for(catalog, &"player_ranger"))
	await process_frame
	var player: PlayerActor = entry.get_active_session().player
	_expect(is_equal_approx(player.get_passive_damage_multiplier(), 1.1), "射手被动应为 1.1。")
	_expect(player.get_passive_weapon_tag() == &"ranged", "被动标签应为 ranged。")

	var bow: WeaponController = _find_controller(player, &"bow")
	_expect(
		bow != null and is_equal_approx(bow.get_runtime_damage_multiplier(), 1.1),
		"带标签的长弓应吃到被动。"
	)

	var plain := WeaponDefinition.new()
	plain.id = &"test_plain"
	plain.projectile_definition = load("res://data/projectiles/basic_projectile.tres") as ProjectileDefinition
	_expect(player.add_weapon(plain), "应能加入无标签测试武器。")
	var plain_controller: WeaponController = _find_controller(player, &"test_plain")
	_expect(
		plain_controller != null and is_equal_approx(plain_controller.get_runtime_damage_multiplier(), 1.0),
		"无标签武器不应吃到被动。"
	)
	entry.queue_free()
	await process_frame


## 同武器在两角色下被动不同；切换角色属性正确。
func _test_two_characters_difference_and_switch() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog

	var mage_entry: GameEntry = await _spawn_entry()
	mage_entry._start_session(RunLoadout.default_for(catalog, &"player_default"))
	await process_frame
	var mage: PlayerActor = mage_entry.get_active_session().player
	_expect(is_equal_approx(mage.get_effective_move_speed(), 220.0), "法师移速应为 220。")
	mage_entry.queue_free()
	await process_frame

	var ranger_entry: GameEntry = await _spawn_entry()
	ranger_entry._start_session(RunLoadout.default_for(catalog, &"player_ranger"))
	await process_frame
	var ranger: PlayerActor = ranger_entry.get_active_session().player
	_expect(is_equal_approx(ranger.get_effective_move_speed(), 230.0), "射手移速应为 230。")
	_expect(is_equal_approx(ranger.health_component.maximum_health, 90.0), "射手最大生命应为 90。")
	var ranger_bow: WeaponController = _find_controller(ranger, &"bow")
	_expect(
		ranger_bow != null and is_equal_approx(ranger_bow.get_runtime_damage_multiplier(), 1.1),
		"射手长弓应为 1.1。"
	)

	# 再开法师一局，确认被动不会残留到别的角色。
	var second_mage: GameEntry = await _spawn_entry()
	second_mage._start_session(RunLoadout.default_for(catalog, &"player_default"))
	await process_frame
	var second_player: PlayerActor = second_mage.get_active_session().player
	second_player.add_weapon(catalog.get_weapon(&"bow"))
	var second_bow: WeaponController = _find_controller(second_player, &"bow")
	_expect(
		second_bow != null and is_equal_approx(second_bow.get_runtime_damage_multiplier(), 1.0),
		"法师不应继承射手被动。"
	)
	ranger_entry.queue_free()
	second_mage.queue_free()
	await process_frame


## 射手默认锁定，购买后解锁；重开隔离由新场景保证。
func _test_unlock_and_restart_isolation() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var store: ProfileStore = _make_store()
	var entry: GameEntry = await _spawn_entry(store)
	var profile: Profile = entry.get_profile()
	_expect(not profile.is_character_unlocked(&"player_ranger"), "射手应默认锁定。")
	_expect(profile.is_character_unlocked(&"player_default"), "默认角色应解锁。")

	profile.coins = 200
	_expect(
		entry.unlock_service.purchase_character(catalog, &"player_ranger")
		== UnlockService.Result.SUCCESS,
		"余额充足应解锁射手。"
	)
	_expect(profile.coins == 80 and profile.is_character_unlocked(&"player_ranger"), "应扣 120 并解锁。")
	_expect(
		_make_store().load_profile().is_character_unlocked(&"player_ranger"),
		"解锁应持久化。"
	)
	entry.queue_free()
	await process_frame


func _test_shared_resource_unchanged() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var ranger: CharacterDefinition = catalog.get_character(&"player_ranger")
	_expect(is_equal_approx(ranger.passive_damage_multiplier, 0.1), "共享射手定义不应被回写。")
	var bow: WeaponDefinition = catalog.get_weapon(&"bow")
	_expect(bow.tags.has(&"ranged"), "共享长弓标签不应被回写。")


func _spawn_entry(store: ProfileStore = null) -> GameEntry:
	var entry := GameEntry.new()
	entry.catalog = load(CATALOG_PATH) as ContentCatalog
	entry.menu_scene = load(MENU_SCENE_PATH) as PackedScene
	entry.session_scene = load(SESSION_SCENE_PATH) as PackedScene
	entry.profile_store = store if store != null else _make_store()
	root.add_child(entry)
	await process_frame
	return entry


func _find_controller(player: PlayerActor, weapon_id: StringName) -> WeaponController:
	for controller: WeaponController in player.weapon_controllers:
		if is_instance_valid(controller) and controller.definition.id == weapon_id:
			return controller
	return null


func _make_store() -> ProfileStore:
	return ProfileStore.new(TEST_PROFILE_PATH)


func _cleanup() -> void:
	ProfileStore.new(TEST_PROFILE_PATH).delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
