## 单局武器修正数据。
##
## 输入：冷却、弹数、伤害、射程及概率型发射效果。
## 输出：由 WeaponController 合并到独立运行时状态的瞬时数据。
## 扩展点：既可代码构造，也可作为 UpgradeDefinition 引用的共享 Resource（如威能质变捆绑修正）。
class_name WeaponRuntimeModifier
extends Resource

@export var cooldown_multiplier: float = 1.0
@export var projectile_count_bonus: int = 0
@export var damage_multiplier: float = 1.0
@export var bonus_projectile_chance: float = 0.0
@export var projectile_lifesteal_ratio: float = 0.0
@export var repeat_shot_chance: float = 0.0
@export var pierce_bonus: int = 0
@export var speed_multiplier: float = 1.0
@export var size_multiplier: float = 1.0
@export var critical_chance: float = 0.0
## 同一次攻击周期内的额外射击轮数（与“弹数+1”“穿透+1”独立）。
@export var volley_count_bonus: int = 0
## 爆炸范围倍率与溅射伤害倍率（T16 爆炸分支专属升级使用）。
@export var explosion_radius_multiplier: float = 1.0
@export var explosion_damage_multiplier: float = 1.0
## 地面区域持续时间倍率（T17 火焰分支专属升级使用）。
@export var ground_area_duration_multiplier: float = 1.0
## 单武器索敌射程倍率（T18 威能分支使用，区别于角色级全武器射程）。
@export var range_multiplier: float = 1.0
## 冻结持续时间倍率（T19 寒冰分支专属升级使用）。
@export var freeze_duration_multiplier: float = 1.0
## 分裂弹体数量加成（T19 寒冰分支专属升级使用）。
@export var split_count_bonus: int = 0


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
