## 管理一把武器的独立运行时冷却和发射请求。
##
## 输入：只读 WeaponDefinition、所属 Actor、子弹容器、目标与运行时修正。
## 输出：实际 ProjectileBase、fire_requested、projectile_spawned 和 weapon_fired 信号。
## 扩展点：同一角色可组合多个实例，每个实例拥有独立冷却与修正状态。
class_name WeaponController
extends Node

signal fire_requested(
	definition: WeaponDefinition,
	owner_actor: ActorBase,
	target: Node2D,
	projectile_parent: Node,
	projectile_count: int,
	damage_multiplier: float
)
signal weapon_fired(weapon_id: StringName)
signal projectile_spawned(projectile: ProjectileBase)

const MINIMUM_COOLDOWN_SECONDS := 0.02
const MINIMUM_RUNTIME_MULTIPLIER := 0.05

var definition: WeaponDefinition
var owner_actor: ActorBase
var projectile_parent: Node
var targeting_service: TargetingService

var _cooldown_remaining: float = 0.0
var _runtime_cooldown_multiplier: float = 1.0
var _runtime_projectile_count_bonus: int = 0
var _runtime_damage_multiplier: float = 1.0
var _runtime_bonus_projectile_chance: float = 0.0
var _runtime_projectile_lifesteal_ratio: float = 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()


func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not can_fire() or not is_instance_valid(targeting_service):
		return

	var target: ActorBase = targeting_service.get_nearest_target(
		owner_actor.get_aim_position(),
		get_effective_target_range(),
		&"enemy"
	)
	if target != null:
		request_fire(target)


## 注入武器配置及运行时依赖，并完全重置单局状态。
func initialize(
		new_definition: WeaponDefinition,
		new_owner_actor: ActorBase,
		new_projectile_parent: Node
) -> void:
	_disconnect_dependency_signals()
	definition = new_definition
	owner_actor = new_owner_actor
	projectile_parent = new_projectile_parent
	reset_runtime_state()

	if definition == null or not is_instance_valid(owner_actor) or not is_instance_valid(projectile_parent):
		push_error("WeaponController 初始化失败：缺少武器配置、所属 Actor 或子弹容器。")
		set_process(false)
		return

	owner_actor.tree_exiting.connect(_on_owner_actor_tree_exiting)
	projectile_parent.tree_exiting.connect(_on_projectile_parent_tree_exiting)
	set_process(true)


## 注入共享索敌服务；不持有固定 GameSession 路径。
func set_targeting_service(new_targeting_service: TargetingService) -> void:
	if is_instance_valid(targeting_service) and targeting_service.tree_exiting.is_connected(_on_targeting_service_tree_exiting):
		targeting_service.tree_exiting.disconnect(_on_targeting_service_tree_exiting)
	targeting_service = new_targeting_service
	if is_instance_valid(targeting_service):
		targeting_service.tree_exiting.connect(_on_targeting_service_tree_exiting)


func can_fire() -> bool:
	return (
		definition != null
		and definition.projectile_definition != null
		and definition.projectile_definition.scene != null
		and is_instance_valid(owner_actor)
		and is_instance_valid(projectile_parent)
		and not owner_actor.health_component.is_dead()
		and _cooldown_remaining <= 0.0
	)


## 验证目标并按弹数和扩散创建子弹；未成功生成时不消耗冷却。
func request_fire(target: Node2D) -> bool:
	if not can_fire() or not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return false
	if target is ActorBase and (target as ActorBase).health_component.is_dead():
		return false

	var target_position: Vector2 = (target as ActorBase).get_aim_position() if target is ActorBase else target.global_position
	var base_direction: Vector2 = owner_actor.get_aim_position().direction_to(target_position)
	if base_direction.is_zero_approx():
		base_direction = Vector2.RIGHT
	var requested_count: int = get_effective_projectile_count()
	if _random.randf() < _runtime_bonus_projectile_chance:
		requested_count += 1
	var spawned_count: int = 0
	for index: int in range(requested_count):
		var direction: Vector2 = base_direction.rotated(_get_spread_offset_radians(index, requested_count))
		var context := ProjectileSpawnContext.new(
			owner_actor,
			owner_actor.get_team_id(),
			owner_actor.get_aim_position(),
			direction
		)
		context.damage_multiplier = _runtime_damage_multiplier
		context.lifesteal_ratio = _runtime_projectile_lifesteal_ratio
		context.target = target
		context.weapon_id = definition.id
		if spawn_projectile(definition.projectile_definition, context) != null:
			spawned_count += 1
	if spawned_count == 0:
		return false

	_cooldown_remaining = get_effective_cooldown_seconds()
	fire_requested.emit(
		definition,
		owner_actor,
		target,
		projectile_parent,
		spawned_count,
		_runtime_damage_multiplier
	)
	weapon_fired.emit(definition.id)
	return true


## 通过注入的容器实例化并启动一个 ProjectileBase。
func spawn_projectile(
		projectile_definition: ProjectileDefinition,
		context: ProjectileSpawnContext
) -> ProjectileBase:
	if projectile_definition == null or projectile_definition.scene == null or context == null:
		return null
	if not is_instance_valid(projectile_parent):
		return null

	var projectile_node: Node = projectile_definition.scene.instantiate()
	if projectile_node is not ProjectileBase:
		push_error("WeaponController 发射失败：ProjectileDefinition.scene 必须生成 ProjectileBase。")
		projectile_node.queue_free()
		return null
	var projectile: ProjectileBase = projectile_node as ProjectileBase
	projectile_parent.add_child(projectile)
	projectile.initialize(projectile_definition, context)
	projectile.launch(context.initial_direction)
	if not projectile.is_active:
		projectile.queue_free()
		return null
	projectile_spawned.emit(projectile)
	return projectile


## 将单局修正合并到控制器，不回写 WeaponDefinition。
func apply_runtime_modifier(modifier: WeaponRuntimeModifier) -> void:
	if modifier == null:
		return
	_runtime_cooldown_multiplier *= maxf(modifier.cooldown_multiplier, MINIMUM_RUNTIME_MULTIPLIER)
	_runtime_projectile_count_bonus += modifier.projectile_count_bonus
	_runtime_damage_multiplier *= maxf(modifier.damage_multiplier, 0.0)
	_runtime_bonus_projectile_chance = clampf(
		_runtime_bonus_projectile_chance + modifier.bonus_projectile_chance,
		0.0,
		1.0
	)
	_runtime_projectile_lifesteal_ratio = clampf(
		_runtime_projectile_lifesteal_ratio + modifier.projectile_lifesteal_ratio,
		0.0,
		1.0
	)


func reset_runtime_state() -> void:
	_cooldown_remaining = 0.0
	_runtime_cooldown_multiplier = 1.0
	_runtime_projectile_count_bonus = 0
	_runtime_damage_multiplier = 1.0
	_runtime_bonus_projectile_chance = 0.0
	_runtime_projectile_lifesteal_ratio = 0.0


func get_effective_cooldown_seconds() -> float:
	if definition == null:
		return MINIMUM_COOLDOWN_SECONDS
	return maxf(definition.cooldown_seconds * _runtime_cooldown_multiplier, MINIMUM_COOLDOWN_SECONDS)


func get_effective_projectile_count() -> int:
	if definition == null:
		return 0
	return maxi(definition.projectile_count + _runtime_projectile_count_bonus, 1)


func get_runtime_damage_multiplier() -> float:
	return _runtime_damage_multiplier


func get_runtime_bonus_projectile_chance() -> float:
	return _runtime_bonus_projectile_chance


func get_runtime_projectile_lifesteal_ratio() -> float:
	return _runtime_projectile_lifesteal_ratio


## 测试可注入固定种子；正式运行仍使用独立随机源。
func set_random_seed(seed: int) -> void:
	_random.seed = seed


## 合并角色攻击范围上限与武器自身射程。
##
## 两者均为独立的数据驱动约束；较短的一方决定本武器本次索敌的有效范围。
func get_effective_target_range() -> float:
	if definition == null or not is_instance_valid(owner_actor):
		return 0.0
	return minf(maxf(owner_actor.get_attack_range(), 0.0), maxf(definition.target_range, 0.0))


func _get_spread_offset_radians(index: int, projectile_count: int) -> float:
	if projectile_count <= 1 or is_zero_approx(definition.spread_degrees):
		return 0.0
	var ratio: float = float(index) / float(projectile_count - 1)
	return deg_to_rad(lerpf(-definition.spread_degrees * 0.5, definition.spread_degrees * 0.5, ratio))


func _disconnect_dependency_signals() -> void:
	if is_instance_valid(owner_actor) and owner_actor.tree_exiting.is_connected(_on_owner_actor_tree_exiting):
		owner_actor.tree_exiting.disconnect(_on_owner_actor_tree_exiting)
	if is_instance_valid(projectile_parent) and projectile_parent.tree_exiting.is_connected(_on_projectile_parent_tree_exiting):
		projectile_parent.tree_exiting.disconnect(_on_projectile_parent_tree_exiting)


func _on_owner_actor_tree_exiting() -> void:
	owner_actor = null
	set_process(false)


func _on_projectile_parent_tree_exiting() -> void:
	projectile_parent = null
	set_process(false)


func _on_targeting_service_tree_exiting() -> void:
	targeting_service = null
