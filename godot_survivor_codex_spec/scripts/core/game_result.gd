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
## 本局已拾取的金币（T26）。
var coins_collected: int = 0
## 结算按击杀数发放的金币（T26）。
var coins_from_kills: int = 0
## 本局总奖励 = 已拾取 + 击杀结算。
var total_coins: int = 0


func _init(
		new_outcome: Outcome,
		new_elapsed_seconds: float,
		new_level: int,
		new_kill_count: int,
		new_coins_collected: int = 0,
		new_coins_from_kills: int = 0
) -> void:
	outcome = new_outcome
	elapsed_seconds = maxf(new_elapsed_seconds, 0.0)
	level = maxi(new_level, 1)
	kill_count = maxi(new_kill_count, 0)
	coins_collected = maxi(new_coins_collected, 0)
	coins_from_kills = maxi(new_coins_from_kills, 0)
	total_coins = coins_collected + coins_from_kills
