## 伤害结算的可调规则（Resource）。
##
## 输入：无；所有数值可在 Inspector 修改，或由 GameSession 注入到 Actor。
## 输出：供 ActorBase 计算防御下限、闪避/免疫上限与反伤上限。
## 扩展点：新公式参数继续加在这里，避免在多个脚本里散落魔法数字。
class_name CombatRules
extends Resource

## 防御后的最低伤害比例：实际伤害 = max(原始 - 防御, 原始 × 该比例)。
@export_range(0.0, 1.0, 0.01) var minimum_damage_ratio: float = 0.1
@export_range(0.0, 1.0, 0.01) var max_dodge_chance: float = 0.75
@export_range(0.0, 1.0, 0.01) var max_immune_chance: float = 0.5
@export_range(0.0, 2.0, 0.05) var max_damage_reflect_ratio: float = 1.0
