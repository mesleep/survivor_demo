## T08：防具静态定义、与武器共用六格、类别装配与重开的专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_armor_coexists_with_weapons()
	await _test_full_slots_block_armor()
	await _test_invalid_and_duplicate()
	await _test_upgrade_acquisition()
	await _test_restart_clears()
	if not _failed:
		print("Armor equipment smoke test passed: coexist, capacity, categories and restart are valid.")
	quit(1 if _failed else 0)


func _test_armor_coexists_with_weapons() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var weapons: Array[WeaponDefinition] = _make_weapons(5)
	player.configure_equipment([&"starter_weapon", weapons[0].id, weapons[1].id, weapons[2].id, weapons[3].id, weapons[4].id])
	for weapon: WeaponDefinition in weapons:
		_expect(player.try_acquire_weapon(weapon), "应能获取武器 %s。" % weapon.id)
	_expect(player.get_equipped_count() == PlayerActor.MAX_EQUIPMENT_SLOTS, "六把武器应占满 6 格。")

	var armor: ArmorDefinition = _make_armor(&"armor_basic", ArmorDefinition.ArmorCategory.ARMOR)
	# 已满格时防具不可获取。
	_expect(not player.can_acquire_armor(armor), "满格时防具不应可获取。")
	_expect(not player.try_acquire_armor(armor), "满格时防具获取应失败。")
	await _free_node(main_node)

	# 五把武器 + 一件防具 = 6。
	var main_node_b: Node = await _spawn_main()
	var session_b: GameSession = main_node_b.get_node("GameSession") as GameSession
	session_b.enemy_spawner.stop()
	var player_b: PlayerActor = session_b.player
	var weapons_b: Array[WeaponDefinition] = _make_weapons(4)
	player_b.configure_equipment([
		&"starter_weapon", weapons_b[0].id, weapons_b[1].id, weapons_b[2].id, weapons_b[3].id
	])
	for weapon: WeaponDefinition in weapons_b:
		player_b.try_acquire_weapon(weapon)
	_expect(player_b.get_equipped_count() == 5, "应为 5 件。")
	var weapon_controller_count: int = player_b.weapon_controllers.size()
	_expect(player_b.try_acquire_armor(armor), "空位时防具应可获取。")
	_expect(player_b.get_equipped_count() == 6, "武器与防具应共用格数。")
	_expect(player_b.get_equipped_category(armor.id) == &"armor", "防具类别未登记。")
	_expect(player_b.get_equipped_weapon_ids().size() == 5, "武器类别计数不正确。")
	_expect(player_b.get_equipped_armor_ids().size() == 1, "防具类别计数不正确。")
	# 防具不是武器：不创建控制器，不能当武器发射。
	_expect(not player_b.has_weapon(armor.id), "防具被误登记为武器。")
	_expect(player_b.weapon_controllers.size() == weapon_controller_count, "防具创建了武器控制器。")
	_expect(player_b.has_equipment(armor.id), "防具未登记进装备清单。")
	_expect(player_b.get_armor_definition(armor.id) == armor, "防具定义读取失败。")
	await _free_node(main_node_b)


func _test_full_slots_block_armor() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var weapons: Array[WeaponDefinition] = _make_weapons(5)
	var candidate_ids: Array[StringName] = [&"starter_weapon"]
	for weapon: WeaponDefinition in weapons:
		candidate_ids.append(weapon.id)
	player.configure_equipment(candidate_ids)
	for weapon: WeaponDefinition in weapons:
		player.try_acquire_weapon(weapon)
	_expect(player.get_equipped_count() == 6, "应满 6 格武器。")
	var armor: ArmorDefinition = _make_armor(&"armor_basic", ArmorDefinition.ArmorCategory.ARMOR)
	_expect(not player.try_acquire_armor(armor), "六把武器后防具不应可获取。")
	await _free_node(main_node)


func _test_invalid_and_duplicate() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	_expect(not player.try_acquire_armor(null), "空防具不应被获取。")
	var empty_armor: ArmorDefinition = ArmorDefinition.new()
	_expect(not player.try_acquire_armor(empty_armor), "空 ID 防具不应被获取。")
	var armor: ArmorDefinition = _make_armor(&"armor_basic", ArmorDefinition.ArmorCategory.HELMET)
	_expect(player.try_acquire_armor(armor), "有效防具应可获取。")
	_expect(not player.try_acquire_armor(armor), "重复获取防具应被拒绝。")
	_expect(player.get_equipped_count() == 2, "重复获取不应占新格。")
	await _free_node(main_node)


func _test_upgrade_acquisition() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var armor: ArmorDefinition = _make_armor(&"armor_basic", ArmorDefinition.ArmorCategory.ARMOR)
	var upgrade := UpgradeDefinition.new()
	upgrade.id = &"acquire_armor_basic"
	upgrade.category = UpgradeDefinition.UpgradeCategory.ACQUIRE_EQUIPMENT
	upgrade.type = UpgradeDefinition.UpgradeType.ACQUIRE_ARMOR
	upgrade.armor_definition = armor
	upgrade.max_stacks = 1
	var upgrade_system := UpgradeSystem.new()
	upgrade_system.initialize(player)
	upgrade_system.upgrade_pool = [upgrade]
	_expect(upgrade_system.can_offer(upgrade), "未持有时防具获取卡应可出。")
	_expect(player.apply_upgrade(upgrade), "防具获取卡应能应用。")
	_expect(player.has_armor(armor.id), "应用后应持有防具。")
	_expect(not upgrade_system.can_offer(upgrade), "已持有后防具获取卡不应再出。")
	upgrade_system.free()
	await _free_node(main_node)


func _test_restart_clears() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var armor: ArmorDefinition = _make_armor(&"armor_basic", ArmorDefinition.ArmorCategory.GLOVES)
	_expect(player.try_acquire_armor(armor), "重开前应能获取防具。")
	session.restart_run()
	await process_frame
	await process_frame
	var reloaded: Node = current_scene
	if reloaded == null:
		reloaded = root.get_child(root.get_child_count() - 1)
	var new_session: GameSession = reloaded.get_node("GameSession") as GameSession
	_expect(new_session != null and new_session.player != null, "重开未创建新单局。")
	if new_session != null and new_session.player != null:
		new_session.enemy_spawner.stop()
		_expect(not new_session.player.has_armor(armor.id), "重开残留了防具。")
		_expect(new_session.player.get_equipped_count() == 1, "重开装备数不正确。")
		_expect(new_session.player.get_equipped_armor_ids().is_empty(), "重开残留防具类别。")


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _make_weapons(count: int) -> Array[WeaponDefinition]:
	var weapons: Array[WeaponDefinition] = []
	for index: int in range(count):
		var weapon := WeaponDefinition.new()
		weapon.id = StringName("test_weapon_%d" % index)
		weapon.display_name = "Test Weapon %d" % index
		weapons.append(weapon)
	return weapons


func _make_armor(id: StringName, category: ArmorDefinition.ArmorCategory) -> ArmorDefinition:
	var armor := ArmorDefinition.new()
	armor.id = id
	armor.display_name = String(id)
	armor.category = category
	return armor


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
