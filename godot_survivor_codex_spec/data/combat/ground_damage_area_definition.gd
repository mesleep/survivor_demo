## 地面持续伤害区域的共享只读配置（T17 火坑）。
##
## 输入：半径、持续时间、tick 间隔、每跳伤害、物理掩码与表现参数。
## 输出：供 GroundDamageArea 按固定间隔对范围内敌人结算带 dot 标签的伤害。
## 扩展点：毒池、冰面等区域能力可复用该资源结构。
class_name GroundDamageAreaDefinition
extends Resource

@export_group("基础信息")
@export var id: StringName
@export_range(0.0, 2000.0, 1.0) var radius: float = 70.0
@export_range(0.05, 60.0, 0.1) var duration_seconds: float = 3.0
@export_range(0.05, 10.0, 0.05) var tick_interval_seconds: float = 0.5
@export_group("伤害")
## 每跳基础伤害；实际值还会乘以生成时的伤害倍率。
@export_range(0.0, 100000.0, 0.1) var damage_per_tick: float = 2.0
## 查询 Hurtbox 所在的物理层；默认 4 为敌人受击层。
@export_flags_2d_physics var collision_mask: int = 4
@export_range(1, 256, 1) var max_targets: int = 64
@export_group("表现")
## 特效；为空时由 GroundDamageArea 绘制占位地面圆环（E02 素材待生成）。
@export var visual_frames: SpriteFrames
@export_range(0.01, 10.0, 0.01) var visual_scale: float = 1.0
@export var visual_color: Color = Color(1.0, 0.42, 0.12, 0.35)
