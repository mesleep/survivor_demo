## 只读的角色与武器目录。
##
## 输入：角色与武器 Resource 数组。
## 输出：按稳定 ID 查询的定义，以及重复、空引用和缺失场景的校验错误。
## 扩展点：正式解锁筛选在 T29 基于本目录与档案实现；目录本身只描述全部内容，
## 不保存“已解锁”状态，也不被单局配置回写。
class_name ContentCatalog
extends Resource

@export var characters: Array[CharacterDefinition] = []
@export var weapons: Array[WeaponDefinition] = []
@export var armors: Array[ArmorDefinition] = []


func get_character(id: StringName) -> CharacterDefinition:
	for character: CharacterDefinition in characters:
		if character != null and character.id == id:
			return character
	return null


func get_weapon(id: StringName) -> WeaponDefinition:
	for weapon: WeaponDefinition in weapons:
		if weapon != null and weapon.id == id:
			return weapon
	return null


func get_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for character: CharacterDefinition in characters:
		if character != null and character.id != StringName():
			ids.append(character.id)
	return ids


func get_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for weapon: WeaponDefinition in weapons:
		if weapon != null and weapon.id != StringName():
			ids.append(weapon.id)
	return ids


func get_armor(id: StringName) -> ArmorDefinition:
	for armor: ArmorDefinition in armors:
		if armor != null and armor.id == id:
			return armor
	return null


## 返回目录自身的错误列表；空数组表示有效。
##
## 只读取定义，不修改任何 Resource。重复 ID 会让按 ID 查询产生歧义，
## 因此必须在进入开局配置前暴露。
func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen_characters: Dictionary[StringName, bool] = {}
	for character: CharacterDefinition in characters:
		if character == null:
			errors.append("角色目录包含空引用。")
			continue
		if character.id == StringName():
			errors.append("角色缺少 ID：%s。" % character.display_name)
		elif seen_characters.has(character.id):
			errors.append("角色 ID 重复：%s。" % character.id)
		else:
			seen_characters[character.id] = true
		if character.scene == null:
			errors.append("角色 %s 缺少场景。" % character.id)

	var seen_weapons: Dictionary[StringName, bool] = {}
	for weapon: WeaponDefinition in weapons:
		if weapon == null:
			errors.append("武器目录包含空引用。")
			continue
		if weapon.id == StringName():
			errors.append("武器缺少 ID：%s。" % weapon.display_name)
		elif seen_weapons.has(weapon.id):
			errors.append("武器 ID 重复：%s。" % weapon.id)
		else:
			seen_weapons[weapon.id] = true

	var seen_armors: Dictionary[StringName, bool] = {}
	for armor: ArmorDefinition in armors:
		if armor == null:
			errors.append("防具目录包含空引用。")
			continue
		if armor.id == StringName():
			errors.append("防具缺少 ID：%s。" % armor.display_name)
		elif seen_armors.has(armor.id):
			errors.append("防具 ID 重复：%s。" % armor.id)
		else:
			seen_armors[armor.id] = true

	return errors
