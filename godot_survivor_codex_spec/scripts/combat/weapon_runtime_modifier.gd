## 单局武器修正数据。
##
## 输入：冷却、弹数、伤害及概率型发射效果。
## 输出：由 WeaponController 合并到独立运行时状态的瞬时数据。
## 扩展点：阶段三升级可构造该对象，不需要修改共享 WeaponDefinition。
class_name WeaponRuntimeModifier
extends RefCounted

var cooldown_multiplier: float = 1.0
var projectile_count_bonus: int = 0
var damage_multiplier: float = 1.0
var bonus_projectile_chance: float = 0.0
var projectile_lifesteal_ratio: float = 0.0
var repeat_shot_chance: float = 0.0
var pierce_bonus: int = 0
var speed_multiplier: float = 1.0
var size_multiplier: float = 1.0
var critical_chance: float = 0.0
## 同一次攻击周期内的额外射击轮数（与“弹数+1”“穿透+1”独立）。
var volley_count_bonus: int = 0


func _init(
		new_cooldown_multiplier: float = 1.0,
		new_projectile_count_bonus: int = 0,
		new_damage_multiplier: float = 1.0,
		new_bonus_projectile_chance: float = 0.0,
		new_projectile_lifesteal_ratio: float = 0.0,
		new_repeat_shot_chance: float = 0.0
) -> void:
	cooldown_multiplier = new_cooldown_multiplier
	projectile_count_bonus = new_projectile_count_bonus
	damage_multiplier = new_damage_multiplier
	bonus_projectile_chance = new_bonus_projectile_chance
	projectile_lifesteal_ratio = new_projectile_lifesteal_ratio
	repeat_shot_chance = new_repeat_shot_chance
