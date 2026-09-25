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
## 预留：基础升级与质变卡；T11 起填充，当前只保存引用，不在此脚本套用效果。
@export var base_upgrades: Array[UpgradeDefinition] = []
@export var branch_upgrades: Array[UpgradeDefinition] = []


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
