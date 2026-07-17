## 将命中事件转发给所属 Actor。
##
## 输入：ActorBase 引用与 DamageEvent。
## 输出：damage_received 信号，以及 ActorBase.apply_damage() 调用。
## 扩展点：无敌、阵营过滤和部位倍率可在 receive_damage() 中扩展。
class_name HurtboxComponent
extends Area2D

signal damage_received(event: DamageEvent)

var owner_actor: ActorBase


func initialize(new_owner_actor: ActorBase) -> void:
	owner_actor = new_owner_actor
	monitorable = is_instance_valid(owner_actor)


func receive_damage(event: DamageEvent) -> void:
	if event == null or not is_instance_valid(owner_actor):
		return
	if owner_actor.health_component.is_dead():
		return
	owner_actor.apply_damage(event)
	damage_received.emit(event)
