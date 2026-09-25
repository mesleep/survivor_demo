## 本轮平衡修订：质变保底、候选武器隔离、测试解锁、Boss 弹幕与持续刷怪。
extends SceneTree

const SESSION_PATH := "res://scenes/bootstrap/main.tscn"
const MENU_PATH := "res://scenes/ui/main_menu.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const PERMANENT_PATH := "res://data/progression/permanent_catalog.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_upgrades_and_boss()
	await _test_unlock_button()
	if not _failed:
		print("Balance revision smoke test passed: progression, roster, unlock, boss and spawn.")
	paused = false
	quit(1 if _failed else 0)


func _test_upgrades_and_boss() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	_expect(catalog.get_weapon_ids() == [&"bow", &"staff", &"sword"], "可玩武器目录应只含弓、法杖、剑。")
	var main: Node = (load(SESSION_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var session: GameSession = main.get_node("GameSession") as GameSession
	var player: PlayerActor = session.player
	var system: UpgradeSystem = session.upgrade_system
	_expect(player.has_weapon(&"staff") and not player.has_weapon(&"bow"), "默认角色应只持有法杖。")
	var bow_base: UpgradeDefinition = load("res://data/upgrades/bow_base.tres") as UpgradeDefinition
	var staff_base: UpgradeDefinition = load("res://data/upgrades/staff_base.tres") as UpgradeDefinition
	_expect(not system.can_offer(bow_base) and system.can_offer(staff_base), "未持有弓时不可出现弓的专属 Buff。")
	for definition: UpgradeDefinition in system.upgrade_pool:
		_expect(not String(definition.id).begins_with("star_wand") and not String(definition.id).contains("leaf") \
			and not String(definition.id).contains("bone") and not String(definition.id).contains("bell"), "旧武器升级卡仍在可玩池中。")
	system.set_random_seed(17)
	for _level: int in range(EquipmentProgress.MAX_BASE_LEVEL - 1):
		system.request_choices(3)
		_expect(system.get_current_choices().has(staff_base), "基础成长卡应保底出现。")
		_expect(player.add_equipment_base_level(&"staff"), "法杖基础等级提升失败。")
	var ascension_count: int = 0
	for _draw: int in range(20):
		system.request_choices(3)
		var has_ascension: bool = false
		for card: UpgradeDefinition in system.get_current_choices():
			if card.category == UpgradeDefinition.UpgradeCategory.ASCENSION:
				has_ascension = true
		if has_ascension:
			ascension_count += 1
	_expect(ascension_count == 20, "满足条件的质变应每次三选一都出现。")

	session.advance_time(session.run_definition.run_duration_seconds)
	_expect(is_instance_valid(session.boss), "五分钟应生成 Boss。")
	_expect(not session.enemy_spawner.spawn_timer.is_stopped(), "Boss 登场后小怪生成必须继续。")
	_expect(session.boss.definition.attack_type == EnemyDefinition.AttackType.HYBRID, "Boss 应兼有远程和近战能力。")
	_expect(session.boss.health_component.maximum_health >= 1500.0, "Boss 在末阶段应有足够生命。")
	var added: Array[EnemyActor] = session.enemy_spawner.spawn_batch()
	_expect(not added.is_empty(), "Boss 登场后应能继续生成小怪。")
	session.boss.global_position = player.global_position + Vector2(260.0, 0.0)
	await physics_frame
	await physics_frame
	var bolts: int = 0
	for child: Node in session.projectiles.get_children():
		if child is ProjectileBase and (child as ProjectileBase).definition.id == &"boss_bolt":
			bolts += 1
	_expect(bolts >= 3, "Boss 应发射三向远程弹幕。")
	main.queue_free()
	await process_frame


func _test_unlock_button() -> void:
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var permanent: PermanentUpgradeCatalog = load(PERMANENT_PATH) as PermanentUpgradeCatalog
	var path := "user://balance_revision_test_profile.json"
	var store := ProfileStore.new(path)
	store.delete_save()
	var profile := Profile.new()
	profile.unlocked_character_ids = [&"player_default"]
	profile.unlocked_weapon_ids = [&"staff"]
	var service := UnlockService.new(profile, store)
	var menu: MainMenu = (load(MENU_PATH) as PackedScene).instantiate() as MainMenu
	menu.catalog = catalog
	menu.configure_profile(profile, service, permanent)
	root.add_child(menu)
	await process_frame
	_expect(menu.unlock_all_button.visible, "测试解锁按钮应在主菜单可见。")
	menu.unlock_all_button.pressed.emit()
	for id: StringName in catalog.get_character_ids():
		_expect(profile.is_character_unlocked(id), "角色未被测试按钮解锁。")
	for id: StringName in catalog.get_weapon_ids():
		_expect(profile.is_weapon_unlocked(id), "武器未被测试按钮解锁。")
	for definition: PermanentUpgradeDefinition in permanent.upgrades:
		_expect(profile.get_permanent_level(definition.id) == definition.max_level, "永久强化未升满。")
	_expect(profile.refresh_bonus >= 5, "测试档案未获得足够刷新次数。")
	_expect(store.has_save(), "一键解锁后应持久化。")
	menu.queue_free()
	await process_frame
	store.delete_save()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
