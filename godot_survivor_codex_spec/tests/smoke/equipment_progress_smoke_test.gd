## T05：单件装备等级/质变运行时模型与共享 Resource 隔离的专项回归。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const CATALOG_PATH := "res://data/catalog/default_catalog.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_progress_model()
	await _test_snapshot_and_resource_isolation()
	await _test_restart_resets()
	if not _failed:
		print("Equipment progress smoke test passed: levels, branches, isolation and restart are valid.")
	quit(1 if _failed else 0)


func _test_progress_model() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player

	_expect(player.get_progress(&"unknown") == null, "未持有装备不应有成长状态。")
	var progress: EquipmentProgress = player.get_progress(&"starter_weapon")
	_expect(progress != null, "起始武器缺少成长状态。")
	if progress == null:
		await _free_node(main_node)
		return
	_expect(progress.base_level == 1, "初始基础等级应为 1。")
	_expect(not progress.has_branch(), "初始不应有质变分支。")
	_expect(not player.can_choose_equipment_branch(&"starter_weapon", &"branch_a"), "未满级不应可选质变。")
	_expect(not player.choose_equipment_branch(&"starter_weapon", &"branch_a"), "未满级不应能选质变。")

	for _index: int in range(EquipmentProgress.MAX_BASE_LEVEL - 1):
		_expect(player.add_equipment_base_level(&"starter_weapon"), "基础升级应成功。")
	_expect(player.get_progress(&"starter_weapon").is_base_maxed(), "基础等级应已满。")
	_expect(not player.add_equipment_base_level(&"starter_weapon"), "超过基础上限应被拒绝。")

	_expect(player.can_choose_equipment_branch(&"starter_weapon", &"star_burst"), "满级后应可选质变。")
	_expect(player.choose_equipment_branch(&"starter_weapon", &"star_burst"), "应能选择质变分支。")
	_expect(not player.choose_equipment_branch(&"starter_weapon", &"star_focus"), "已选分支后不应改选。")
	_expect(player.get_progress(&"starter_weapon").branch_id == &"star_burst", "分支 ID 不正确。")

	for _index: int in range(EquipmentProgress.MAX_BRANCH_UPGRADE_LEVEL):
		_expect(player.add_equipment_branch_upgrade(&"starter_weapon", &"burst_count"), "专属升级应成功。")
	_expect(
		not player.add_equipment_branch_upgrade(&"starter_weapon", &"burst_count"),
		"超过专属上限应被拒绝。"
	)
	_expect(
		player.add_equipment_branch_upgrade(&"starter_weapon", &"burst_pierce"),
		"不同专属升级应各有独立层数。"
	)

	await _free_node(main_node)


func _test_snapshot_and_resource_isolation() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	var catalog: ContentCatalog = load(CATALOG_PATH) as ContentCatalog
	var leaf: WeaponDefinition = catalog.get_weapon(&"leaf")
	var projectile_damage_before: float = leaf.projectile_definition.damage
	var cooldown_before: float = leaf.cooldown_seconds

	player.configure_equipment([&"starter_weapon", &"leaf"])
	_expect(player.try_acquire_weapon(leaf), "应能获取飞叶刃。")
	_expect(not player.try_acquire_weapon(leaf), "重复获取应被拒绝。")
	_expect(player.get_equipped_count() == 2, "重复获取不应占新格。")

	# 快照隔离：修改快照不影响局内状态。
	var snapshot: EquipmentProgress = player.get_progress(&"leaf")
	_expect(snapshot.add_base_level(), "快照应可独立升级。")
	_expect(player.get_progress(&"leaf").base_level == 1, "修改快照污染了局内成长状态。")

	# 共享 Resource 隔离：装备成长不写入武器/子弹定义。
	_expect(leaf.cooldown_seconds == cooldown_before, "武器冷却被运行时状态回写。")
	_expect(leaf.projectile_definition.damage == projectile_damage_before, "子弹伤害被运行时状态回写。")

	await _free_node(main_node)


func _test_restart_resets() -> void:
	var main_node: Node = await _spawn_main()
	current_scene = main_node
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	session.enemy_spawner.stop()
	var player: PlayerActor = session.player
	player.add_equipment_base_level(&"starter_weapon")
	player.add_equipment_base_level(&"starter_weapon")
	_expect(player.get_progress(&"starter_weapon").base_level == 3, "重开前升级未生效。")

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
		var fresh: EquipmentProgress = new_session.player.get_progress(&"starter_weapon")
		_expect(fresh != null and fresh.base_level == 1, "重开残留了基础等级。")
		_expect(fresh != null and not fresh.has_branch(), "重开残留了质变分支。")


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
