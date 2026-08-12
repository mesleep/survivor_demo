## 一局游戏的共享只读流程配置。
##
## 输入：单局时长、按起始时间排序的难度阶段和 Boss 定义。
## 输出：供 GameSession 与 DifficultyDirector 使用的权威规则数据。
class_name RunDefinition
extends Resource

@export_range(1.0, 3600.0, 1.0) var run_duration_seconds: float = 300.0
@export var stages: Array[DifficultyStage] = []
@export var boss_definition: EnemyDefinition
