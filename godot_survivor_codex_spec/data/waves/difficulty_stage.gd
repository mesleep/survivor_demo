## 单局某个时间段的生成与敌人强度配置。
##
## 输入：起始时间、生成池、生成节奏、数量上限和实例倍率。
## 输出：供 DifficultyDirector 只读选择的阶段数据。
class_name DifficultyStage
extends Resource

@export_range(0.0, 3600.0, 1.0) var start_time_seconds: float = 0.0
@export_range(0.05, 60.0, 0.05) var spawn_interval_seconds: float = 1.0
@export_range(1, 100, 1) var batch_size: int = 1
@export_range(1, 10000, 1) var max_alive_enemies: int = 30
@export_range(0.05, 100.0, 0.05) var health_multiplier: float = 1.0
@export_range(0.05, 100.0, 0.05) var move_speed_multiplier: float = 1.0
@export_range(0.0, 100.0, 0.05) var damage_multiplier: float = 1.0
@export var enemy_pool: Array[EnemyDefinition] = []
