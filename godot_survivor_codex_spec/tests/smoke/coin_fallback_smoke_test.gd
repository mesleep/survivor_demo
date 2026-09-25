## 满级后金币兜底升级专项回归。
##
## 覆盖池空/全部满级时给出金币卡并正确加币、正常情况不出现兜底卡。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_fallback_when_pool_empty()
	await _test_fallback_when_all_maxed()
	await _test_no_fallback_when_available()
	if not _failed:
		print("Coin fallback smoke test passed: fallback card and coin reward are valid.")
	quit(1 if _failed else 0)


## 池为空时给出金币卡，选择后增加金币。
func _test_fallback_when_pool_empty() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	upgrade_system.upgrade_pool = []
	upgrade_system.set_random_seed(1)
	upgrade_system.request_choices(3)
	var choices: Array[UpgradeDefinition] = upgrade_system.get_current_choices()
	_expect(choices.size() == 1 and choices[0].id == &"coin_reward", "池空时应给出金币兜底卡。")

	var before: int = session.player.get_run_coins()
	_expect(upgrade_system.apply_choice(choices[0]), "应能选择金币卡。")
	_expect(session.player.get_run_coins() == before + 12, "选择金币卡应增加 12 金币。")
	await _free_node(main_node)


## 唯一升级满级后给出金币卡。
func _test_fallback_when_all_maxed() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	var damage_up: UpgradeDefinition = load("res://data/upgrades/damage_up.tres") as UpgradeDefinition
	upgrade_system.upgrade_pool = [damage_up]
	for _index: int in range(damage_up.max_stacks):
		session.player.apply_upgrade(damage_up)
	upgrade_system.set_random_seed(2)
	upgrade_system.request_choices(3)
	var choices: Array[UpgradeDefinition] = upgrade_system.get_current_choices()
	_expect(choices.size() == 1 and choices[0].id == &"coin_reward", "全部满级后应给出金币卡。")
	await _free_node(main_node)


## 正常有可用升级时不应出现金币兜底卡。
func _test_no_fallback_when_available() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var upgrade_system: UpgradeSystem = session.upgrade_system
	upgrade_system.set_random_seed(3)
	upgrade_system.request_choices(3)
	for definition: UpgradeDefinition in upgrade_system.get_current_choices():
		_expect(definition.id != &"coin_reward", "有可用升级时不应出现金币兜底卡。")
	await _free_node(main_node)


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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
