## 武器/角色解锁交易入口（T29）。
##
## 输入：档案、档案存储与内容目录。
## 输出：一次交易的结果；成功时写档，写档失败则回滚内存档案。
## 只按稳定 ID 操作，不改目录内容，也不修改进行中的单局。
class_name UnlockService
extends RefCounted

enum Result {
	SUCCESS,
	INVALID_ID,
	ALREADY_UNLOCKED,
	INSUFFICIENT_COINS,
	SAVE_FAILED,
	MAX_LEVEL,
}

var profile: Profile
var store: ProfileStore


func _init(new_profile: Profile, new_store: ProfileStore) -> void:
	profile = new_profile
	store = new_store


func is_character_unlocked(character_id: StringName) -> bool:
	return profile != null and profile.is_character_unlocked(character_id)


func is_weapon_unlocked(weapon_id: StringName) -> bool:
	return profile != null and profile.is_weapon_unlocked(weapon_id)


func get_character_cost(catalog: ContentCatalog, character_id: StringName) -> int:
	var definition: CharacterDefinition = catalog.get_character(character_id) if catalog != null else null
	return definition.unlock_cost if definition != null else 0


func get_weapon_cost(catalog: ContentCatalog, weapon_id: StringName) -> int:
	var definition: WeaponDefinition = catalog.get_weapon(weapon_id) if catalog != null else null
	return definition.unlock_cost if definition != null else 0


## 购买角色：校验 ID、重复、余额，成功才写档；写档失败回滚。
func purchase_character(catalog: ContentCatalog, character_id: StringName) -> Result:
	var definition: CharacterDefinition = catalog.get_character(character_id) if catalog != null else null
	if definition == null:
		return Result.INVALID_ID
	if is_character_unlocked(character_id):
		return Result.ALREADY_UNLOCKED
	if profile.coins < definition.unlock_cost:
		return Result.INSUFFICIENT_COINS
	var snapshot: Profile = profile.copy()
	if not profile.try_unlock_character(character_id, definition.unlock_cost):
		return Result.INSUFFICIENT_COINS
	return _commit(snapshot)


## 购买武器：校验 ID、重复、余额，成功才写档；写档失败回滚。
func purchase_weapon(catalog: ContentCatalog, weapon_id: StringName) -> Result:
	var definition: WeaponDefinition = catalog.get_weapon(weapon_id) if catalog != null else null
	if definition == null:
		return Result.INVALID_ID
	if is_weapon_unlocked(weapon_id):
		return Result.ALREADY_UNLOCKED
	if profile.coins < definition.unlock_cost:
		return Result.INSUFFICIENT_COINS
	var snapshot: Profile = profile.copy()
	if not profile.try_unlock_weapon(weapon_id, definition.unlock_cost):
		return Result.INSUFFICIENT_COINS
	return _commit(snapshot)


func get_permanent_level(upgrade_id: StringName) -> int:
	return profile.get_permanent_level(upgrade_id) if profile != null else 0


## 购买一级永久强化（T30）：校验上限与余额，成功写档，失败回滚。
func purchase_permanent_upgrade(
		catalog: PermanentUpgradeCatalog, upgrade_id: StringName
) -> Result:
	var definition: PermanentUpgradeDefinition = (
		catalog.get_upgrade(upgrade_id) if catalog != null else null
	)
	if definition == null:
		return Result.INVALID_ID
	var current: int = profile.get_permanent_level(upgrade_id)
	if current >= definition.max_level:
		return Result.MAX_LEVEL
	var price: int = definition.get_price(current)
	if profile.coins < price:
		return Result.INSUFFICIENT_COINS
	var snapshot: Profile = profile.copy()
	if not profile.try_upgrade_permanent(upgrade_id, price, definition.max_level):
		return Result.INSUFFICIENT_COINS
	return _commit(snapshot)


## 写档失败时把内存档案恢复为交易前快照，保证与磁盘一致。
func _commit(snapshot: Profile) -> Result:
	if store == null:
		return Result.SUCCESS
	if store.save_profile(profile):
		return Result.SUCCESS
	_restore(snapshot)
	return Result.SAVE_FAILED


func _restore(snapshot: Profile) -> void:
	if profile == null or snapshot == null:
		return
	profile.version = snapshot.version
	profile.coins = snapshot.coins
	profile.unlocked_character_ids = snapshot.unlocked_character_ids.duplicate()
	profile.unlocked_weapon_ids = snapshot.unlocked_weapon_ids.duplicate()
	profile.refresh_bonus = snapshot.refresh_bonus
	profile.permanent_upgrades = snapshot.permanent_upgrades.duplicate()
