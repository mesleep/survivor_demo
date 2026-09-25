## 冻结效果的共享只读配置（T19）。
##
## 输入：效果 ID 与冻结时长。
## 输出：供 StatusEffectComponent 在冻结期间把移速倍率压到 0。
## 扩展点：Boss 等控制免疫目标由 Actor 端拒绝；重复施加刷新而非叠层。
class_name FreezeEffect
extends Resource

@export var id: StringName
@export_range(0.05, 30.0, 0.05) var duration_seconds: float = 0.8
