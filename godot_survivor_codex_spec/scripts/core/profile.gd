## 跨局玩家档案数据对象（T27）。
##
## 输入：金币、已解锁 ID、永久升级等级与刷新次数加成。
## 输出：只包含标量与稳定 ID 的可序列化快照，不含 Node/Resource/场景路径。
## 扩展点：新字段在此增加，并在 from_dict 里给出默认值与版本迁移。
class_name Profile
extends RefCounted

const CURRENT_VERSION := 1

var version: int = CURRENT_VERSION
var coins: int = 0
var unlocked_character_ids: Array[StringName] = []
var unlocked_weapon_ids: Array[StringName] = []
## 升级卡刷新次数加成（T28 使用）。
var refresh_bonus: int = 0
## 永久强化等级：ID → 等级（T30 使用）。
var permanent_upgrades: Dictionary[StringName, int] = {}


func to_dict() -> Dictionary:
	var character_ids: Array[String] = []
	for id: StringName in unlocked_character_ids:
		character_ids.append(String(id))
	var weapon_ids: Array[String] = []
	for id: StringName in unlocked_weapon_ids:
		weapon_ids.append(String(id))
	var upgrades: Dictionary = {}
	for upgrade_id: StringName in permanent_upgrades.keys():
		upgrades[String(upgrade_id)] = int(permanent_upgrades[upgrade_id])
	return {
		"version": version,
		"coins": coins,
		"unlocked_character_ids": character_ids,
		"unlocked_weapon_ids": weapon_ids,
		"refresh_bonus": refresh_bonus,
		"permanent_upgrades": upgrades,
	}


## 从任意字典安全还原；返回 null 表示版本高于当前支持或数据不可用。
##
## 已知 ID 列表非空时会丢弃其中的未知项（T27 测试“未知 ID”）。
static func from_dict(
		data: Variant,
		known_character_ids: Array[StringName] = [],
		known_weapon_ids: Array[StringName] = []
) -> Profile:
	if not (data is Dictionary):
		return null
	var source: Dictionary = data
	var profile := Profile.new()
	if source.has("version"):
		profile.version = int(source["version"])
	else:
		profile.version = CURRENT_VERSION
	if profile.version > CURRENT_VERSION:
		return null
	# 版本迁移：0 或更早视为当前结构，未来在此按版本逐步补齐字段。
	if profile.version < CURRENT_VERSION:
		profile.version = CURRENT_VERSION
	profile.coins = maxi(_as_int(source.get("coins", 0)), 0)
	profile.unlocked_character_ids = _as_id_array(
		source.get("unlocked_character_ids", []), known_character_ids
	)
	profile.unlocked_weapon_ids = _as_id_array(
		source.get("unlocked_weapon_ids", []), known_weapon_ids
	)
	profile.refresh_bonus = maxi(_as_int(source.get("refresh_bonus", 0)), 0)
	profile.permanent_upgrades = _as_int_dict(source.get("permanent_upgrades", {}))
	return profile


func copy() -> Profile:
	return Profile.from_dict(to_dict())


func add_coins(amount: int) -> void:
	if amount > 0:
		coins += amount


func is_character_unlocked(character_id: StringName) -> bool:
	return unlocked_character_ids.has(character_id)


func is_weapon_unlocked(weapon_id: StringName) -> bool:
	return unlocked_weapon_ids.has(weapon_id)


static func _as_int(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return roundi(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return 0


static func _as_id_array(value: Variant, known: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		if not (item is String) and not (item is StringName):
			continue
		var id := StringName(item)
		if id == StringName():
			continue
		if not known.is_empty() and not known.has(id):
			continue
		if not result.has(id):
			result.append(id)
	return result


static func _as_int_dict(value: Variant) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if not (value is Dictionary):
		return result
	for key: Variant in (value as Dictionary).keys():
		if not (key is String) and not (key is StringName):
			continue
		result[StringName(key)] = maxi(_as_int((value as Dictionary)[key]), 0)
	return result
