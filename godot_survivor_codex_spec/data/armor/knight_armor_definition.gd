## 骑士盔甲的运行时数值档案（T22）。
##
## 输入：固定减伤（叠加进统一防御管线）与完全免伤概率。
## 输出：供 PlayerActor 写入防御与免疫运行时属性；概率会被 CombatRules 上限钳制。
## 扩展点：减伤方式（固定/比例）与上限可继续加字段，不写死在脚本。
class_name KnightArmorDefinition
extends Resource

## 固定减伤，与基础盔甲防御一起进入 max(原始−防御, 原始×最低比例) 管线。
@export_range(0.0, 10000.0, 0.5) var bonus_defense: float = 6.0
## 完全免伤概率（免疫），实际值受 CombatRules.max_immune_chance 钳制。
@export_range(0.0, 1.0, 0.01) var immune_chance: float = 0.1
