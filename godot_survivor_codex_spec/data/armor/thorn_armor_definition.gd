## 反伤刺甲的运行时数值档案（T21）。
##
## 输入：刺圈半径、周期、每跳伤害、物理掩码与受击返还比例。
## 输出：供 ThornAuraComponent 和玩家反伤属性使用；数值全部可配。
## 扩展点：范围/返还升级通过运行时倍率修改，不回写本资源。
class_name ThornArmorDefinition
extends Resource

@export_range(0.0, 2000.0, 1.0) var aura_radius: float = 90.0
@export_range(0.1, 10.0, 0.05) var aura_tick_interval_seconds: float = 0.5
@export_range(0.0, 100000.0, 0.1) var aura_damage_per_tick: float = 4.0
## 查询 Hurtbox 所在的物理层；默认 4 为敌人受击层。
@export_flags_2d_physics var collision_mask: int = 4
@export_range(1, 256, 1) var max_targets: int = 64
## 受击后按“实际伤害”返还给攻击者的比例。
@export_range(0.0, 2.0, 0.05) var hit_reflect_ratio: float = 0.3
## 占位刺圈颜色（E04 正式素材待生成）。
@export var visual_color: Color = Color(0.85, 0.25, 0.35, 0.22)
