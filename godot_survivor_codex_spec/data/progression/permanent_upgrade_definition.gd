## 永久强化项的共享只读配置（T30 / D11）。
##
## 输入：稳定 ID、显示名、属性、每级增量、等级上限、基础价格与价格成长。
## 输出：供商店交易与开局快照使用；数值全部可配，不写死在脚本。
class_name PermanentUpgradeDefinition
extends Resource

enum Attribute { MOVE_SPEED, DAMAGE, REGENERATION, LIFESTEAL, DEFENSE }

@export_group("基础信息")
@export var id: StringName
@export var display_name: String
@export var attribute: Attribute = Attribute.MOVE_SPEED
@export_group("数值与价格")
## 每级增量：移速/伤害/吸血为比例，每秒恢复为点数/秒，防御为点数。
@export_range(0.0, 100.0, 0.01) var per_level_value: float = 0.05
@export_range(1, 20, 1) var max_level: int = 5
@export_range(0, 1000000, 1) var base_price: int = 30
## 价格成长系数：下一级价格 = round(基础价 × 成长^当前等级)。
@export_range(1.0, 5.0, 0.05) var price_growth: float = 1.5


## 从当前等级升到下一级的价格。
func get_price(current_level: int) -> int:
	return roundi(float(base_price) * pow(price_growth, float(maxi(current_level, 0))))
