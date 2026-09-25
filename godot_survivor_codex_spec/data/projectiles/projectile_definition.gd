## 子弹的共享只读配置。
##
## 输入：子弹场景、伤害、速度、寿命、穿透、命中半径和击退强度。
## 输出：供 ProjectileBase 初始化独立运行状态的数据。
## 扩展点：不同子弹优先通过新 Resource 和场景组合，不复制基础移动与命中逻辑。
class_name ProjectileDefinition
extends Resource

enum MotionType { STRAIGHT, RETURNING, ORBIT }

@export var motion_type: MotionType = MotionType.STRAIGHT
@export var visual_frames: SpriteFrames
@export var visual_scale: float = 0.1
## 弹体着色；敌人弹体可借此区分敌我（不修改共享素材）。
@export var visual_modulate: Color = Color.WHITE
@export var orbit_radius: float = 100.0
@export var orbit_speed: float = 3.0

@export var id: StringName
@export var scene: PackedScene
@export_range(0.0, 1000000.0, 0.1) var damage: float = 10.0
@export_range(0.0, 10000.0, 1.0) var speed: float = 600.0
@export_range(0.02, 60.0, 0.01) var lifetime_seconds: float = 2.0
@export_range(0, 1000, 1) var pierce_count: int = 0
@export_range(1.0, 1000.0, 0.5) var hit_radius: float = 8.0
@export_range(0.0, 100000.0, 0.1) var knockback_strength: float = 0.0
## 命中检测的物理层；玩家武器默认 4（敌人受击层），敌人弹体为 2（玩家受击层）。
@export_flags_2d_physics var collision_mask: int = 4
## 命中后的一次性范围爆炸配置；为空表示不爆炸（T16）。
@export var explosion: ExplosionDefinition
## 命中后施加的持续伤害效果；为空表示无 DoT（T17）。
@export var damage_over_time: DamageOverTimeEffect
## 命中后在地面留下的持续伤害区域；为空表示不留火坑（T17）。
@export var ground_area: GroundDamageAreaDefinition
## 命中后施加的移动减速；为空表示无减速（T19）。
@export var on_hit_slow: MovementSlowEffect
## 命中后施加的冻结；为空表示不冻结（T19）。
@export var on_hit_freeze: FreezeEffect
## 命中后分裂出的小弹体；为空表示不分裂（T19）。小弹体自身不应再配置分裂，避免递归。
@export var split_projectile: ProjectileDefinition
@export_range(0, 32, 1) var split_count: int = 0
@export_range(0.0, 360.0, 1.0) var split_spread_degrees: float = 90.0
@export_range(0.0, 10.0, 0.05) var split_damage_multiplier: float = 1.0
@export_range(0.1, 10.0, 0.05) var split_speed_multiplier: float = 1.0
