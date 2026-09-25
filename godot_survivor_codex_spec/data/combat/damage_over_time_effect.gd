## 持续伤害效果的共享只读配置（T17）。
##
## 输入：效果 ID、tick 间隔、持续时间、每跳伤害与是否允许暴击/吸血。
## 输出：供 StatusEffectComponent 在目标 Actor 上按固定间隔结算伤害。
## 扩展点：减速/冻结等状态可共用同类资源模式，不把数值写进脚本。
class_name DamageOverTimeEffect
extends Resource

@export var id: StringName
@export_range(0.05, 10.0, 0.05) var tick_interval_seconds: float = 0.5
@export_range(0.1, 60.0, 0.1) var duration_seconds: float = 2.0
## 每跳基础伤害；实际值还会乘以施加时的伤害倍率。
@export_range(0.0, 100000.0, 0.1) var damage_per_tick: float = 3.0
## 首版 DoT 不暴击、不吸血；标签为 dot，按 D07 不触发反伤。
@export var can_crit: bool = false
@export var allow_lifesteal: bool = false
