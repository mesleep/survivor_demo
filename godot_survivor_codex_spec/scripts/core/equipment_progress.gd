## 单件装备的本局成长状态（运行时对象，不写入任何 `.tres`）。
##
## 输入：装备稳定 ID。
## 输出：基础等级、质变分支 ID 和各分支专属升级层数，以及只读快照 copy()。
## D04 首版规则：基础等级 1→MAX_BASE_LEVEL；基础满级后可选一次互斥质变；
## 质变专属升级 1→MAX_BRANCH_UPGRADE_LEVEL。具体数值效果由升级资源驱动。
class_name EquipmentProgress
extends RefCounted

const MAX_BASE_LEVEL := 5
const MAX_BRANCH_UPGRADE_LEVEL := 3

var equipment_id: StringName = &""
var base_level: int = 1
var branch_id: StringName = &""
var branch_upgrade_levels: Dictionary[StringName, int] = {}
## 质变后的显示名与图标（T33 装备栏用）；未质变时为空。
var branch_display_name: String = ""
var branch_icon: Texture2D


func _init(new_equipment_id: StringName = &"") -> void:
	equipment_id = new_equipment_id


## 返回独立副本；调用方修改快照不影响实际局内状态。
func copy() -> EquipmentProgress:
	var clone := EquipmentProgress.new(equipment_id)
	clone.base_level = base_level
	clone.branch_id = branch_id
	clone.branch_upgrade_levels = branch_upgrade_levels.duplicate()
	clone.branch_display_name = branch_display_name
	clone.branch_icon = branch_icon
	return clone


func is_base_maxed() -> bool:
	return base_level >= MAX_BASE_LEVEL


func can_add_base_level() -> bool:
	return base_level < MAX_BASE_LEVEL


func add_base_level() -> bool:
	if not can_add_base_level():
		return false
	base_level += 1
	return true


func has_branch() -> bool:
	return branch_id != StringName()


## 质变门槛：基础满级且尚未选择任何分支；每件每局仅一次。
func can_choose_branch() -> bool:
	return is_base_maxed() and not has_branch()


func choose_branch(new_branch_id: StringName) -> bool:
	if new_branch_id == StringName() or not can_choose_branch():
		return false
	branch_id = new_branch_id
	return true


func get_branch_upgrade_level(upgrade_id: StringName) -> int:
	return branch_upgrade_levels.get(upgrade_id, 0)


func can_add_branch_upgrade(upgrade_id: StringName) -> bool:
	if not has_branch() or upgrade_id == StringName():
		return false
	return get_branch_upgrade_level(upgrade_id) < MAX_BRANCH_UPGRADE_LEVEL


func add_branch_upgrade(upgrade_id: StringName) -> bool:
	if not can_add_branch_upgrade(upgrade_id):
		return false
	branch_upgrade_levels[upgrade_id] = get_branch_upgrade_level(upgrade_id) + 1
	return true
