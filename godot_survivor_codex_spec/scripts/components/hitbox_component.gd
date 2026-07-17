## 将伤害数据应用到进入范围的 Hurtbox。
##
## 输入：来源 Actor、伤害数值、伤害标签和 HurtboxComponent。
## 输出：独立 DamageEvent 和 hit_landed 信号。
## 扩展点：攻击冷却、穿透和同目标去重由后续具体攻击行为管理。
class_name HitboxComponent
extends Area2D

signal hit_landed(hurtbox: HurtboxComponent, event: DamageEvent)

var owner_actor: ActorBase
var damage_amount: float = 0.0
var damage_tags: Array[StringName] = []


func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func initialize(
		new_owner_actor: ActorBase,
		new_damage_amount: float,
		new_damage_tags: Array[StringName] = []
) -> void:
	owner_actor = new_owner_actor
	damage_amount = maxf(new_damage_amount, 0.0)
	damage_tags = new_damage_tags.duplicate()
	monitoring = is_instance_valid(owner_actor) and damage_amount > 0.0


## 显式命中入口，同时供物理重叠和后续子弹/近战行为复用。
func apply_to(hurtbox: HurtboxComponent) -> bool:
	if not is_instance_valid(hurtbox) or not is_instance_valid(owner_actor) or damage_amount <= 0.0:
		return false

	var event := DamageEvent.new(damage_amount, owner_actor, owner_actor.global_position)
	event.tags = damage_tags.duplicate()
	hurtbox.receive_damage(event)
	hit_landed.emit(hurtbox, event)
	return true


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		apply_to(area as HurtboxComponent)
