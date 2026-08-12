## 子弹的共享只读配置。
##
## 输入：子弹场景、伤害、速度、寿命、穿透、命中半径和击退强度。
## 输出：供 ProjectileBase 初始化独立运行状态的数据。
## 扩展点：不同子弹优先通过新 Resource 和场景组合，不复制基础移动与命中逻辑。
class_name ProjectileDefinition
extends Resource

@export var id: StringName
@export var scene: PackedScene
@export_range(0.0, 1000000.0, 0.1) var damage: float = 10.0
@export_range(0.0, 10000.0, 1.0) var speed: float = 600.0
@export_range(0.02, 60.0, 0.01) var lifetime_seconds: float = 2.0
@export_range(0, 1000, 1) var pierce_count: int = 0
@export_range(1.0, 1000.0, 0.5) var hit_radius: float = 8.0
@export_range(0.0, 100000.0, 0.1) var knockback_strength: float = 0.0
