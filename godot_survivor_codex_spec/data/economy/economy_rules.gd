## 单局经济的可调规则（T26 / D10）。
##
## 输入：无；数值可在 Inspector 修改，或由 GameSession 注入。
## 输出：金币掉落概率、单次掉落数量与结算公式。
## 扩展点：任务/成就奖励等继续加字段，不写死在脚本。
class_name EconomyRules
extends Resource

## 敌人死亡时掉落金币的概率。
@export_range(0.0, 1.0, 0.01) var coin_drop_chance: float = 0.15
## 每次掉落生成的金币数量。
@export_range(0, 1000, 1) var coins_per_drop: int = 1
## 结算时每个击杀发放的金币。
@export_range(0, 1000, 1) var coins_per_kill: int = 2


func roll_drop(random: RandomNumberGenerator) -> bool:
	if random == null:
		return false
	return random.randf() < coin_drop_chance
