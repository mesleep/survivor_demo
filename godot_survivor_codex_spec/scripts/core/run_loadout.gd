## 单局开局配置快照（运行时对象，不是 Resource）。
##
## 输入：角色 ID、候选武器 ID、起始武器 ID，通常由主菜单或默认目录生成。
## 输出：经目录解析得到的角色与武器定义，以及可读的校验错误。
## 生命周期：构造时复制传入数组，之后菜单或外部数组改动都不影响本局；
## 只保存稳定 ID 与副本，不修改任何共享 `.tres`，正式解锁筛选留给 T29。
class_name RunLoadout
extends RefCounted

## 候选池上限；D01 已确认“最多 10 个唯一 ID，库存不足可少选”。
const MAX_CANDIDATE_WEAPONS := 10

var character_id: StringName = &""
var candidate_weapon_ids: Array[StringName] = []
var starting_weapon_ids: Array[StringName] = []


func _init(
		new_character_id: StringName = &"",
		new_candidate_weapon_ids: Array[StringName] = [],
		new_starting_weapon_ids: Array[StringName] = []
) -> void:
	character_id = new_character_id
	candidate_weapon_ids = new_candidate_weapon_ids.duplicate()
	starting_weapon_ids = new_starting_weapon_ids.duplicate()


## 由目录中的可玩内容生成默认快照，供旧直启入口使用。
##
## 角色为空时取目录首个角色；候选池最多 10 个，并保证所有起始武器都在池内（D01）。
static func default_for(catalog: ContentCatalog, character_id: StringName = &"") -> RunLoadout:
	var loadout := RunLoadout.new()
	if catalog == null:
		return loadout

	var character: CharacterDefinition = null
	if character_id != StringName():
		character = catalog.get_character(character_id)
	if character == null and not catalog.characters.is_empty():
		character = catalog.characters[0]
	if character == null:
		return loadout

	loadout.character_id = character.id
	var starting_ids: Array[StringName] = []
	for weapon: WeaponDefinition in character.starting_weapons:
		if weapon != null and not starting_ids.has(weapon.id):
			starting_ids.append(weapon.id)
	loadout.starting_weapon_ids = starting_ids.duplicate()

	var candidates: Array[StringName] = starting_ids.duplicate()
	for weapon: WeaponDefinition in catalog.weapons:
		if weapon == null:
			continue
		if candidates.size() >= MAX_CANDIDATE_WEAPONS:
			break
		if not candidates.has(weapon.id):
			candidates.append(weapon.id)
	loadout.candidate_weapon_ids = candidates
	return loadout


## 返回副本；调用方修改副本不会影响本对象，反之亦然。
func copy() -> RunLoadout:
	return RunLoadout.new(character_id, candidate_weapon_ids, starting_weapon_ids)


## 按目录校验本快照；返回中文错误列表，空数组表示可用。
##
## 校验不修改任何状态，可被菜单、GameSession 和测试重复调用。
func validate(catalog: ContentCatalog) -> Array[String]:
	var errors: Array[String] = []
	if catalog == null:
		errors.append("缺少内容目录，无法校验单局配置。")
		return errors

	if character_id == StringName():
		errors.append("单局配置缺少角色 ID。")
	elif catalog.get_character(character_id) == null:
		errors.append("单局配置引用了未知角色：%s。" % character_id)

	if candidate_weapon_ids.size() > MAX_CANDIDATE_WEAPONS:
		errors.append("候选武器最多 %d 个，当前 %d 个。" % [
			MAX_CANDIDATE_WEAPONS, candidate_weapon_ids.size()
		])

	var seen_candidates: Dictionary[StringName, bool] = {}
	for weapon_id: StringName in candidate_weapon_ids:
		if weapon_id == StringName():
			errors.append("候选武器包含空 ID。")
			continue
		if seen_candidates.has(weapon_id):
			errors.append("候选武器 ID 重复：%s。" % weapon_id)
		else:
			seen_candidates[weapon_id] = true
		if catalog.get_weapon(weapon_id) == null:
			errors.append("候选武器不在目录中：%s。" % weapon_id)

	if starting_weapon_ids.is_empty():
		errors.append("单局配置至少需要一把起始武器。")
	var seen_starting: Dictionary[StringName, bool] = {}
	for weapon_id: StringName in starting_weapon_ids:
		if weapon_id == StringName():
			errors.append("起始武器包含空 ID。")
			continue
		if seen_starting.has(weapon_id):
			errors.append("起始武器 ID 重复：%s。" % weapon_id)
		else:
			seen_starting[weapon_id] = true
		if catalog.get_weapon(weapon_id) == null:
			errors.append("起始武器不在目录中：%s。" % weapon_id)
		elif not seen_candidates.has(weapon_id):
			errors.append("起始武器不在候选池中：%s。" % weapon_id)

	return errors


func is_valid(catalog: ContentCatalog) -> bool:
	return validate(catalog).is_empty()


func resolve_character(catalog: ContentCatalog) -> CharacterDefinition:
	if catalog == null:
		return null
	return catalog.get_character(character_id)


## 解析起始武器；按快照顺序返回，跳过目录中不存在的 ID。
func resolve_starting_weapons(catalog: ContentCatalog) -> Array[WeaponDefinition]:
	var resolved: Array[WeaponDefinition] = []
	if catalog == null:
		return resolved
	for weapon_id: StringName in starting_weapon_ids:
		var weapon: WeaponDefinition = catalog.get_weapon(weapon_id)
		if weapon != null:
			resolved.append(weapon)
	return resolved


## 解析候选武器；按快照顺序返回，跳过目录中不存在的 ID。
func resolve_candidate_weapons(catalog: ContentCatalog) -> Array[WeaponDefinition]:
	var resolved: Array[WeaponDefinition] = []
	if catalog == null:
		return resolved
	for weapon_id: StringName in candidate_weapon_ids:
		var weapon: WeaponDefinition = catalog.get_weapon(weapon_id)
		if weapon != null:
			resolved.append(weapon)
	return resolved
