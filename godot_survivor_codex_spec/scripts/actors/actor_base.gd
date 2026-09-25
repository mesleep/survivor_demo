## 玩家和敌人共享的运行时 Actor 基类。
##
## 输入：只读的角色 Resource 和 DamageEvent。
## 输出：组件化生命变化与只转发一次的 actor_died 信号。
## 扩展点：子类提供基础生命、阵营和攻击范围，移动与决策仍各自实现。
class_name ActorBase
extends CharacterBody2D

signal actor_died(actor: ActorBase, event: DamageEvent)

@export var free_on_death: bool = true

var definition_resource: Resource
var _death_forwarded: bool = false

@onready var health_component: HealthComponent = %HealthComponent
@onready var hurtbox_component: HurtboxComponent = %HurtboxComponent
@onready var damage_feedback_component: DamageFeedbackComponent = %DamageFeedbackComponent
@onready var visual: Node2D = $Visual


func _ready() -> void:
	if not health_component.died.is_connected(_on_health_component_died):
		health_component.died.connect(_on_health_component_died)
	hurtbox_component.initialize(self)
	damage_feedback_component.initialize(health_component, visual)


## 从共享 Resource 初始化 Actor 的独立运行时生命状态。
##
## 该方法仅保存 Resource 引用并读取基础值，不会将当前生命回写 `.tres`。
func initialize(new_definition: Resource) -> void:
	if new_definition == null:
		push_error("ActorBase 初始化失败：缺少角色 Resource。")
		set_physics_process(false)
		return
	definition_resource = new_definition
	_death_forwarded = false
	health_component.initialize(_get_base_max_health())
	hurtbox_component.initialize(self)


func apply_damage(event: DamageEvent) -> void:
	health_component.apply_damage(event)


## 统一处理死亡转发和节点停用。
func die(event: DamageEvent) -> void:
	if _death_forwarded:
		return
	_death_forwarded = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	hurtbox_component.set_deferred("monitorable", false)
	actor_died.emit(self, event)
	if free_on_death:
		queue_free()


func get_aim_position() -> Vector2:
	return global_position


func get_team_id() -> StringName:
	return &"neutral"


## 返回当前 Actor 可用于武器索敌的攻击范围上限。
##
## 默认中立 Actor 不具备攻击范围；可攻击子类必须从自身数据或单局状态提供该值。
func get_attack_range() -> float:
	return 0.0


## 返回全武器索敌射程倍率；默认 1.0，由可成长 Actor 覆盖（D06 最终索敌值语义）。
func get_weapon_range_multiplier() -> float:
	return 1.0


func _get_base_max_health() -> float:
	return 1.0


func _on_health_component_died(event: DamageEvent) -> void:
	die(event)
