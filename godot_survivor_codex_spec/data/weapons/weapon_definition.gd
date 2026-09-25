## 武器的共享只读配置。
##
## 输入：冷却、弹数、扩散、武器自身射程和子弹配置。
## 输出：供 WeaponController 初始化基础运行参数的数据。
## 扩展点：复杂发射策略应独立组合，不按武器 ID 堆叠分支。
class_name WeaponDefinition
extends Resource

## 索敌方式：最近目标；或每一发从范围内候选中随机取目标（T25 科技导弹）。
enum TargetMode { NEAREST, RANDOM }
## 攻击形态：发射弹体；或在目标方向做一次近战扇形斩击（T32）。
enum AttackMode { PROJECTILE, MELEE_FAN }

@export var id: StringName
@export var display_name: String
## 装备栏图标；为空时回退到武器动画首帧（T33）。
@export var icon: Texture2D
## 解锁所需金币；0 表示默认解锁（T29）。
@export_range(0, 1000000, 1) var unlock_cost: int = 0
## 武器标签（如 ranged）；角色被动按标签生效（T31）。
@export var tags: Array[StringName] = []
## 武器动画由配置指定，控制器只驱动表现，不按武器 ID 分支。
@export var visual_frames: SpriteFrames
## 手持武器显示缩放（可配置，避免在控制器里写死）。
@export_range(0.02, 2.0, 0.01) var visual_scale: float = 0.22
@export var projectile_definition: ProjectileDefinition
@export_range(0.02, 60.0, 0.01) var cooldown_seconds: float = 1.0
@export_range(1, 100, 1) var projectile_count: int = 1
@export_range(0.0, 360.0, 0.1) var spread_degrees: float = 0.0
@export_range(1.0, 5000.0, 1.0) var target_range: float = 900.0
## 多重射击时，相邻两轮之间的间隔（秒），可在 Resource 调整。
@export_range(0.02, 5.0, 0.01) var volley_interval_seconds: float = 0.18
## 蓄力时长（秒）；0 表示不蓄力、冷却好即发射。
@export_range(0.0, 10.0, 0.05) var charge_seconds: float = 0.0
## 蓄力完成后的伤害倍率（1 = 不额外加成）。
@export_range(1.0, 20.0, 0.1) var charge_damage_multiplier: float = 1.0
## 索敌方式；RANDOM 时每一发各自从 TargetingService 候选中随机取目标。
@export var target_mode: TargetMode = TargetMode.NEAREST
## 交替攻击弹体（T25 激光）：每次开火在主弹体与该弹体之间交替；为空则只发主弹体。
@export var alternate_projectile_definition: ProjectileDefinition
@export_range(1, 100, 1) var alternate_projectile_count: int = 1
## 攻击形态；MELEE_FAN 时不发射弹体，改为扇形范围斩击。
@export var attack_mode: AttackMode = AttackMode.PROJECTILE
## 近战扇形参数（MELEE_FAN 使用）。
@export_range(0.0, 100000.0, 0.5) var melee_damage: float = 12.0
@export_range(1.0, 1000.0, 1.0) var melee_radius: float = 120.0
@export_range(10.0, 360.0, 1.0) var melee_arc_degrees: float = 110.0
@export_range(0.0, 100000.0, 0.1) var melee_knockback_strength: float = 100.0
@export_flags_2d_physics var melee_hit_mask: int = 4
## 近战斩击表现序列帧（C05）；为空时用代码绘制占位弧光。
@export var melee_visual_frames: SpriteFrames
