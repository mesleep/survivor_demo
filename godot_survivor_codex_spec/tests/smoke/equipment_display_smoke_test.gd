## 装备图标与质变后名称专项回归。
##
## 覆盖未质变显示基础名与图标、质变后显示“基础名·分支名”并使用质变图标、
## 防具名称与图标。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const STAFF_PATH := "res://data/weapons/staff.tres"
const EXPLOSION_PATH := "res://data/upgrades/staff_explosion.tres"
const ARMOR_PATH := "res://data/armor/armor_basic.tres"

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_weapon_name_and_icon()
	await _test_armor_name_and_icon()
	if not _failed:
		print("Equipment display smoke test passed: icons and ascended names are valid.")
	quit(1 if _failed else 0)


## 质变前为基础名与武器图标；质变后为“基础名·分支名”与质变图标。
func _test_weapon_name_and_icon() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = session.player
	player.add_weapon(load(STAFF_PATH) as WeaponDefinition)
	_expect(player.get_equipment_display_name(&"staff") == "蓄力法杖", "未质变应显示基础名。")
	_expect(player.get_equipment_icon(&"staff") != null, "武器应能提供图标（回退首帧）。")

	for _index: int in range(4):
		player.add_equipment_base_level(&"staff")
	_expect(player.apply_upgrade(load(EXPLOSION_PATH) as UpgradeDefinition), "应能选择爆炸质变。")
	var ascended_name: String = player.get_equipment_display_name(&"staff")
	_expect(ascended_name.contains("爆炸法术"), "质变后名称应包含分支名。")
	_expect(not ascended_name.contains("质变："), "质变后名称不应带“质变：”前缀。")
	_expect(player.get_equipment_icon(&"staff") != null, "质变后应使用质变图标。")
	await _free_node(main_node)


## 防具显示自身名称与图标。
func _test_armor_name_and_icon() -> void:
	var main_node: Node = await _spawn_main()
	var session: GameSession = main_node.get_node("GameSession") as GameSession
	var player: PlayerActor = session.player
	_expect(player.try_acquire_armor(load(ARMOR_PATH) as ArmorDefinition), "应能装备基础盔甲。")
	_expect(player.get_equipment_display_name(&"armor_basic") == "基础盔甲", "防具应显示自身名称。")
	_expect(player.get_equipment_icon(&"armor_basic") != null, "防具应提供图标。")
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
