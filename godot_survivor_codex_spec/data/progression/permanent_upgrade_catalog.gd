## 永久强化目录（T30）。
##
## 输入：永久强化定义数组。
## 输出：按 ID 查询；目录只描述全部项目，不保存购买等级。
class_name PermanentUpgradeCatalog
extends Resource

@export var upgrades: Array[PermanentUpgradeDefinition] = []


func get_upgrade(upgrade_id: StringName) -> PermanentUpgradeDefinition:
	for definition: PermanentUpgradeDefinition in upgrades:
		if definition != null and definition.id == upgrade_id:
			return definition
	return null


func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: PermanentUpgradeDefinition in upgrades:
		if definition != null and definition.id != StringName():
			ids.append(definition.id)
	return ids
