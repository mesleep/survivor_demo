## 根据 GameSession 提供的经过时间切换分段难度。
##
## 输入：只读 RunDefinition、EnemySpawner 和权威经过时间。
## 输出：stage_changed 信号及生成器运行时参数更新。
class_name DifficultyDirector
extends Node

signal stage_changed(stage_index: int, stage: DifficultyStage)

var run_definition: RunDefinition
var enemy_spawner: EnemySpawner
var current_stage_index: int = -1


func initialize(definition: RunDefinition, spawner: EnemySpawner) -> void:
	run_definition = definition
	enemy_spawner = spawner
	current_stage_index = -1
	update_elapsed_time(0.0)


func update_elapsed_time(elapsed_seconds: float) -> void:
	if run_definition == null or not is_instance_valid(enemy_spawner):
		return
	var next_index: int = _find_stage_index(elapsed_seconds)
	if next_index < 0 or next_index == current_stage_index:
		return
	current_stage_index = next_index
	var stage: DifficultyStage = run_definition.stages[current_stage_index]
	enemy_spawner.apply_difficulty_stage(stage)
	stage_changed.emit(current_stage_index, stage)


func reset() -> void:
	run_definition = null
	enemy_spawner = null
	current_stage_index = -1


func _find_stage_index(elapsed_seconds: float) -> int:
	var found_index: int = -1
	for index: int in range(run_definition.stages.size()):
		var stage: DifficultyStage = run_definition.stages[index]
		if stage == null or stage.start_time_seconds > elapsed_seconds:
			continue
		if found_index < 0 or stage.start_time_seconds >= run_definition.stages[found_index].start_time_seconds:
			found_index = index
	return found_index
