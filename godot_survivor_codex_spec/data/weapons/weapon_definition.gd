## 武器的共享只读配置。
##
## 输入：冷却、弹数、扩散、武器自身射程和子弹配置。
## 输出：供 WeaponController 初始化基础运行参数的数据。
## 扩展点：复杂发射策略应独立组合，不按武器 ID 堆叠分支。
class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
## 武器动画由配置指定，控制器只驱动表现，不按武器 ID 分支。
@export var visual_frames: SpriteFrames
@export var projectile_definition: ProjectileDefinition
@export_range(0.02, 60.0, 0.01) var cooldown_seconds: float = 1.0
@export_range(1, 100, 1) var projectile_count: int = 1
@export_range(0.0, 360.0, 0.1) var spread_degrees: float = 0.0
@export_range(1.0, 5000.0, 1.0) var target_range: float = 900.0
