## 一局结束时传给 UI 的不可持久化结果数据。
class_name GameResult
extends RefCounted

enum Outcome {
	VICTORY,
	DEFEAT,
}

var outcome: Outcome
var elapsed_seconds: float
var level: int
var kill_count: int


func _init(
		new_outcome: Outcome,
		new_elapsed_seconds: float,
		new_level: int,
		new_kill_count: int
) -> void:
	outcome = new_outcome
	elapsed_seconds = maxf(new_elapsed_seconds, 0.0)
	level = maxi(new_level, 1)
	kill_count = maxi(new_kill_count, 0)
