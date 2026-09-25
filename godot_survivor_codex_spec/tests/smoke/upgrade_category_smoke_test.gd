## T06：升级候选分类、前置、互斥与上限过滤的专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_category_filtering()
	await _test_choice_counts()
	if not _failed:
		print("Upgrade category smoke test passed: prerequisites, mutex, caps and counts are valid.")
	quit(1 if _failed else 0)


func _test_category_filtering() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var bow: WeaponDefinition = catalog.get_weapon(&"bow")

	var upgrade_system := UpgradeSystem.new()
	upgrade_system.initialize(player)

	# 通用始终可出。
	var generic: UpgradeDefinition = _make_upgrade(&"generic_test", UpgradeDefinition.UpgradeCategory.GENERIC)
	_expect(upgrade_system.can_offer(generic), "通用升级应始终可出。")

	# 获取卡：未持有可出，持有后不可出。
	var acquire_bow: UpgradeDefinition = _make_acquire(&"acquire_bow_test", bow)
	_expect(upgrade_system.can_offer(acquire_bow), "未持有时获取卡应可出。")
	player.configure_equipment([&"staff", &"bow"])
	_expect(player.try_acquire_weapon(bow), "应能获取长弓。")
	_expect(not upgrade_system.can_offer(acquire_bow), "已持有后获取卡不应再出。")

	# 基础升级卡：持有后可出，基础满级后不可出。
	var base_bow: UpgradeDefinition = _make_upgrade(
		&"base_bow_test", UpgradeDefinition.UpgradeCategory.BASE_UPGRADE,
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER, &"bow", &"", 4
	)
	_expect(upgrade_system.can_offer(base_bow), "持有后基础升级应可出。")
	for _index: int in range(EquipmentProgress.MAX_BASE_LEVEL - 1):
		player.add_equipment_base_level(&"bow")
	_expect(not upgrade_system.can_offer(base_bow), "基础满级后基础升级不应可出。")

	# 质变卡：满级后可出；选一条分支后两条分支均不可再出。
	var ascension_a: UpgradeDefinition = _make_upgrade(
		&"ascension_a", UpgradeDefinition.UpgradeCategory.ASCENSION,
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER, &"bow", &"branch_a", 1
	)
	var ascension_b: UpgradeDefinition = _make_upgrade(
		&"ascension_b", UpgradeDefinition.UpgradeCategory.ASCENSION,
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER, &"bow", &"branch_b", 1
	)
	_expect(upgrade_system.can_offer(ascension_a), "满级后质变卡应可出。")
	_expect(player.choose_equipment_branch(&"bow", &"branch_a"), "应能选择分支 A。")
	_expect(not upgrade_system.can_offer(ascension_a), "已选分支后同分支质变不应再出。")
	_expect(not upgrade_system.can_offer(ascension_b), "已选分支后其它分支质变不应再出。")

	# 分支专属卡：需匹配当前分支；与专属上限独立。
	var branch_a_up: UpgradeDefinition = _make_upgrade(
		&"branch_a_up", UpgradeDefinition.UpgradeCategory.BRANCH_UPGRADE,
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER, &"bow", &"branch_a", 3
	)
	var branch_b_up: UpgradeDefinition = _make_upgrade(
		&"branch_b_up", UpgradeDefinition.UpgradeCategory.BRANCH_UPGRADE,
		UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER, &"bow", &"branch_b", 3
	)
	_expect(upgrade_system.can_offer(branch_a_up), "匹配分支的专属升级应可出。")
	_expect(not upgrade_system.can_offer(branch_b_up), "其它分支专属升级不应可出。")
	for _index: int in range(EquipmentProgress.MAX_BRANCH_UPGRADE_LEVEL):
		player.add_equipment_branch_upgrade(&"bow", &"branch_a_up")
	_expect(not upgrade_system.can_offer(branch_a_up), "专属升级满级后不应再出。")

	upgrade_system.free()
	await _free_node(main_node)


func _test_choice_counts() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var upgrade_system := UpgradeSystem.new()
	upgrade_system.initialize(player)

	var generics: Array[UpgradeDefinition] = []
	for index: int in range(4):
		generics.append(_make_upgrade(StringName("g%d" % index), UpgradeDefinition.UpgradeCategory.GENERIC))
	upgrade_system.upgrade_pool = generics
	upgrade_system.request_choices(3)
	var choices: Array[UpgradeDefinition] = upgrade_system.get_current_choices()
	_expect(choices.size() == 3, "候选充足时应给出 3 张。")
	var unique_ids: Dictionary[StringName, bool] = {}
	for choice: UpgradeDefinition in choices:
		unique_ids[choice.id] = true
	_expect(unique_ids.size() == choices.size(), "三选一出现重复。")

	# 不足三张时返回实际数量。
	upgrade_system.upgrade_pool = [generics[0], generics[1]]
	upgrade_system.request_choices(3)
	_expect(upgrade_system.get_current_choices().size() == 2, "不足三张时应返回实际数量。")

	# 全部不可用时返回空，交由 GameSession 安全恢复。
	player.configure_equipment([&"staff"])
	var missing: WeaponDefinition = _make_weapon(&"missing_weapon")
	var blocked: UpgradeDefinition = _make_acquire(&"blocked_acquire", missing)
	upgrade_system.upgrade_pool = [blocked]
	upgrade_system.request_choices(3)
	_expect(upgrade_system.get_current_choices().is_empty(), "无可用项时应返回空列表。")

	upgrade_system.free()
	await _free_node(main_node)


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _make_upgrade(
		id: StringName,
		category: UpgradeDefinition.UpgradeCategory,
		type: UpgradeDefinition.UpgradeType = UpgradeDefinition.UpgradeType.DAMAGE_MULTIPLIER,
		target: StringName = &"",
		branch: StringName = &"",
		max_stacks: int = 5
) -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = id
	upgrade.display_name = String(id)
	upgrade.category = category
	upgrade.type = type
	upgrade.target_equipment_id = target
	upgrade.branch_id = branch
	upgrade.max_stacks = max_stacks
	return upgrade


func _make_acquire(id: StringName, weapon: WeaponDefinition) -> UpgradeDefinition:
	var upgrade := _make_upgrade(id, UpgradeDefinition.UpgradeCategory.ACQUIRE_EQUIPMENT)
	upgrade.type = UpgradeDefinition.UpgradeType.ACQUIRE_WEAPON
	upgrade.weapon_definition = weapon
	upgrade.max_stacks = 1
	return upgrade


func _make_weapon(id: StringName) -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.id = id
	weapon.display_name = String(id)
	return weapon


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
