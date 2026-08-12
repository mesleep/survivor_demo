## P2-03 武器配置烟雾检查。
##
## 验证默认武器 Resource、强类型起始武器列表和基础参数。
extends SceneTree

const PLAYER_DEFINITION_PATH := "res://data/characters/player_default.tres"
const STARTER_WEAPON_PATH := "res://data/weapons/starter_weapon.tres"

var _failed: bool = false


func _initialize() -> void:
	var player_definition: CharacterDefinition = load(PLAYER_DEFINITION_PATH) as CharacterDefinition
	var starter_weapon: WeaponDefinition = load(STARTER_WEAPON_PATH) as WeaponDefinition
	_expect(player_definition != null, "无法加载默认角色 Resource。")
	_expect(starter_weapon != null, "无法加载默认武器 Resource。")
	if player_definition == null or starter_weapon == null:
		quit(1)
		return

	_expect(player_definition.starting_weapons.size() == 1, "默认角色起始武器数量不是 1。")
	_expect(is_equal_approx(player_definition.base_attack_range, 1000.0), "默认角色基础攻击范围不正确。")
	if player_definition.starting_weapons.size() == 1:
		_expect(player_definition.starting_weapons[0] == starter_weapon, "默认角色未引用统一的默认武器 Resource。")
	_expect(starter_weapon.id == &"starter_weapon", "默认武器 ID 不正确。")
	_expect(is_equal_approx(starter_weapon.cooldown_seconds, 1.0), "默认武器冷却不是约 1 秒。")
	_expect(starter_weapon.projectile_count == 1, "默认武器弹数不正确。")
	_expect(is_equal_approx(starter_weapon.target_range, 900.0), "默认武器射程不正确。")
	_expect(starter_weapon.projectile_definition is ProjectileDefinition, "默认武器未引用强类型子弹 Resource。")

	if not _failed:
		print("Weapon definition smoke test passed: typed starter configuration is valid.")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
