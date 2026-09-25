## 防具（盔甲/头盔/手套）的共享只读配置。
##
## 输入：稳定 ID、显示名、图标与类别；基础升级/分支引用为后续 T11 预留。
## 输出：供装备清单、UI 与后续防具系统只读使用的数据。
## 边界：本任务只描述“能被持有”，防御数值与减伤结算留到 T11/T10。
class_name ArmorDefinition
extends Resource

enum ArmorCategory { ARMOR, HELMET, GLOVES }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var category: ArmorCategory = ArmorCategory.ARMOR
## 穿戴时立即获得的固定防御。
@export_range(0.0, 1000.0, 0.5) var defense_base: float = 0.0
## 每提升 1 级基础等级额外增加的防御。
@export_range(0.0, 1000.0, 0.5) var defense_per_level: float = 0.0
## 1 级时的移动速度惩罚比例（0.08 = -8%）。
@export_range(0.0, 1.0, 0.01) var move_penalty_ratio: float = 0.0
## 每提升 1 级基础等级减轻的移动惩罚比例，最低减到 0。
@export_range(0.0, 1.0, 0.01) var move_penalty_reduction_per_level: float = 0.0
## 预留：基础升级与质变卡；T11 起填充，当前只保存引用，不在此脚本套用效果。
@export var base_upgrades: Array[UpgradeDefinition] = []
@export var branch_upgrades: Array[UpgradeDefinition] = []


## 按基础等级计算该防具提供的防御（等级从 1 开始）。
func get_defense_for_level(base_level: int) -> float:
	return maxf(defense_base + defense_per_level * float(maxi(base_level, 1) - 1), 0.0)


## 按基础等级计算该防具的移动惩罚比例，升级会逐步减轻且不低于 0。
func get_move_penalty_for_level(base_level: int) -> float:
	var reduction: float = move_penalty_reduction_per_level * float(maxi(base_level, 1) - 1)
	return clampf(move_penalty_ratio - reduction, 0.0, 1.0)


func get_category_name() -> String:
	match category:
		ArmorCategory.ARMOR:
			return "盔甲"
		ArmorCategory.HELMET:
			return "头盔"
		ArmorCategory.GLOVES:
			return "手套"
		_:
			return "防具"
