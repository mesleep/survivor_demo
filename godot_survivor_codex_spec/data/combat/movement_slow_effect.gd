## 移动减速效果的共享只读配置（T19）。
##
## 输入：效果 ID、减速比例与持续时间。
## 输出：供 StatusEffectComponent 汇总敌人的运行时移速倍率。
## 扩展点：冻结可视为减速比例 1.0 的同类控制，重复施加刷新而非叠层。
class_name MovementSlowEffect
extends Resource

@export_group("基础信息")
@export var id: StringName
## 减速比例：0 不减速，0.4 表示移速变为 60%。
@export_range(0.0, 0.95, 0.01) var slow_ratio: float = 0.4
@export_range(0.1, 30.0, 0.1) var duration_seconds: float = 1.5
