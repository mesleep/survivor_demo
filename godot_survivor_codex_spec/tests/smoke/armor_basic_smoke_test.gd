## T11：基础盔甲防御、移速惩罚、升级减轻与重开的专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"
const ARMOR_UP_PATH := "res://data/upgrades/armor_basic_up.tres"
const ACQUIRE_ARMOR_PATH := "res://data/upgrades/acquire_armor_basic.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_armor_effects()
	await _test_restart_clears()
	if not _failed:
		print("Basic armor smoke test passed: defense, move penalty, upgrades and restart are valid.")
	quit(1 if _failed else 0)


func _test_armor_effects() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var armor: ArmorDefinition = catalog.get_armor(&"armor_basic")
	_expect(armor != null, "目录缺少基础盔甲。")
	if armor == null:
		await _free_node(main_node)
		return

	_expect(is_equal_approx(player.get_defense(), 0.0), "初始防御应为 0。")
	var base_move: float = player.get_effective_move_speed()
	_expect(is_equal_approx(base_move, 220.0), "初始移速应为 220。")

	var upgrade_system := UpgradeSystem.new()
	upgrade_system.initialize(player)
	var acquire_card: UpgradeDefinition = load(ACQUIRE_ARMOR_PATH) as UpgradeDefinition
	_expect(upgrade_system.can_offer(acquire_card), "未持有时盔甲获取卡应可出。")
	_expect(player.try_acquire_armor(armor), "应能获取基础盔甲。")
	_expect(not upgrade_system.can_offer(acquire_card), "已持有后盔甲获取卡不应再出。")

	_expect(is_equal_approx(player.get_defense(), 3.0), "1 级盔甲防御应为 3。")
	_expect(is_equal_approx(player.get_effective_move_speed(), 220.0 * 0.92), "1 级盔甲移速应为 -8%。")
	var result: DamageResult = player.apply_damage(DamageEvent.new(20.0, null, Vector2.ZERO))
	_expect(is_equal_approx(result.applied_amount, 17.0), "防御 3 时 20 伤害应剩 17。")

	var armor_up: UpgradeDefinition = load(ARMOR_UP_PATH) as UpgradeDefinition
	_expect(player.apply_upgrade(armor_up), "盔甲基础升级应成功。")
	_expect(is_equal_approx(player.get_defense(), 5.0), "2 级盔甲防御应为 5。")
	_expect(is_equal_approx(player.get_effective_move_speed(), 220.0 * 0.94), "2 级盔甲惩罚应减轻到 -6%。")
	for _index: int in range(armor_up.max_stacks - 1):
		player.apply_upgrade(armor_up)
	_expect(player.get_progress(&"armor_basic").base_level == EquipmentProgress.MAX_BASE_LEVEL, "盔甲应满级。")
	_expect(is_equal_approx(player.get_defense(), 11.0), "满级盔甲防御应为 3+2×4=11。")
	_expect(is_equal_approx(player.get_effective_move_speed(), 220.0), "满级盔甲惩罚应降为 0。")
	_expect(not upgrade_system.can_offer(armor_up), "满级后盔甲强化卡不应再出。")

	# 重复获取不叠加。
	_expect(not player.try_acquire_armor(armor), "重复获取盔甲应被拒绝。")
	_expect(is_equal_approx(player.get_defense(), 11.0), "重复获取改变了防御。")

	upgrade_system.free()
	await _free_node(main_node)


func _test_restart_clears() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var armor: ArmorDefinition = catalog.get_armor(&"armor_basic")
	player.try_acquire_armor(armor)
	_expect(player.get_defense() > 0.0, "重开前应有防御。")
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
		_expect(is_equal_approx(new_session.player.get_defense(), 0.0), "重开残留防御。")
		_expect(is_equal_approx(new_session.player.get_effective_move_speed(), 220.0), "重开残留移速惩罚。")
		_expect(not new_session.player.has_armor(&"armor_basic"), "重开残留盔甲。")


func _spawn_main() -> Node:
	var main_node: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main_node)
	await process_frame
	return main_node


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
