## 第一阶段敌人生成参数。
##
## 输入：敌人配置、生成间隔、数量上限与玩家周围的生成距离。
## 输出：供 EnemySpawner 只读使用的数据。
## 扩展点：P4 的难度导演可将单段配置升级为分段 RunDefinition。
class_name EnemySpawnSettings
extends Resource

@export var enemy_definition: EnemyDefinition
@export_range(0.05, 60.0, 0.05) var spawn_interval_seconds: float = 1.0
@export_range(1, 10000, 1) var max_alive_enemies: int = 30
@export_range(1.0, 5000.0, 1.0) var min_spawn_distance: float = 760.0
@export_range(1.0, 5000.0, 1.0) var max_spawn_distance: float = 1500.0
@export_range(0.0, 1000.0, 1.0) var offscreen_margin: float = 64.0
