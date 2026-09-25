## 一次性范围爆炸的共享只读配置（T16）。
##
## 输入：半径、溅射伤害倍率、是否命中直击目标、物理掩码与表现参数。
## 输出：供 ProjectileBase 在命中时执行一次受控范围查询，并交给 ExplosionEffect 播放。
## 扩展点：后续“留下火坑”“元素转化”等能力继续加字段，不在脚本里写死数值。
class_name ExplosionDefinition
extends Resource

## 溅射半径（像素）。
@export_range(0.0, 2000.0, 1.0) var radius: float = 90.0
## 溅射伤害 = 本次直击伤害 × 该倍率。
@export_range(0.0, 20.0, 0.05) var damage_multiplier: float = 0.5
## 是否也命中被直击的敌人；true 时直击目标同时承受直击与溅射。
@export var hits_direct_target: bool = true
## 查询 Hurtbox 所在的物理层；默认 4 为敌人受击层。
@export_flags_2d_physics var collision_mask: int = 4
## 单次爆炸最多结算的目标数，防止极端密度下查询失控。
@export_range(1, 256, 1) var max_targets: int = 64
@export_range(0.0, 100000.0, 0.1) var knockback_strength: float = 0.0
## 爆炸特效；为空时由 ExplosionEffect 绘制占位圆环（E02 素材待生成）。
@export var visual_frames: SpriteFrames
@export_range(0.01, 10.0, 0.01) var visual_scale: float = 1.0
@export_range(0.05, 5.0, 0.01) var visual_duration_seconds: float = 0.3
@export var visual_color: Color = Color(1.0, 0.62, 0.24, 0.55)
