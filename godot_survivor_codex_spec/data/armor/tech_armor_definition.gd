## 科技单件的共享只读配置（T24）。
##
## 输入：稳定 ID、每秒经验与宝石经验倍率。
## 输出：供 PlayerActor 汇总科技经验与宝石倍率；套装判定留待 T25。
## 扩展点：专属升级数值可继续加字段，不写死在脚本。
class_name TechArmorDefinition
extends Resource

@export var id: StringName
@export_range(0.0, 100.0, 0.1) var experience_per_second: float = 2.0
@export_range(1.0, 10.0, 0.05) var gem_experience_multiplier: float = 1.2
