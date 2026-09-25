## 玩家和敌人共享的运行时 Actor 基类。
##
## 输入：只读的角色 Resource 和 DamageEvent。
## 输出：组件化生命变化与只转发一次的 actor_died 信号。
## 扩展点：子类提供基础生命、阵营和攻击范围，移动与决策仍各自实现。
class_name ActorBase
extends CharacterBody2D

signal actor_died(actor: ActorBase, event: DamageEvent)
## 闪避成功：不扣血、不触发反伤/吸血/受伤反馈，由 UI 播放“闪避”提示。
signal damage_dodged(event: DamageEvent)
## 免疫成功：效果同闪避但提示为“免疫”，用于概率完全免伤。
signal damage_immune(event: DamageEvent)

@export var free_on_death: bool = true
## 可调伤害规则；为空时使用脚本内常量默认值，供 Tests 与独立 Actor 使用。
@export var combat_rules: CombatRules

const DEFAULT_MIN_DAMAGE_RATIO := 0.1
const DEFAULT_MAX_DODGE_CHANCE := 0.75
const DEFAULT_MAX_IMMUNE_CHANCE := 0.5
const DEFAULT_MAX_REFLECT_RATIO := 1.0

var definition_resource: Resource
var _death_forwarded: bool = false
var _defense: float = 0.0
var _dodge_chance: float = 0.0
var _immune_chance: float = 0.0
var _damage_reflect_ratio: float = 0.0
var _damage_random := RandomNumberGenerator.new()

## 持续伤害等状态运行时组件；由 ActorBase 在 _ready 时自动创建，场景无需改动。
var status_effect_component: StatusEffectComponent

@onready var health_component: HealthComponent = %HealthComponent
@onready var hurtbox_component: HurtboxComponent = %HurtboxComponent
@onready var damage_feedback_component: DamageFeedbackComponent = %DamageFeedbackComponent
@onready var visual: Node2D = $Visual


func _ready() -> void:
	_damage_random.randomize()
	if not health_component.died.is_connected(_on_health_component_died):
		health_component.died.connect(_on_health_component_died)
	hurtbox_component.initialize(self)
	damage_feedback_component.initialize(health_component, visual)
	damage_feedback_component.bind_actor(self)
	if status_effect_component == null:
		status_effect_component = StatusEffectComponent.new()
		status_effect_component.name = "StatusEffectComponent"
		add_child(status_effect_component)
		status_effect_component.initialize(self)


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
	if status_effect_component != null:
		status_effect_component.clear()


## 统一伤害结算：免疫/闪避 → 防御 → 扣血 → 反伤（D07）。
##
## 只在实际扣血后触发受伤反馈与反伤；闪避/免疫不扣血、不反伤、不吸血。
## 返回 DamageResult；调用方（Hurtbox、Projectile）可只关心扣血结果。
func apply_damage(event: DamageEvent) -> DamageResult:
	var result := DamageResult.new()
	if event == null:
		return result
	result.raw_amount = maxf(event.amount, 0.0)
	result.source = event.source
	result.tags = event.tags.duplicate()
	if event.amount <= 0.0 or health_component.is_dead():
		return result

	if get_immune_chance() > 0.0 and _damage_random.randf() < get_immune_chance():
		result.is_immune = true
		damage_immune.emit(event)
		return result
	if get_dodge_chance() > 0.0 and _damage_random.randf() < get_dodge_chance():
		result.is_dodged = true
		damage_dodged.emit(event)
		return result

	var reduced: float = maxf(result.raw_amount - get_defense(), result.raw_amount * get_min_damage_ratio())
	reduced = clampf(reduced, 0.0, result.raw_amount)
	result.blocked_amount = result.raw_amount - reduced
	if reduced <= 0.0:
		return result

	var reduced_event := DamageEvent.new(reduced, event.source, event.source_position)
	reduced_event.tags = event.tags.duplicate()
	reduced_event.can_crit = event.can_crit
	reduced_event.knockback_strength = event.knockback_strength
	var health_before: float = health_component.current_health
	health_component.apply_damage(reduced_event)
	result.applied_amount = maxf(health_before - health_component.current_health, 0.0)
	result.killed = health_component.is_dead()
	_try_reflect(event, result)
	return result


## 施加持续伤害状态（T17）；同一效果 ID 刷新而非叠层。
func apply_damage_over_time(
		effect: DamageOverTimeEffect, source: Node, damage_multiplier: float = 1.0
) -> bool:
	if status_effect_component == null:
		return false
	return status_effect_component.apply_dot(effect, source, damage_multiplier)


## 注入可调伤害规则（通常由 GameSession 下发给玩家）。
func set_combat_rules(rules: CombatRules) -> void:
	combat_rules = rules


func get_min_damage_ratio() -> float:
	if combat_rules != null:
		return combat_rules.minimum_damage_ratio
	return DEFAULT_MIN_DAMAGE_RATIO


func get_max_dodge_chance() -> float:
	if combat_rules != null:
		return combat_rules.max_dodge_chance
	return DEFAULT_MAX_DODGE_CHANCE


func get_max_immune_chance() -> float:
	if combat_rules != null:
		return combat_rules.max_immune_chance
	return DEFAULT_MAX_IMMUNE_CHANCE


func get_max_damage_reflect_ratio() -> float:
	if combat_rules != null:
		return combat_rules.max_damage_reflect_ratio
	return DEFAULT_MAX_REFLECT_RATIO


func get_defense() -> float:
	return _defense


func set_defense(value: float) -> void:
	_defense = maxf(value, 0.0)


func add_defense(value: float) -> void:
	set_defense(_defense + value)


func get_dodge_chance() -> float:
	return clampf(_dodge_chance, 0.0, get_max_dodge_chance())


func add_dodge_chance(value: float) -> void:
	_dodge_chance = clampf(_dodge_chance + value, 0.0, get_max_dodge_chance())


func get_immune_chance() -> float:
	return clampf(_immune_chance, 0.0, get_max_immune_chance())


func add_immune_chance(value: float) -> void:
	_immune_chance = clampf(_immune_chance + value, 0.0, get_max_immune_chance())


func get_damage_reflect_ratio() -> float:
	return clampf(_damage_reflect_ratio, 0.0, get_max_damage_reflect_ratio())


func set_damage_reflect_ratio(value: float) -> void:
	_damage_reflect_ratio = clampf(value, 0.0, get_max_damage_reflect_ratio())


func add_damage_reflect_ratio(value: float) -> void:
	_damage_reflect_ratio = clampf(_damage_reflect_ratio + value, 0.0, get_max_damage_reflect_ratio())


## 固定随机种子，供测试确定闪避/免疫结果。
func set_damage_random_seed(seed_value: int) -> void:
	_damage_random.seed = seed_value


## 反伤只对允许的原始命中触发，并打上 reflect 标签防止递归（T21 刺甲复用）。
func _try_reflect(event: DamageEvent, result: DamageResult) -> void:
	var ratio: float = get_damage_reflect_ratio()
	if ratio <= 0.0 or result.applied_amount <= 0.0:
		return
	if event.tags.has(&"reflect") or event.tags.has(&"dot"):
		return
	if not is_instance_valid(event.source) or event.source is not ActorBase:
		return
	var attacker: ActorBase = event.source as ActorBase
	if attacker == self or attacker.health_component.is_dead() or attacker.is_queued_for_deletion():
		return
	var reflect_event := DamageEvent.new(result.applied_amount * ratio, self, global_position)
	reflect_event.tags = [&"reflect"]
	attacker.apply_damage(reflect_event)


## 统一处理死亡转发和节点停用。
func die(event: DamageEvent) -> void:
	if _death_forwarded:
		return
	_death_forwarded = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	if status_effect_component != null:
		status_effect_component.clear()
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
