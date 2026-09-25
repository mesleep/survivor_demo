## 狂战盔甲的运行时数值档案（T23）。
##
## 输入：持续失血参数、基础吸血、半血增吸血与半血阈值。
## 输出：供 BerserkDrainComponent 扣血、供 PlayerActor 汇总额外吸血。
## 扩展点：数值全部可配；失血是否致死由 drain_non_lethal 控制。
class_name BerserkArmorDefinition
extends Resource

@export var drain_enabled: bool = true
@export_range(0.1, 10.0, 0.05) var drain_interval_seconds: float = 1.0
@export_range(0.0, 100000.0, 0.1) var drain_per_tick: float = 3.0
## 失血默认不致死，最低保留 1 点生命。
@export var drain_non_lethal: bool = true
@export_range(0.0, 1.0, 0.01) var base_lifesteal_ratio: float = 0.15
@export_range(0.0, 1.0, 0.01) var half_health_lifesteal_bonus: float = 0.25
@export_range(0.1, 0.9, 0.01) var half_health_ratio: float = 0.5
