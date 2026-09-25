## T04：六格装备清单、候选池过滤与升级获取过滤的专项回归。
##
## 覆盖起始武器占格、候选池限制、重复获取、满格、专属升级仍可用，
## 以及重开后装备清空重建。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const DAMAGE_UP_PATH := "res://data/upgrades/damage_up.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_slots_and_candidates()
	await _test_upgrade_filtering()
	await _test_restart_clears()
	if not _failed:
		print("Equipment slots smoke test passed: capacity, candidates, filtering and restart are valid.")
	quit(1 if _failed else 0)


func _test_slots_and_candidates() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	_expect(player.get_equipped_count() == 1, "起始应只有一把起始武器占格。")
	_expect(player.has_equipment(&"starter_weapon"), "起始武器未登记装备。")

	var extra: Array[WeaponDefinition] = []
	for index: int in range(8):
		extra.append(_make_weapon(StringName("t%d" % index)))
	var candidates: Array[StringName] = [&"starter_weapon"]
	for weapon: WeaponDefinition in extra:
		candidates.append(weapon.id)
	player.configure_equipment(candidates)

	var emissions: Array[int] = [0]
	player.equipment_changed.connect(func(_ids: Array[StringName]) -> void: emissions[0] += 1)

	# 非候选武器不可获取。
	var outsider: WeaponDefinition = _make_weapon(&"outsider")
	_expect(not player.try_acquire_weapon(outsider), "非候选武器不应被获取。")

	# 1（起始）+ 5 = 6，满格；第 7 件被拒。
	for index: int in range(5):
		_expect(player.try_acquire_weapon(extra[index]), "第 %d 件应可获取。" % (index + 2))
	_expect(player.get_equipped_count() == PlayerActor.MAX_EQUIPMENT_SLOTS, "应正好满 6 格。")
	_expect(player.is_equipment_full(), "满格判定错误。")
	_expect(not player.try_acquire_weapon(extra[5]), "第七件应被拒绝。")
	# 重复获取不占格。
	_expect(not player.try_acquire_weapon(extra[0]), "重复获取应被拒绝。")
	_expect(player.get_equipped_count() == PlayerActor.MAX_EQUIPMENT_SLOTS, "重复获取改变了格数。")
	_expect(emissions[0] == 5, "装备变化信号次数不正确：%d。" % emissions[0])

	await _free_node(main_node)


func _test_upgrade_filtering() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player

	var spare: WeaponDefinition = _make_weapon(&"spare")
	var fillers: Array[WeaponDefinition] = []
	for index: int in range(4):
		fillers.append(_make_weapon(StringName("f%d" % index)))
	var candidates: Array[StringName] = [&"starter_weapon", &"spare"]
	for weapon: WeaponDefinition in fillers:
		candidates.append(weapon.id)
	player.configure_equipment(candidates)

	var acquire_spare: UpgradeDefinition = _make_acquire_upgrade(&"acquire_spare", spare)
	var acquire_outsider: UpgradeDefinition = _make_acquire_upgrade(&"acquire_outsider", _make_weapon(&"outsider"))
	var damage_up: UpgradeDefinition = load(DAMAGE_UP_PATH) as UpgradeDefinition
	var upgrade_system := UpgradeSystem.new()
	upgrade_system.upgrade_pool = [acquire_spare, acquire_outsider, damage_up]
	upgrade_system.initialize(player)

	_expect(upgrade_system.can_offer(acquire_spare), "候选池内空位时应提供获取卡。")
	_expect(not upgrade_system.can_offer(acquire_outsider), "非候选武器不应提供获取卡。")
	_expect(upgrade_system.can_offer(damage_up), "通用升级应始终可用。")

	# 占满全部格后，获取卡消失，但通用升级仍在。
	for weapon: WeaponDefinition in fillers:
		player.try_acquire_weapon(weapon)
	player.try_acquire_weapon(spare)
	_expect(player.is_equipment_full(), "升级过滤测试未填满装备。")
	_expect(not upgrade_system.can_offer(acquire_spare), "满格后不应再提供获取卡。")
	_expect(upgrade_system.can_offer(damage_up), "满格后通用升级仍应可用。")

	upgrade_system.request_choices(3)
	for choice: UpgradeDefinition in upgrade_system.get_current_choices():
		_expect(
			choice.type != UpgradeDefinition.UpgradeType.ACQUIRE_WEAPON,
			"满格后三选一仍出现获取卡：%s。" % choice.id
		)

	upgrade_system.free()
	await _free_node(main_node)


func _test_restart_clears() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var extra: WeaponDefinition = _make_weapon(&"r0")
	player.configure_equipment([&"starter_weapon", &"r0"])
	_expect(player.try_acquire_weapon(extra), "重开前应能获取额外武器。")
	_expect(player.get_equipped_count() == 2, "重开前装备数不正确。")

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
		_expect(new_session.player.get_equipped_count() == 1, "重开残留了旧装备。")
		_expect(new_session.player.has_equipment(&"starter_weapon"), "重开缺少起始武器。")
		_expect(not new_session.player.has_equipment(&"r0"), "重开残留了已获取武器。")


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


func _make_weapon(id: StringName) -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.id = id
	weapon.display_name = String(id)
	return weapon


func _make_acquire_upgrade(id: StringName, weapon: WeaponDefinition) -> UpgradeDefinition:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = id
	upgrade.type = UpgradeDefinition.UpgradeType.ACQUIRE_WEAPON
	upgrade.weapon_definition = weapon
	upgrade.max_stacks = 1
	return upgrade


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
