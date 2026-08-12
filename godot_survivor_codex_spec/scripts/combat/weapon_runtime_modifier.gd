## 单局武器修正数据。
##
## 输入：冷却倍率、额外弹数和最终伤害倍率。
## 输出：由 WeaponController 合并到独立运行时状态的瞬时数据。
## 扩展点：阶段三升级可构造该对象，不需要修改共享 WeaponDefinition。
class_name WeaponRuntimeModifier
extends RefCounted

var cooldown_multiplier: float = 1.0
var projectile_count_bonus: int = 0
var damage_multiplier: float = 1.0


func _init(
		new_cooldown_multiplier: float = 1.0,
		new_projectile_count_bonus: int = 0,
		new_damage_multiplier: float = 1.0
) -> void:
	cooldown_multiplier = new_cooldown_multiplier
	projectile_count_bonus = new_projectile_count_bonus
	damage_multiplier = new_damage_multiplier
